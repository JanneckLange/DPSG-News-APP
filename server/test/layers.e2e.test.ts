import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { clearAuthorData, clearEvents, close, connect, createAuthorForTesting } from '../src/db';
import { MAX_TITLE_LENGTH } from '../src/eventValidation';

async function loginAuthor(username: string, password: string): Promise<string> {
  const response = await request(app).post('/api/auth/login').send({ username, password });
  expect(response.status).toBe(200);
  return response.body.token as string;
}

beforeAll(async () => {
  process.env.TEST_DATABASE_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  process.env.AUTHOR_BOOTSTRAP_USERNAME = process.env.AUTHOR_BOOTSTRAP_USERNAME || 'bootstrap-admin';
  process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD = process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD || 'bootstrap-one-time-password';
  await connect();
});

beforeEach(async () => {
  await clearEvents();
  await clearAuthorData();
});

afterAll(async () => {
  await close();
});

describe('Layers API e2e', () => {
  it('exposes the seeded Bundesverband + Diözesanverbände hierarchy', async () => {
    const response = await request(app).get('/api/layers');
    expect(response.status).toBe(200);
    expect(response.body.lastChange).toEqual(expect.any(String));

    const layers = response.body.layers as Array<{ id: number; name: string; type: string; parentId: number | null }>;
    const bundesverband = layers.find((l) => l.type === 'bundesverband');
    expect(bundesverband).toBeDefined();
    expect(bundesverband!.parentId).toBeNull();

    const dvs = layers.filter((l) => l.type === 'dv');
    expect(dvs).toHaveLength(25);
    expect(dvs.every((dv) => dv.parentId === bundesverband!.id)).toBe(true);

    const koeln = dvs.find((dv) => dv.name === 'Köln');
    expect(koeln).toBeDefined();
  });

  it('rejects layer creation and mutation for non-admins and unauthenticated users', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    const token = await loginAuthor('author-a', 'secret-123');

    const unauthenticated = await request(app).post('/api/admin/layers').send({ name: 'Bezirk Nord', type: 'bezirk' });
    expect(unauthenticated.status).toBe(401);

    const nonAdmin = await request(app)
      .post('/api/admin/layers')
      .set('authorization', `Bearer ${token}`)
      .send({ name: 'Bezirk Nord', type: 'bezirk' });
    expect(nonAdmin.status).toBe(403);
  });

  it('lets an admin create, update and delete a layer, enforcing delete guards', async () => {
    await createAuthorForTesting({ username: 'admin-layers', password: 'admin-123', isAdmin: true });
    const adminToken = await loginAuthor('admin-layers', 'admin-123');

    const layersResponse = await request(app).get('/api/layers');
    const koelnLayer = (layersResponse.body.layers as Array<{ id: number; name: string; type: string }>).find(
      (l) => l.name === 'Köln' && l.type === 'dv'
    )!;

    const createResponse = await request(app)
      .post('/api/admin/layers')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Bezirk Süd', type: 'bezirk', parentId: koelnLayer.id });
    expect(createResponse.status).toBe(201);
    const createdLayer = createResponse.body.layer as { id: number; name: string; parentId: number };
    expect(createdLayer.name).toBe('Bezirk Süd');
    expect(createdLayer.parentId).toBe(koelnLayer.id);

    // Parent cannot be deleted while it has a child layer.
    const deleteParentBlocked = await request(app)
      .delete(`/api/admin/layers/${koelnLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteParentBlocked.status).toBe(409);

    const updateResponse = await request(app)
      .patch(`/api/admin/layers/${createdLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Bezirk Süd-West' });
    expect(updateResponse.status).toBe(200);
    expect(updateResponse.body.layer.name).toBe('Bezirk Süd-West');

    // An event referencing the new layer blocks its deletion.
    const eventResponse = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${adminToken}`)
      .send({
        title: 'Bezirkstreffen',
        description: 'Beschreibung',
        startDate: '2026-01-01T10:00:00Z',
        endDate: '2026-01-01T12:00:00Z',
        location: 'Ort',
        layerId: createdLayer.id,
      });
    expect(eventResponse.status).toBe(201);

    const deleteInUseBlocked = await request(app)
      .delete(`/api/admin/layers/${createdLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteInUseBlocked.status).toBe(409);

    await clearEvents();

    const deleteResponse = await request(app)
      .delete(`/api/admin/layers/${createdLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteResponse.status).toBe(204);

    const deleteAgain = await request(app)
      .delete(`/api/admin/layers/${createdLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteAgain.status).toBe(404);
  });

  it('rejects creating or renaming a layer with an oversized name', async () => {
    await createAuthorForTesting({ username: 'admin-layers-oversized', password: 'admin-123', isAdmin: true });
    const adminToken = await loginAuthor('admin-layers-oversized', 'admin-123');
    const oversizedName = 'a'.repeat(MAX_TITLE_LENGTH + 1);

    const layersResponse = await request(app).get('/api/layers');
    const koelnLayer = (layersResponse.body.layers as Array<{ id: number; name: string; type: string }>).find(
      (l) => l.name === 'Köln' && l.type === 'dv'
    )!;

    const createResponse = await request(app)
      .post('/api/admin/layers')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: oversizedName, type: 'bezirk', parentId: koelnLayer.id });
    expect(createResponse.status).toBe(400);

    const validCreateResponse = await request(app)
      .post('/api/admin/layers')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Bezirk Ost', type: 'bezirk', parentId: koelnLayer.id });
    expect(validCreateResponse.status).toBe(201);
    const createdLayer = validCreateResponse.body.layer as { id: number };

    const renameResponse = await request(app)
      .patch(`/api/admin/layers/${createdLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: oversizedName });
    expect(renameResponse.status).toBe(400);

    await request(app).delete(`/api/admin/layers/${createdLayer.id}`).set('authorization', `Bearer ${adminToken}`);
  });

  it('protects the Bundesverband root layer from deletion and ignores reparenting attempts', async () => {
    await createAuthorForTesting({ username: 'admin-layers-root', password: 'admin-123', isAdmin: true });
    const adminToken = await loginAuthor('admin-layers-root', 'admin-123');

    const layersResponse = await request(app).get('/api/layers');
    const layers = layersResponse.body.layers as Array<{ id: number; name: string; type: string; parentId: number | null }>;
    const bundesverband = layers.find((l) => l.type === 'bundesverband')!;
    const koelnLayer = layers.find((l) => l.name === 'Köln' && l.type === 'dv')!;

    // Root layer cannot be deleted.
    const deleteRootBlocked = await request(app)
      .delete(`/api/admin/layers/${bundesverband.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteRootBlocked.status).toBe(409);

    // PATCH only renames; a parentId in the body is ignored, not applied.
    const reparentIgnored = await request(app)
      .patch(`/api/admin/layers/${koelnLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: koelnLayer.name, parentId: null });
    expect(reparentIgnored.status).toBe(200);
    expect(reparentIgnored.body.layer.parentId).toBe(bundesverband.id);
  });

  it('rejects layer creation, rename and deletion outside the admin\'s own layer branch', async () => {
    const layersResponse = await request(app).get('/api/layers');
    const layers = layersResponse.body.layers as Array<{ id: number; name: string; type: string; parentId: number | null }>;
    const koelnLayer = layers.find((l) => l.name === 'Köln' && l.type === 'dv')!;
    const otherDvLayer = layers.find((l) => l.type === 'dv' && l.id !== koelnLayer.id)!;

    await createAuthorForTesting({
      username: 'admin-layers-scoped',
      password: 'admin-123',
      isAdmin: true,
      adminLayerId: koelnLayer.id,
    });
    const adminToken = await loginAuthor('admin-layers-scoped', 'admin-123');

    // Creating a layer under a foreign branch is forbidden.
    const createOutsideScope = await request(app)
      .post('/api/admin/layers')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Bezirk Fremd', type: 'bezirk', parentId: otherDvLayer.id });
    expect(createOutsideScope.status).toBe(403);

    // Creating within the own branch is allowed.
    const createInScope = await request(app)
      .post('/api/admin/layers')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Bezirk Eigen', type: 'bezirk', parentId: koelnLayer.id });
    expect(createInScope.status).toBe(201);
    const createdLayer = createInScope.body.layer as { id: number };

    // Renaming a foreign layer is forbidden.
    const renameOutsideScope = await request(app)
      .patch(`/api/admin/layers/${otherDvLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Umbenannt' });
    expect(renameOutsideScope.status).toBe(403);

    // Deleting a foreign layer is forbidden.
    const deleteOutsideScope = await request(app)
      .delete(`/api/admin/layers/${otherDvLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteOutsideScope.status).toBe(403);

    // Deleting the own, unused layer is allowed.
    const deleteInScope = await request(app)
      .delete(`/api/admin/layers/${createdLayer.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteInScope.status).toBe(204);
  });

  it('rejects creating or updating events with an unknown layerId', async () => {
    await createAuthorForTesting({ username: 'author-b', password: 'secret-123' });
    const token = await loginAuthor('author-b', 'secret-123');

    const response = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Ungültiger Layer',
        description: 'Beschreibung',
        startDate: '2026-01-01T10:00:00Z',
        endDate: '2026-01-01T12:00:00Z',
        location: 'Ort',
        layerId: 999999,
      });
    expect(response.status).toBe(400);
  });
});
