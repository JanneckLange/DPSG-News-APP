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

  it('rejects deactivating, deleting or resetting the password of an admin outside the own layer branch', async () => {
    const hamburgAdmin = await createAuthorForTesting({ username: 'admin-hamburg', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    await createAuthorForTesting({ username: 'admin-koeln', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const koelnAdminToken = await loginAuthor('admin-koeln', 'admin-123');

    const resetOutsideScope = await request(app)
      .post(`/api/admin/users/${hamburgAdmin.id}/reset-password`)
      .set('authorization', `Bearer ${koelnAdminToken}`);
    expect(resetOutsideScope.status).toBe(403);

    const deactivateHamburgAdmin = await request(app)
      .patch(`/api/admin/users/${hamburgAdmin.id}`)
      .set('authorization', `Bearer ${koelnAdminToken}`)
      .send({ isActive: false });
    expect(deactivateHamburgAdmin.status).toBe(403);

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

  it('does not restrict deleting or resetting the password of a plain (non-admin) author without any grants', async () => {
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

  it('rejects deactivating, deleting or resetting the password of a plain author with a layer grant outside the own layer branch', async () => {
    await createAuthorForTesting({ username: 'admin-koeln-scope', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-koeln-scope', 'admin-123');
    const outsideAuthor = await createAuthorForTesting({
      username: 'author-hamburg-only',
      password: 'author-123',
      layerGrantIds: [hamburgLayerId],
    });

    const resetOutsideScope = await request(app)
      .post(`/api/admin/users/${outsideAuthor.id}/reset-password`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(resetOutsideScope.status).toBe(403);

    const deactivateOutsideScope = await request(app)
      .patch(`/api/admin/users/${outsideAuthor.id}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ isActive: false });
    expect(deactivateOutsideScope.status).toBe(403);

    const deleteOutsideScope = await request(app)
      .delete(`/api/admin/users/${outsideAuthor.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteOutsideScope.status).toBe(403);
  });

  it('allows deactivating, deleting or resetting the password of a plain author whose grants are all within the own layer branch', async () => {
    await createAuthorForTesting({ username: 'admin-koeln-inscope', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-koeln-inscope', 'admin-123');
    const inScopeAuthor = await createAuthorForTesting({
      username: 'author-koeln-only',
      password: 'author-123',
      layerGrantIds: [koelnLayerId],
    });

    const resetInScope = await request(app)
      .post(`/api/admin/users/${inScopeAuthor.id}/reset-password`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(resetInScope.status).toBe(200);

    const deactivateInScope = await request(app)
      .patch(`/api/admin/users/${inScopeAuthor.id}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ isActive: false });
    expect(deactivateInScope.status).toBe(204);

    const deleteInScope = await request(app)
      .delete(`/api/admin/users/${inScopeAuthor.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteInScope.status).toBe(204);
  });
});

describe('GET /api/admin/users visibility (#112)', () => {
  it('hides an admin outside the own layer branch entirely from the users list', async () => {
    await createAuthorForTesting({ username: 'visibility-admin-hamburg', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    await createAuthorForTesting({ username: 'visibility-admin-koeln', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const koelnAdminToken = await loginAuthor('visibility-admin-koeln', 'admin-123');

    const response = await request(app)
      .get('/api/admin/users')
      .set('authorization', `Bearer ${koelnAdminToken}`);
    expect(response.status).toBe(200);
    const usernames = (response.body.users as Array<{ username: string }>).map((u) => u.username);
    expect(usernames).toContain('visibility-admin-koeln');
    expect(usernames).not.toContain('visibility-admin-hamburg');
  });

  it('redacts an in-scope admin\'s layers outside the own branch instead of hiding them entirely', async () => {
    await createAuthorForTesting({
      username: 'visibility-admin-multi',
      password: 'admin-123',
      isAdmin: true,
      adminLayerIds: [koelnLayerId, hamburgLayerId],
    });
    await createAuthorForTesting({ username: 'visibility-admin-koeln-2', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const koelnAdminToken = await loginAuthor('visibility-admin-koeln-2', 'admin-123');

    const response = await request(app)
      .get('/api/admin/users')
      .set('authorization', `Bearer ${koelnAdminToken}`);
    expect(response.status).toBe(200);
    const multiAdmin = (response.body.users as Array<{ username: string; adminLayerIds: number[] }>).find(
      (u) => u.username === 'visibility-admin-multi'
    );
    expect(multiAdmin).toBeDefined();
    expect(multiAdmin?.adminLayerIds).toEqual([koelnLayerId]);
  });

  it('hides a plain author with an out-of-branch grant from an unrelated admin', async () => {
    await createAuthorForTesting({ username: 'visibility-admin-unrelated', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('visibility-admin-unrelated', 'admin-123');
    await createAuthorForTesting({ username: 'visibility-author-hamburg', password: 'author-123', layerGrantIds: [hamburgLayerId] });

    const response = await request(app)
      .get('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`);
    expect(response.status).toBe(200);
    const usernames = (response.body.users as Array<{ username: string }>).map((u) => u.username);
    expect(usernames).not.toContain('visibility-author-hamburg');
  });

  it('shows a grant-less author to their creator but not to an unrelated non-root admin', async () => {
    const creator = await createAuthorForTesting({ username: 'visibility-creator', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'visibility-other-admin', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    await createAuthorForTesting({ username: 'visibility-fresh-author', password: 'author-123', createdByAuthorId: creator.id });
    const creatorToken = await loginAuthor('visibility-creator', 'admin-123');
    const otherToken = await loginAuthor('visibility-other-admin', 'admin-123');

    const creatorView = await request(app)
      .get('/api/admin/users')
      .set('authorization', `Bearer ${creatorToken}`);
    expect((creatorView.body.users as Array<{ username: string }>).map((u) => u.username)).toContain('visibility-fresh-author');

    const otherView = await request(app)
      .get('/api/admin/users')
      .set('authorization', `Bearer ${otherToken}`);
    expect((otherView.body.users as Array<{ username: string }>).map((u) => u.username)).not.toContain('visibility-fresh-author');
  });

  it('shows a grant-less author to a root-layer admin regardless of who created them', async () => {
    await createAuthorForTesting({ username: 'visibility-someone', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'visibility-root-admin', password: 'admin-123', isAdmin: true });
    await createAuthorForTesting({ username: 'visibility-fresh-author-2', password: 'author-123' });
    const rootAdminToken = await loginAuthor('visibility-root-admin', 'admin-123');

    const response = await request(app)
      .get('/api/admin/users')
      .set('authorization', `Bearer ${rootAdminToken}`);
    expect((response.body.users as Array<{ username: string }>).map((u) => u.username)).toContain('visibility-fresh-author-2');
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

  it('allows layer grants against an admin target (#81: Admin kann zusaetzlich Autoren-Rechte haben)', async () => {
    await createAuthorForTesting({ username: 'admin-author-grantor-3', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-author-grantor-3', 'admin-123');
    const adminTarget = await createAuthorForTesting({ username: 'admin-target-4', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });

    const add = await request(app)
      .post(`/api/admin/users/${adminTarget.id}/layer-grants`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ layerId: koelnLayerId });
    expect(add.status).toBe(201);
    expect(add.body.layerGrantIds).toEqual([koelnLayerId]);
  });

  it('allows topic grants against an admin target (#81: Admin kann zusaetzlich Autoren-Rechte haben)', async () => {
    await createAuthorForTesting({ username: 'admin-author-grantor-4', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    const adminToken = await loginAuthor('admin-author-grantor-4', 'admin-123');
    const adminTarget = await createAuthorForTesting({ username: 'admin-target-5', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    const topicId = await getTopicIdByLayerAndName(hamburgLayerId, 'Wölflinge');

    const add = await request(app)
      .post(`/api/admin/users/${adminTarget.id}/topic-grants`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ topicId });
    expect(add.status).toBe(201);
    expect(add.body.topicGrantIds).toEqual([topicId]);
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

async function getUserById(adminToken: string, userId: number): Promise<{ isAdmin: boolean; isActive: boolean; adminLayerIds: number[]; layerGrantIds: number[]; topicGrantIds: number[] }> {
  const response = await request(app)
    .get('/api/admin/users')
    .set('authorization', `Bearer ${adminToken}`);
  expect(response.status).toBe(200);
  const user = (response.body.users as Array<{ id: number }>).find((u) => u.id === userId);
  if (!user) {
    throw new Error(`User ${userId} not found in admin users list`);
  }
  return user as unknown as { isAdmin: boolean; isActive: boolean; adminLayerIds: number[]; layerGrantIds: number[]; topicGrantIds: number[] };
}

describe('Admin/Autor role fluidity (#81)', () => {
  it('promotes a non-admin author to admin by granting their first admin layer', async () => {
    const promoter = await createAuthorForTesting({ username: 'admin-promoter', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-promoter', 'admin-123');
    const author = await createAuthorForTesting({ username: 'author-to-promote', password: 'author-123', isAdmin: false, createdByAuthorId: promoter.id });

    const before = await getUserById(adminToken, author.id);
    expect(before.isAdmin).toBe(false);

    const add = await request(app)
      .post(`/api/admin/users/${author.id}/admin-layers`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ layerId: koelnLayerId });
    expect(add.status).toBe(201);

    const after = await getUserById(adminToken, author.id);
    expect(after.isAdmin).toBe(true);
    expect(after.adminLayerIds).toEqual([koelnLayerId]);
  });

  it('keeps an admin with author grants able to lose the author side without affecting admin status', async () => {
    await createAuthorForTesting({ username: 'admin-self-grantor', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-self-grantor', 'admin-123');
    const adminTarget = await createAuthorForTesting({ username: 'admin-target-6', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });

    const add = await request(app)
      .post(`/api/admin/users/${adminTarget.id}/layer-grants`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ layerId: koelnLayerId });
    expect(add.status).toBe(201);

    const remove = await request(app)
      .delete(`/api/admin/users/${adminTarget.id}/layer-grants/${koelnLayerId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(remove.status).toBe(204);

    const after = await getUserById(adminToken, adminTarget.id);
    expect(after.isAdmin).toBe(true);
    expect(after.isActive).toBe(true);
    expect(after.adminLayerIds).toEqual([koelnLayerId]);
  });

  it('auto-disables a non-admin author once their last author right is removed', async () => {
    const disabler = await createAuthorForTesting({ username: 'admin-disabler', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const adminToken = await loginAuthor('admin-disabler', 'admin-123');
    const author = await createAuthorForTesting({ username: 'author-to-disable', password: 'author-123', isAdmin: false, createdByAuthorId: disabler.id });

    const add = await request(app)
      .post(`/api/admin/users/${author.id}/layer-grants`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ layerId: koelnLayerId });
    expect(add.status).toBe(201);

    const before = await getUserById(adminToken, author.id);
    expect(before.isActive).toBe(true);

    const remove = await request(app)
      .delete(`/api/admin/users/${author.id}/layer-grants/${koelnLayerId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(remove.status).toBe(204);

    const after = await getUserById(adminToken, author.id);
    expect(after.isActive).toBe(false);
  });
});
