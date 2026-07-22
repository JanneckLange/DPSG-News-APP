import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { Client } from 'pg';
import { clearAuthorData, clearDrafts, clearEvents, close, connect, createAuthorForTesting } from '../src/db';
import { sendEventNotification } from '../src/fcm';

async function loginAuthor(username: string, password: string): Promise<string> {
  const response = await request(app).post('/api/auth/login').send({ username, password });
  expect(response.status).toBe(200);
  return response.body.token as string;
}

async function getLayerIdByName(name: string): Promise<number> {
  const response = await request(app).get('/api/layers');
  expect(response.status).toBe(200);
  const layer = (response.body.layers as Array<{ id: number; name: string }>).find((l) => l.name === name);
  if (!layer) {
    throw new Error(`Layer "${name}" not found in seeded layers`);
  }
  return layer.id;
}

async function getTopicIdByName(layerId: number, name: string): Promise<number> {
  const response = await request(app).get('/api/topics').query({ layerId });
  expect(response.status).toBe(200);
  const topic = (response.body.topics as Array<{ id: number; name: string }>).find((t) => t.name === name);
  if (!topic) {
    throw new Error(`Topic "${name}" not found for layer ${layerId}`);
  }
  return topic.id;
}

async function forceUpdateDraftModifiedAt(draftId: number, modifiedAt: string): Promise<void> {
  const databaseUrl = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('TEST_DATABASE_URL or DATABASE_URL is required for tests');
  }
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    await client.query('UPDATE drafts SET modified_at = $1 WHERE id = $2', [modifiedAt, draftId]);
  } finally {
    await client.end();
  }
}

beforeAll(async () => {
  process.env.TEST_DATABASE_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  process.env.AUTHOR_BOOTSTRAP_USERNAME = process.env.AUTHOR_BOOTSTRAP_USERNAME || 'bootstrap-admin';
  process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD = process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD || 'bootstrap-one-time-password';
  await connect();
});

beforeEach(async () => {
  await clearEvents();
  await clearDrafts();
  await clearAuthorData();
});

afterAll(async () => {
  await close();
});

