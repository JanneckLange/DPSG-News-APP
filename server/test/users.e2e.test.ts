import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { clearAuthorData, clearEvents, close, connect, createAuthorForTesting } from '../src/db';

async function getLayerIdByName(name: string): Promise<number> {
  const response = await request(app).get('/api/layers');
  expect(response.status).toBe(200);
  const layer = (response.body.layers as Array<{ id: number; name: string }>).find((l) => l.name === name);
  if (!layer) {
    throw new Error(`Layer "${name}" not found in seeded layers`);
  }
  return layer.id;
}

async function loginAuthor(username: string, password: string): Promise<string> {
  const response = await request(app).post('/api/auth/login').send({ username, password });
  expect(response.status).toBe(200);
  return response.body.token as string;
}

async function getTopicIdByLayerAndName(layerId: number, name: string): Promise<number> {
  const response = await request(app).get(`/api/topics?layerId=${layerId}`);
  expect(response.status).toBe(200);
  const topic = (response.body.topics as Array<{ id: number; name: string }>).find((t) => t.name === name);
  if (!topic) {
    throw new Error(`Topic "${name}" not found for layer ${layerId}`);
  }
  return topic.id;
}

let hamburgLayerId: number;
let koelnLayerId: number;
let berlinLayerId: number;

beforeAll(async () => {
  process.env.TEST_DATABASE_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  process.env.AUTHOR_BOOTSTRAP_USERNAME = process.env.AUTHOR_BOOTSTRAP_USERNAME || 'bootstrap-admin';
  process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD = process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD || 'bootstrap-one-time-password';
  await connect();
  hamburgLayerId = await getLayerIdByName('Hamburg');
  koelnLayerId = await getLayerIdByName('Köln');
  berlinLayerId = await getLayerIdByName('Berlin');
});

beforeEach(async () => {
  await clearEvents();
  await clearAuthorData();
});

afterAll(async () => {
  await close();
});

