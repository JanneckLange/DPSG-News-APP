import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
  sendEventUpdateNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { clearAuthorData, clearEvents, close, connect, createAuthorForTesting } from '../src/db';
import { sendEventUpdateNotification } from '../src/fcm';

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

let koelnLayerId: number;
let hamburgLayerId: number;

async function createEvent(token: string, title: string): Promise<number> {
  const response = await request(app)
    .post('/api/author/events')
    .set('authorization', `Bearer ${token}`)
    .send({
      title,
      description: 'Beschreibung',
      startDate: '2026-05-01T10:00:00Z',
      endDate: '2026-05-01T12:00:00Z',
      location: 'Ort',
      layerId: koelnLayerId,
    });
  expect(response.status).toBe(201);
  return response.body.event.id as number;
}

beforeAll(async () => {
  process.env.TEST_DATABASE_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  process.env.AUTHOR_BOOTSTRAP_USERNAME = process.env.AUTHOR_BOOTSTRAP_USERNAME || 'bootstrap-admin';
  process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD = process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD || 'bootstrap-one-time-password';
  await connect();
  koelnLayerId = await getLayerIdByName('Köln');
  hamburgLayerId = await getLayerIdByName('Hamburg');
});

beforeEach(async () => {
  await clearEvents();
  await clearAuthorData();
  (sendEventUpdateNotification as jest.Mock).mockClear();
});

afterAll(async () => {
  await close();
});