describe('Drafts API e2e', () => {
  it('requires authentication for every draft endpoint', async () => {
    const get = await request(app).get('/api/author/drafts');
    expect(get.status).toBe(401);

    const post = await request(app).post('/api/author/drafts').send({ title: 'Draft' });
    expect(post.status).toBe(401);

    const put = await request(app).put('/api/author/drafts/1').send({ title: 'Draft' });
    expect(put.status).toBe(401);

    const del = await request(app).delete('/api/author/drafts/1');
    expect(del.status).toBe(401);
  });

  it('allows an author to create a draft with title only', async () => {
    await createAuthorForTesting({ username: 'draft-author', password: 'pwd-123' });
    const token = await loginAuthor('draft-author', 'pwd-123');

    const res = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Draft only' });

    expect(res.status).toBe(201);
    expect(res.body.draft).toBeDefined();
    expect(res.body.draft.title).toBe('Draft only');
    expect(typeof res.body.draft.timeUntilDeletion).toBe('number');
    expect(res.body.draft.timeUntilDeletion).toBeGreaterThan(0);
    expect(sendEventNotification).not.toHaveBeenCalled();
  });

  it('accepts a draft with a valid layerId and rejects an unknown layerId', async () => {
    await createAuthorForTesting({ username: 'draft-author', password: 'pwd-123' });
    const token = await loginAuthor('draft-author', 'pwd-123');
    const koelnLayerId = await getLayerIdByName('Köln');

    const validRes = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Draft with layer', layerId: koelnLayerId });
    expect(validRes.status).toBe(201);
    expect(validRes.body.draft.layerId).toBe(koelnLayerId);

    const invalidRes = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Draft with bad layer', layerId: 999999 });
    expect(invalidRes.status).toBe(400);
  });

  it('accepts a draft with a valid topicId for the selected layer', async () => {
    await createAuthorForTesting({ username: 'draft-author-topic', password: 'pwd-123' });
    const token = await loginAuthor('draft-author-topic', 'pwd-123');
    const hamburgLayerId = await getLayerIdByName('Hamburg');
    const roverTopicId = await getTopicIdByName(hamburgLayerId, 'Rover');

    const res = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Draft with topic', layerId: hamburgLayerId, topicId: roverTopicId });
    expect(res.status).toBe(201);
    expect(res.body.draft.topicId).toBe(roverTopicId);
  });

  it('rejects a draft with an oversized CTA label', async () => {
    await createAuthorForTesting({ username: 'draft-author-cta', password: 'pwd-123' });
    const token = await loginAuthor('draft-author-cta', 'pwd-123');

    const res = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Draft', cta1Label: 'x'.repeat(21) });

    expect(res.status).toBe(400);
  });

  it('rejects a draft with a non-http CTA URL', async () => {
    await createAuthorForTesting({ username: 'draft-author-scheme', password: 'pwd-123' });
    const token = await loginAuthor('draft-author-scheme', 'pwd-123');

    const res = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Draft', cta1Url: 'file:///etc/passwd' });

    expect(res.status).toBe(400);
  });

  it('rejects draft creation and update without a title', async () => {
    await createAuthorForTesting({ username: 'draft-author', password: 'pwd-123' });
    const token = await loginAuthor('draft-author', 'pwd-123');

    const createRes = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${token}`)
      .send({ description: 'No title' });
    expect(createRes.status).toBe(400);
  });

  it('only returns the author\'s own drafts, never another author\'s', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'pwd-123' });
    await createAuthorForTesting({ username: 'author-b', password: 'pwd-456' });
    const tokenA = await loginAuthor('author-a', 'pwd-123');
    const tokenB = await loginAuthor('author-b', 'pwd-456');

    await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${tokenA}`)
      .send({ title: 'Draft A' });
    await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${tokenB}`)
      .send({ title: 'Draft B' });

    const listA = await request(app)
      .get('/api/author/drafts')
      .set('authorization', `Bearer ${tokenA}`);
    expect(listA.status).toBe(200);
    expect(listA.body.drafts).toHaveLength(1);
    expect(listA.body.drafts[0].title).toBe('Draft A');
  });

  it('does not let a foreign author update or delete a draft', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'pwd-123' });
    await createAuthorForTesting({ username: 'author-b', password: 'pwd-456' });
    const tokenA = await loginAuthor('author-a', 'pwd-123');
    const tokenB = await loginAuthor('author-b', 'pwd-456');

    const created = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${tokenA}`)
      .send({ title: 'Private draft' });
    const draftId = created.body.draft.id as number;

    const foreignUpdate = await request(app)
      .put(`/api/author/drafts/${draftId}`)
      .set('authorization', `Bearer ${tokenB}`)
      .send({ title: 'Hijacked' });
    expect(foreignUpdate.status).toBe(404);

    const foreignDelete = await request(app)
      .delete(`/api/author/drafts/${draftId}`)
      .set('authorization', `Bearer ${tokenB}`);
    expect(foreignDelete.status).toBe(404);
  });

  it('updates and deletes own draft', async () => {
    await createAuthorForTesting({ username: 'draft-author', password: 'pwd-123' });
    const token = await loginAuthor('draft-author', 'pwd-123');

    const created = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Original' });
    const draftId = created.body.draft.id as number;

    const updated = await request(app)
      .put(`/api/author/drafts/${draftId}`)
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Updated', description: 'Now with a description' });
    expect(updated.status).toBe(200);
    expect(updated.body.draft.title).toBe('Updated');
    expect(sendEventNotification).not.toHaveBeenCalled();

    const deleted = await request(app)
      .delete(`/api/author/drafts/${draftId}`)
      .set('authorization', `Bearer ${token}`);
    expect(deleted.status).toBe(204);

    const list = await request(app)
      .get('/api/author/drafts')
      .set('authorization', `Bearer ${token}`);
    expect(list.body.drafts).toHaveLength(0);
  });

  it('never exposes drafts through the event endpoints, not even to admins', async () => {
    await createAuthorForTesting({ username: 'draft-author', password: 'pwd-123' });
    await createAuthorForTesting({ username: 'admin-user', password: 'admin-123', isAdmin: true });
    const draftToken = await loginAuthor('draft-author', 'pwd-123');
    const adminToken = await loginAuthor('admin-user', 'admin-123');

    const created = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${draftToken}`)
      .send({ title: 'Private draft' });
    const draftId = created.body.draft.id as number;

    const publicResponse = await request(app).get('/api/events');
    expect(publicResponse.status).toBe(200);
    expect((publicResponse.body.events as Array<{ title?: string }>).find((event) => event.title === 'Private draft')).toBeUndefined();

    const adminResponse = await request(app)
      .get('/api/events')
      .set('authorization', `Bearer ${adminToken}`);
    expect(adminResponse.status).toBe(200);
    expect((adminResponse.body.events as Array<{ title?: string }>).find((event) => event.title === 'Private draft')).toBeUndefined();

    const ownEventsResponse = await request(app)
      .get('/api/author/events')
      .set('authorization', `Bearer ${draftToken}`);
    expect(ownEventsResponse.status).toBe(200);
    expect(ownEventsResponse.body.events).toHaveLength(0);

    const koelnLayerId = await getLayerIdByName('Köln');

    const adminEditAttempt = await request(app)
      .put(`/api/events/${draftId}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({
        title: 'Taken over by admin',
        description: 'Body',
        startDate: '2026-06-01T10:00:00Z',
        endDate: '2026-06-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(adminEditAttempt.status).toBe(404);

    const adminDeleteAttempt = await request(app)
      .delete(`/api/events/${draftId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(adminDeleteAttempt.status).toBe(404);

    const authorEditAttemptViaEventsPath = await request(app)
      .put(`/api/author/events/${draftId}`)
      .set('authorization', `Bearer ${draftToken}`)
      .send({
        title: 'Taken over via events path',
        description: 'Body',
        startDate: '2026-06-01T10:00:00Z',
        endDate: '2026-06-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(authorEditAttemptViaEventsPath.status).toBe(404);
  });

  it('deletes expired drafts after the retention window', async () => {
    await createAuthorForTesting({ username: 'draft-author', password: 'pwd-123' });
    const token = await loginAuthor('draft-author', 'pwd-123');

    const created = await request(app)
      .post('/api/author/drafts')
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Expired draft' });
    const draftId = created.body.draft.id as number;

    await forceUpdateDraftModifiedAt(draftId, '1999-01-01T00:00:00Z');

    const list = await request(app)
      .get('/api/author/drafts')
      .set('authorization', `Bearer ${token}`);
    expect(list.status).toBe(200);
    expect((list.body.drafts as Array<{ id?: number }>).find((draft) => draft.id === draftId)).toBeUndefined();
  });
});
