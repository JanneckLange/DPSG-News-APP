import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { clearAuthorData, clearEvents, close, connect, createAuthorForTesting } from '../src/db';
import { MAX_TITLE_LENGTH } from '../src/eventValidation';

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

describe('Topics API e2e', () => {
  it('exposes the seeded Hamburg topics', async () => {
    const response = await request(app).get('/api/topics').query({ layerId: hamburgLayerId });
    expect(response.status).toBe(200);

    const topics = response.body.topics as Array<{ id: number; name: string; layerId: number }>;
    expect(topics.length).toBeGreaterThan(0);
    expect(topics.every((topic) => topic.layerId === hamburgLayerId)).toBe(true);
    expect(topics.map((topic) => topic.name)).toEqual(
      expect.arrayContaining(['Wölflinge', 'Jungpfadfinder', 'Pfadfinder', 'Rover'])
    );
  });

  it('returns no topics for a layer without seeded topics', async () => {
    const response = await request(app).get('/api/topics').query({ layerId: koelnLayerId });
    expect(response.status).toBe(200);
    expect(response.body.topics).toEqual([]);
  });

  it('returns all topics when no layerId filter is given', async () => {
    const response = await request(app).get('/api/topics');
    expect(response.status).toBe(200);
    const topics = response.body.topics as Array<{ id: number; name: string; layerId: number }>;
    expect(topics.some((topic) => topic.layerId === hamburgLayerId)).toBe(true);
  });
});

describe('Topics admin CRUD e2e', () => {
  it('rejects topic creation and mutation for non-admins and unauthenticated users', async () => {
    await createAuthorForTesting({ username: 'author-topics', password: 'secret-123' });
    const token = await loginAuthor('author-topics', 'secret-123');

    const unauthenticated = await request(app).post('/api/admin/topics').send({ name: 'Meute', layerId: koelnLayerId });
    expect(unauthenticated.status).toBe(401);

    const nonAdmin = await request(app)
      .post('/api/admin/topics')
      .set('authorization', `Bearer ${token}`)
      .send({ name: 'Meute', layerId: koelnLayerId });
    expect(nonAdmin.status).toBe(403);
  });

  it('lets an admin create, rename and delete a topic, enforcing the delete guard', async () => {
    await createAuthorForTesting({ username: 'admin-topics', password: 'admin-123', isAdmin: true });
    const adminToken = await loginAuthor('admin-topics', 'admin-123');

    const createResponse = await request(app)
      .post('/api/admin/topics')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Meute', layerId: koelnLayerId });
    expect(createResponse.status).toBe(201);
    const createdTopic = createResponse.body.topic as { id: number; name: string; layerId: number };
    expect(createdTopic.name).toBe('Meute');
    expect(createdTopic.layerId).toBe(koelnLayerId);

    const renameResponse = await request(app)
      .patch(`/api/admin/topics/${createdTopic.id}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Meute Nord' });
    expect(renameResponse.status).toBe(200);
    expect(renameResponse.body.topic.name).toBe('Meute Nord');
    expect(renameResponse.body.topic.layerId).toBe(koelnLayerId);

    const eventResponse = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${adminToken}`)
      .send({
        title: 'Meutentreffen',
        description: 'Beschreibung',
        startDate: '2026-01-01T10:00:00Z',
        endDate: '2026-01-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
        topicId: createdTopic.id,
      });
    expect(eventResponse.status).toBe(201);

    const deleteInUseBlocked = await request(app)
      .delete(`/api/admin/topics/${createdTopic.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteInUseBlocked.status).toBe(409);

    await clearEvents();

    const deleteResponse = await request(app)
      .delete(`/api/admin/topics/${createdTopic.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteResponse.status).toBe(204);

    const deleteAgain = await request(app)
      .delete(`/api/admin/topics/${createdTopic.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteAgain.status).toBe(404);
  });

  it('rejects a duplicate topic name for the same layer with 409', async () => {
    await createAuthorForTesting({ username: 'admin-topics-dup', password: 'admin-123', isAdmin: true });
    const adminToken = await loginAuthor('admin-topics-dup', 'admin-123');

    const firstResponse = await request(app)
      .post('/api/admin/topics')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Rover', layerId: koelnLayerId });
    expect(firstResponse.status).toBe(201);
    const createdTopic = firstResponse.body.topic as { id: number };

    const duplicateResponse = await request(app)
      .post('/api/admin/topics')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Rover', layerId: koelnLayerId });
    expect(duplicateResponse.status).toBe(409);

    await request(app).delete(`/api/admin/topics/${createdTopic.id}`).set('authorization', `Bearer ${adminToken}`);
  });

  it('rejects creating a topic with an unknown layerId', async () => {
    await createAuthorForTesting({ username: 'admin-topics-invalid', password: 'admin-123', isAdmin: true });
    const adminToken = await loginAuthor('admin-topics-invalid', 'admin-123');

    const response = await request(app)
      .post('/api/admin/topics')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Ungültig', layerId: 999999 });
    expect(response.status).toBe(400);
  });

  it('rejects creating or renaming a topic with an oversized name', async () => {
    await createAuthorForTesting({ username: 'admin-topics-oversized', password: 'admin-123', isAdmin: true });
    const adminToken = await loginAuthor('admin-topics-oversized', 'admin-123');
    const oversizedName = 'a'.repeat(MAX_TITLE_LENGTH + 1);

    const createResponse = await request(app)
      .post('/api/admin/topics')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: oversizedName, layerId: koelnLayerId });
    expect(createResponse.status).toBe(400);

    const validCreateResponse = await request(app)
      .post('/api/admin/topics')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Kurzer Name', layerId: koelnLayerId });
    expect(validCreateResponse.status).toBe(201);
    const createdTopic = validCreateResponse.body.topic as { id: number };

    const renameResponse = await request(app)
      .patch(`/api/admin/topics/${createdTopic.id}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: oversizedName });
    expect(renameResponse.status).toBe(400);

    await request(app).delete(`/api/admin/topics/${createdTopic.id}`).set('authorization', `Bearer ${adminToken}`);
  });

  it('returns 404 when updating or deleting an unknown topic', async () => {
    await createAuthorForTesting({ username: 'admin-topics-404', password: 'admin-123', isAdmin: true });
    const adminToken = await loginAuthor('admin-topics-404', 'admin-123');

    const updateResponse = await request(app)
      .patch('/api/admin/topics/999999')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ name: 'Neuer Name' });
    expect(updateResponse.status).toBe(404);

    const deleteResponse = await request(app)
      .delete('/api/admin/topics/999999')
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteResponse.status).toBe(404);
  });
});