describe('Event updates API e2e', () => {
  it('requires authentication to post an update, but not to read updates', async () => {
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('evtupd-author', 'pwd-123');
    const eventId = await createEvent(token, 'Event ohne Auth-Test');

    const post = await request(app).post(`/api/events/${eventId}/updates`).send({ message: 'Hallo' });
    expect(post.status).toBe(401);

    const get = await request(app).get(`/api/events/${eventId}/updates`);
    expect(get.status).toBe(200);
    expect(get.body.updates).toEqual([]);
  });

  it('lets the event creator post an update and shows author + timestamp', async () => {
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('evtupd-author', 'pwd-123');
    const eventId = await createEvent(token, 'Event mit Update');

    const post = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: '**Wichtig:** Ort geändert.' });

    expect(post.status).toBe(201);
    expect(post.body.update).toMatchObject({
      eventId,
      authorUsername: 'evtupd-author',
      message: '**Wichtig:** Ort geändert.',
    });
    expect(typeof post.body.update.createdAt).toBe('string');
    expect(sendEventUpdateNotification).toHaveBeenCalledWith({
      eventId,
      eventTitle: 'Event mit Update',
      message: '**Wichtig:** Ort geändert.',
    });

    const list = await request(app).get(`/api/events/${eventId}/updates`);
    expect(list.status).toBe(200);
    expect(list.body.updates).toHaveLength(1);
    expect(list.body.updates[0].message).toBe('**Wichtig:** Ort geändert.');
  });

  it('exposes lastUpdateAt on the event once an update has been posted', async () => {
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('evtupd-author', 'pwd-123');
    const eventId = await createEvent(token, 'Event ohne Update');

    const beforeUpdate = await request(app)
      .get('/api/author/events')
      .set('authorization', `Bearer ${token}`);
    expect(beforeUpdate.status).toBe(200);
    expect(beforeUpdate.body.events[0].lastUpdateAt).toBeUndefined();

    const firstUpdate = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'Erstes Update' });
    expect(firstUpdate.status).toBe(201);

    const afterFirstUpdate = await request(app)
      .get('/api/author/events')
      .set('authorization', `Bearer ${token}`);
    const lastUpdateAtAfterFirst = afterFirstUpdate.body.events[0].lastUpdateAt as string;
    expect(typeof lastUpdateAtAfterFirst).toBe('string');
    expect(new Date(lastUpdateAtAfterFirst).getTime()).toBeGreaterThanOrEqual(
      new Date(afterFirstUpdate.body.events[0].createdAt).getTime(),
    );

    const secondUpdate = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'Zweites, neueres Update' });
    expect(secondUpdate.status).toBe(201);

    const afterSecondUpdate = await request(app)
      .get('/api/author/events')
      .set('authorization', `Bearer ${token}`);
    const lastUpdateAtAfterSecond = afterSecondUpdate.body.events[0].lastUpdateAt as string;
    expect(new Date(lastUpdateAtAfterSecond).getTime()).toBeGreaterThanOrEqual(
      new Date(lastUpdateAtAfterFirst).getTime(),
    );

    // Auch der oeffentliche Endpunkt liefert lastUpdateAt.
    const publicEvents = await request(app).get('/api/events');
    expect(publicEvents.status).toBe(200);
    expect(publicEvents.body.events[0].lastUpdateAt).toBe(lastUpdateAtAfterSecond);
  });

  it('forbids a foreign author (neither creator nor admin) from posting an update', async () => {
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'evtupd-other', password: 'pwd-456' });
    const ownerToken = await loginAuthor('evtupd-author', 'pwd-123');
    const otherToken = await loginAuthor('evtupd-other', 'pwd-456');
    const eventId = await createEvent(ownerToken, 'Fremdes Event');

    const post = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${otherToken}`)
      .send({ message: 'Darf ich das?' });

    expect(post.status).toBe(403);
  });

  it('forbids an admin from posting an update, even with matching layer scope (create update ist ausschliesslich Autoren vorbehalten)', async () => {
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'evtupd-admin', password: 'pwd-789', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const ownerToken = await loginAuthor('evtupd-author', 'pwd-123');
    const adminToken = await loginAuthor('evtupd-admin', 'pwd-789');
    const eventId = await createEvent(ownerToken, 'Event für Admin-Update');

    const post = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ message: 'Admin-Update' });

    expect(post.status).toBe(403);
  });

  it('rejects an empty update message', async () => {
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('evtupd-author', 'pwd-123');
    const eventId = await createEvent(token, 'Event ohne Nachricht');

    const post = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: '   ' });

    expect(post.status).toBe(400);
  });

  it('rejects a non-string update message instead of crashing', async () => {
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('evtupd-author', 'pwd-123');
    const eventId = await createEvent(token, 'Event mit falschem Typ');

    const post = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 12345 });

    expect(post.status).toBe(400);
  });

  it('rejects an oversized update message', async () => {
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('evtupd-author', 'pwd-123');
    const eventId = await createEvent(token, 'Event mit zu langer Nachricht');

    const post = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'x'.repeat(1001) });

    expect(post.status).toBe(400);
  });

  it('returns 404 for updates on a non-existent event, 400 for an invalid id', async () => {
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('evtupd-author', 'pwd-123');

    const missing = await request(app)
      .post('/api/events/999999/updates')
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'Hallo' });
    expect(missing.status).toBe(404);

    const invalid = await request(app)
      .post('/api/events/not-a-number/updates')
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'Hallo' });
    expect(invalid.status).toBe(400);

    const missingGet = await request(app).get('/api/events/999999/updates');
    expect(missingGet.status).toBe(404);
  });

  it('continues when the update notification fails to send', async () => {
    (sendEventUpdateNotification as jest.Mock).mockRejectedValueOnce(new Error('FCM down'));
    await createAuthorForTesting({ username: 'evtupd-author', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('evtupd-author', 'pwd-123');
    const eventId = await createEvent(token, 'Event mit Push-Fehler');

    const post = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'Trotzdem gespeichert' });

    expect(post.status).toBe(201);
    expect(post.body.update.message).toBe('Trotzdem gespeichert');
  });

  it('lets the update author edit and delete their own update', async () => {
    await createAuthorForTesting({ username: 'evtupd-edit-owner', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('evtupd-edit-owner', 'pwd-123');
    const eventId = await createEvent(token, 'Event mit eigenem Update');
    const create = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'Erste Fassung' });
    const updateId = create.body.update.id as number;

    const edit = await request(app)
      .put(`/api/events/${eventId}/updates/${updateId}`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'Korrigierte Fassung' });
    expect(edit.status).toBe(200);
    expect(edit.body.update.message).toBe('Korrigierte Fassung');

    const del = await request(app)
      .delete(`/api/events/${eventId}/updates/${updateId}`)
      .set('authorization', `Bearer ${token}`);
    expect(del.status).toBe(204);

    const list = await request(app).get(`/api/events/${eventId}/updates`);
    expect(list.body.updates).toHaveLength(0);
  });

  it('forbids a foreign author from editing or deleting someone else\'s update', async () => {
    await createAuthorForTesting({ username: 'evtupd-edit-victim', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'evtupd-edit-attacker', password: 'pwd-456', layerGrantIds: [koelnLayerId] });
    const ownerToken = await loginAuthor('evtupd-edit-victim', 'pwd-123');
    const otherToken = await loginAuthor('evtupd-edit-attacker', 'pwd-456');
    const eventId = await createEvent(ownerToken, 'Event mit fremdem Update');
    const create = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${ownerToken}`)
      .send({ message: 'Original' });
    const updateId = create.body.update.id as number;

    const edit = await request(app)
      .put(`/api/events/${eventId}/updates/${updateId}`)
      .set('authorization', `Bearer ${otherToken}`)
      .send({ message: 'Manipuliert' });
    expect(edit.status).toBe(403);

    const del = await request(app)
      .delete(`/api/events/${eventId}/updates/${updateId}`)
      .set('authorization', `Bearer ${otherToken}`);
    expect(del.status).toBe(403);
  });

  it('lets an admin with matching layer scope edit and delete a foreign update', async () => {
    await createAuthorForTesting({ username: 'evtupd-scope-owner', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'evtupd-scope-admin', password: 'pwd-789', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const ownerToken = await loginAuthor('evtupd-scope-owner', 'pwd-123');
    const adminToken = await loginAuthor('evtupd-scope-admin', 'pwd-789');
    const eventId = await createEvent(ownerToken, 'Event fuer Admin-Scope-Update');
    const create = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${ownerToken}`)
      .send({ message: 'Original' });
    const updateId = create.body.update.id as number;

    const edit = await request(app)
      .put(`/api/events/${eventId}/updates/${updateId}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ message: 'Von Admin korrigiert' });
    expect(edit.status).toBe(200);
    expect(edit.body.update.message).toBe('Von Admin korrigiert');

    const del = await request(app)
      .delete(`/api/events/${eventId}/updates/${updateId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(del.status).toBe(204);
  });

  it('forbids an admin without matching layer scope from editing or deleting a foreign update', async () => {
    await createAuthorForTesting({ username: 'evtupd-noscope-owner', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'evtupd-noscope-admin', password: 'pwd-789', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    const ownerToken = await loginAuthor('evtupd-noscope-owner', 'pwd-123');
    const adminToken = await loginAuthor('evtupd-noscope-admin', 'pwd-789');
    const eventId = await createEvent(ownerToken, 'Event ausserhalb Admin-Scope');
    const create = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${ownerToken}`)
      .send({ message: 'Original' });
    const updateId = create.body.update.id as number;

    const edit = await request(app)
      .put(`/api/events/${eventId}/updates/${updateId}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ message: 'Darf ich nicht' });
    expect(edit.status).toBe(403);

    const del = await request(app)
      .delete(`/api/events/${eventId}/updates/${updateId}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(del.status).toBe(403);
  });

  it('returns 404 when editing/deleting an unknown update or one belonging to a different event', async () => {
    await createAuthorForTesting({ username: 'evtupd-404-author', password: 'pwd-123', layerGrantIds: [koelnLayerId, hamburgLayerId] });
    const token = await loginAuthor('evtupd-404-author', 'pwd-123');
    const eventId = await createEvent(token, 'Event A');
    const otherEventResponse = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Event B',
        description: 'Beschreibung',
        startDate: '2026-05-01T10:00:00Z',
        endDate: '2026-05-01T12:00:00Z',
        location: 'Ort',
        layerId: hamburgLayerId,
      });
    const otherEventId = otherEventResponse.body.event.id as number;
    const create = await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'Original' });
    const updateId = create.body.update.id as number;

    const missingUpdate = await request(app)
      .put(`/api/events/${eventId}/updates/999999`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'x' });
    expect(missingUpdate.status).toBe(404);

    const mismatchedEvent = await request(app)
      .put(`/api/events/${otherEventId}/updates/${updateId}`)
      .set('authorization', `Bearer ${token}`)
      .send({ message: 'x' });
    expect(mismatchedEvent.status).toBe(404);

    const invalidId = await request(app)
      .delete(`/api/events/${eventId}/updates/not-a-number`)
      .set('authorization', `Bearer ${token}`);
    expect(invalidId.status).toBe(400);
  });

  it('personalizes canEdit/canDelete on the updates list based on the requester', async () => {
    await createAuthorForTesting({ username: 'evtupd-flags-owner', password: 'pwd-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'evtupd-flags-other', password: 'pwd-456', layerGrantIds: [koelnLayerId] });
    const ownerToken = await loginAuthor('evtupd-flags-owner', 'pwd-123');
    const otherToken = await loginAuthor('evtupd-flags-other', 'pwd-456');
    const eventId = await createEvent(ownerToken, 'Event fuer Flag-Test');
    await request(app)
      .post(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${ownerToken}`)
      .send({ message: 'Original' });

    const anonymous = await request(app).get(`/api/events/${eventId}/updates`);
    expect(anonymous.body.updates[0].canEdit).toBe(false);
    expect(anonymous.body.updates[0].canDelete).toBe(false);

    const owner = await request(app)
      .get(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${ownerToken}`);
    expect(owner.body.updates[0].canEdit).toBe(true);
    expect(owner.body.updates[0].canDelete).toBe(true);

    const foreign = await request(app)
      .get(`/api/events/${eventId}/updates`)
      .set('authorization', `Bearer ${otherToken}`);
    expect(foreign.body.updates[0].canEdit).toBe(false);
    expect(foreign.body.updates[0].canDelete).toBe(false);
  });
});
