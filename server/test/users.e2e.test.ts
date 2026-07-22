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

let hamburgLayerId: number;
let koelnLayerId: number;

beforeAll(async () => {
  process.env.TEST_DATABASE_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  process.env.AUTHOR_BOOTSTRAP_USERNAME = process.env.AUTHOR_BOOTSTRAP_USERNAME || 'bootstrap-admin';
  process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD = process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD || 'bootstrap-one-time-password';
  await connect();
  hamburgLayerId = await getLayerIdByName('Hamburg');
  koelnLayerId = await getLayerIdByName('Köln');
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
    await createAuthorForTesting({ username: 'admin-users-koeln', password: 'admin-123', isAdmin: true, adminLayerId: koelnLayerId });
    const adminToken = await loginAuthor('admin-users-koeln', 'admin-123');

    const missingLayerId = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-admin', isAdmin: true });
    expect(missingLayerId.status).toBe(400);

    const outsideScope = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-admin', isAdmin: true, layerId: hamburgLayerId });
    expect(outsideScope.status).toBe(403);

    const inScope = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-admin', isAdmin: true, layerId: koelnLayerId });
    expect(inScope.status).toBe(201);
    expect(inScope.body.author.adminLayerId).toBe(koelnLayerId);
  });

  it('does not require a layerId to create a plain (non-admin) author', async () => {
    await createAuthorForTesting({ username: 'admin-users-plain', password: 'admin-123', isAdmin: true, adminLayerId: koelnLayerId });
    const adminToken = await loginAuthor('admin-users-plain', 'admin-123');

    const response = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-author' });
    expect(response.status).toBe(201);
  });

  it('rejects deleting or resetting the password of an admin outside the own layer branch', async () => {
    await createAuthorForTesting({ username: 'admin-hamburg', password: 'admin-123', isAdmin: true, adminLayerId: hamburgLayerId });
    await createAuthorForTesting({ username: 'admin-koeln', password: 'admin-123', isAdmin: true, adminLayerId: koelnLayerId });
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
    await createAuthorForTesting({ username: 'admin-koeln-owner', password: 'admin-123', isAdmin: true, adminLayerId: koelnLayerId });
    const adminToken = await loginAuthor('admin-koeln-owner', 'admin-123');

    const createResponse = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'admin-koeln-managed', isAdmin: true, layerId: koelnLayerId });
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
    await createAuthorForTesting({ username: 'admin-koeln-authors', password: 'admin-123', isAdmin: true, adminLayerId: koelnLayerId });
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