describe('Admin user management authorization e2e (#58)', () => {
  it('requires a valid layerId within the creator\'s own branch to create a new admin', async () => {
    await createAuthorForTesting({ username: 'admin-users-koeln', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-users-koeln', 'admin-123');

    const missingLayerId = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-admin', isAdmin: true });
    expect(missingLayerId.status).toBe(400);

    const outsideScope = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-admin', isAdmin: true, layerIds: [hamburgLayerId] });
    expect(outsideScope.status).toBe(403);

    const inScope = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-admin', isAdmin: true, layerIds: [koelnLayerId] });
    expect(inScope.status).toBe(201);
    expect(inScope.body.author.adminLayerIds).toEqual([koelnLayerId]);
  });

  it('does not require a layerId to create a plain (non-admin) author', async () => {
    await createAuthorForTesting({ username: 'admin-users-plain', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-users-plain', 'admin-123');

    const response = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-author' });
    expect(response.status).toBe(201);
  });

  it('rejects deleting or resetting the password of an admin outside the own layer branch', async () => {
    await createAuthorForTesting({ username: 'admin-hamburg', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    await createAuthorForTesting({ username: 'admin-koeln', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const koelnAdminToken = await loginAuthor('admin-koeln', 'admin-123');

    const usersResponse = await request(app)
      .get('/api/admin/users')
      .set('authorization', `Bearer ${koelnAdminToken}`);
    const hamburgAdmin = usersResponse.body.users.find((u: { username: string }) => u.username === 'admin-hamburg');

    const resetOutsideScope = await request(app)
      .post(`/api/admin/users/${hamburgAdmin.id}/reset-password`)
      .set('authorization', `Bearer ${koelnAdminToken}`);
    expect(resetOutsideScope.status).toBe(403);

    const deactivateHamburgAdmin = await request(app)
      .patch(`/api/admin/users/${hamburgAdmin.id}`)
      .set('authorization', `Bearer ${koelnAdminToken}`)
      .send({ isActive: false });
    expect(deactivateHamburgAdmin.status).toBe(204);

    const deleteOutsideScope = await request(app)
      .delete(`/api/admin/users/${hamburgAdmin.id}`)
      .set('authorization', `Bearer ${koelnAdminToken}`);
    expect(deleteOutsideScope.status).toBe(403);
  });

  it('allows deleting or resetting the password of an admin within the own layer branch', async () => {
    await createAuthorForTesting({ username: 'admin-koeln-owner', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-koeln-owner', 'admin-123');

    const createResponse = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'admin-koeln-managed', isAdmin: true, layerIds: [koelnLayerId] });
    expect(createResponse.status).toBe(201);
    const managedAdminId = createResponse.body.author.id as number;

    const resetInScope = await request(app)
      .post(`/api/admin/users/${managedAdminId}/reset-password`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(resetInScope.status).toBe(200);

    const deactivateResponse = await request(app)
      .patch(`/api/admin/users/${managedAdminId}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ isActive: false });
    expect(deactivateResponse.status).toBe(204);

    const deleteInScope = await request(app)
      .delete(`/api/admin/users/${managedAdminId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteInScope.status).toBe(204);
  });

  it('does not restrict deleting or resetting the password of a plain (non-admin) author by layer', async () => {
    await createAuthorForTesting({ username: 'admin-koeln-authors', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-koeln-authors', 'admin-123');

    const createResponse = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'plain-author' });
    expect(createResponse.status).toBe(201);
    const authorId = createResponse.body.author.id as number;

    const resetResponse = await request(app)
      .post(`/api/admin/users/${authorId}/reset-password`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(resetResponse.status).toBe(200);

    const deactivateResponse = await request(app)
      .patch(`/api/admin/users/${authorId}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ isActive: false });
    expect(deactivateResponse.status).toBe(204);

    const deleteResponse = await request(app)
      .delete(`/api/admin/users/${authorId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteResponse.status).toBe(204);
  });
});

describe('Multi-layer admin scope (#59)', () => {
  it('grants scope over the union of all assigned layer subtrees, not just one', async () => {
    await createAuthorForTesting({
      username: 'admin-multi',
      password: 'admin-123',
      isAdmin: true,
      adminLayerIds: [hamburgLayerId, koelnLayerId],
    });
    const adminToken = await loginAuthor('admin-multi', 'admin-123');

    const inHamburgScope = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'author-hamburg' });
    expect(inHamburgScope.status).toBe(201);

    const createInKoeln = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-admin-koeln', isAdmin: true, layerIds: [koelnLayerId] });
    expect(createInKoeln.status).toBe(201);

    const outsideBothLayers = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-admin-berlin', isAdmin: true, layerIds: [berlinLayerId] });
    expect(outsideBothLayers.status).toBe(403);
  });

  it('rejects admin creation without at least one layerId', async () => {
    await createAuthorForTesting({ username: 'admin-empty', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-empty', 'admin-123');

    const response = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-admin', isAdmin: true, layerIds: [] });
    expect(response.status).toBe(400);
  });
});

describe('Admin layer grant/revoke endpoints (#18)', () => {
  it('adds and removes an admin layer within the acting admin\'s scope', async () => {
    await createAuthorForTesting({ username: 'admin-grantor', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId, koelnLayerId] });
    const adminToken = await loginAuthor('admin-grantor', 'admin-123');
    const target = await createAuthorForTesting({ username: 'admin-target', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });

    const add = await request(app)
      .post(`/api/admin/users/${target.id}/admin-layers`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ layerId: koelnLayerId });
    expect(add.status).toBe(201);
    expect(add.body.adminLayerIds.sort()).toEqual([hamburgLayerId, koelnLayerId].sort());

    const remove = await request(app)
      .delete(`/api/admin/users/${target.id}/admin-layers/${koelnLayerId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(remove.status).toBe(204);
  });

  it('rejects removing the last remaining admin layer', async () => {
    await createAuthorForTesting({ username: 'admin-grantor-2', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    const adminToken = await loginAuthor('admin-grantor-2', 'admin-123');
    const target = await createAuthorForTesting({ username: 'admin-target-2', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });

    const remove = await request(app)
      .delete(`/api/admin/users/${target.id}/admin-layers/${hamburgLayerId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(remove.status).toBe(409);
  });

  it('rejects granting/revoking a layer outside the acting admin\'s own scope', async () => {
    await createAuthorForTesting({ username: 'admin-grantor-3', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-grantor-3', 'admin-123');
    const target = await createAuthorForTesting({ username: 'admin-target-3', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });

    const add = await request(app)
      .post(`/api/admin/users/${target.id}/admin-layers`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ layerId: berlinLayerId });
    expect(add.status).toBe(403);
  });
});

describe('Author layer/topic grant endpoints (#15, #18)', () => {
  it('adds and removes a layer grant for a non-admin author within scope', async () => {
    await createAuthorForTesting({ username: 'admin-author-grantor', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId, koelnLayerId] });
    const adminToken = await loginAuthor('admin-author-grantor', 'admin-123');
    const author = await createAuthorForTesting({ username: 'plain-author-grants', password: 'author-123', isAdmin: false });

    const add = await request(app)
      .post(`/api/admin/users/${author.id}/layer-grants`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ layerId: hamburgLayerId });
    expect(add.status).toBe(201);
    expect(add.body.layerGrantIds).toEqual([hamburgLayerId]);

    const remove = await request(app)
      .delete(`/api/admin/users/${author.id}/layer-grants/${hamburgLayerId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(remove.status).toBe(204);
  });

  it('rejects a layer grant outside the acting admin\'s scope', async () => {
    await createAuthorForTesting({ username: 'admin-author-grantor-2', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-author-grantor-2', 'admin-123');
    const author = await createAuthorForTesting({ username: 'plain-author-grants-2', password: 'author-123', isAdmin: false });

    const add = await request(app)
      .post(`/api/admin/users/${author.id}/layer-grants`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ layerId: berlinLayerId });
    expect(add.status).toBe(403);
  });

  it('rejects layer grants against an admin target (use admin-layers endpoint instead)', async () => {
    await createAuthorForTesting({ username: 'admin-author-grantor-3', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-author-grantor-3', 'admin-123');
    const adminTarget = await createAuthorForTesting({ username: 'admin-target-4', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });

    const add = await request(app)
      .post(`/api/admin/users/${adminTarget.id}/layer-grants`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ layerId: koelnLayerId });
    expect(add.status).toBe(400);
  });

  it('adds and removes a topic grant for a non-admin author within scope', async () => {
    await createAuthorForTesting({ username: 'admin-topic-grantor', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    const adminToken = await loginAuthor('admin-topic-grantor', 'admin-123');
    const author = await createAuthorForTesting({ username: 'plain-author-topic-grants', password: 'author-123', isAdmin: false });
    const topicId = await getTopicIdByLayerAndName(hamburgLayerId, 'Wölflinge');

    const add = await request(app)
      .post(`/api/admin/users/${author.id}/topic-grants`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ topicId });
    expect(add.status).toBe(201);
    expect(add.body.topicGrantIds).toEqual([topicId]);

    const remove = await request(app)
      .delete(`/api/admin/users/${author.id}/topic-grants/${topicId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(remove.status).toBe(204);
  });

  it('rejects a topic grant whose layer is outside the acting admin\'s scope', async () => {
    await createAuthorForTesting({ username: 'admin-topic-grantor-2', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-topic-grantor-2', 'admin-123');
    const author = await createAuthorForTesting({ username: 'plain-author-topic-grants-2', password: 'author-123', isAdmin: false });
    const topicId = await getTopicIdByLayerAndName(hamburgLayerId, 'Wölflinge');

    const add = await request(app)
      .post(`/api/admin/users/${author.id}/topic-grants`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ topicId });
    expect(add.status).toBe(403);
  });
});
