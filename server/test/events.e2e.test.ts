import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { clearAuthorData, clearEvents, close, connect, createAuthorForTesting } from '../src/db';
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

let koelnLayerId: number;
let hamburgLayerId: number;
let hamburgRoverTopicId: number;

beforeAll(async () => {
  process.env.TEST_DATABASE_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  process.env.AUTHOR_BOOTSTRAP_USERNAME = process.env.AUTHOR_BOOTSTRAP_USERNAME || 'bootstrap-admin';
  process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD = process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD || 'bootstrap-one-time-password';
  await connect();
  koelnLayerId = await getLayerIdByName('Köln');
  hamburgLayerId = await getLayerIdByName('Hamburg');
  hamburgRoverTopicId = await getTopicIdByName(hamburgLayerId, 'Rover');
});

beforeEach(async () => {
  await clearEvents();
  await clearAuthorData();
});

describe('Events API e2e', () => {
  it('requires authentication for author event writes', async () => {
    const response = await request(app).post('/api/events').send({
      title: 'Unauthorized',
      description: 'No token',
      startDate: '2026-01-01T10:00:00Z',
      endDate: '2026-01-01T12:00:00Z',
      location: 'Ort',
      layerId: koelnLayerId,
    });

    expect(response.status).toBe(401);
    expect(response.body).toEqual({ error: 'Unauthorized' });
  });

  it('rejects a title-only event as invalid (events always require full data)', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    const token = await loginAuthor('author-a', 'secret-123');

    const res = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({ title: 'Title only' });

    expect(res.status).toBe(400);
  });

  it('allows creating and updating events without an endDate (falls back to startDate)', async () => {
    await createAuthorForTesting({ username: 'author-enddate', password: 'secret-123' });
    const token = await loginAuthor('author-enddate', 'secret-123');

    const createResponse = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Ohne Enddatum',
        description: 'Beschreibung',
        startDate: '2026-04-01T10:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(createResponse.status).toBe(201);
    expect(createResponse.body.event.endDate).toBe('2026-04-01T10:00:00.000Z');

    const publicCreateResponse = await request(app)
      .post('/api/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Ohne Enddatum (public)',
        description: 'Beschreibung',
        startDate: '2026-04-02T10:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(publicCreateResponse.status).toBe(201);
    expect(publicCreateResponse.body.event.endDate).toBe('2026-04-02T10:00:00.000Z');

    const eventId = createResponse.body.event.id as number;
    const updateResponse = await request(app)
      .put(`/api/author/events/${eventId}`)
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Ohne Enddatum aktualisiert',
        description: 'Beschreibung',
        startDate: '2026-04-03T10:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(updateResponse.status).toBe(200);
    expect(updateResponse.body.event.endDate).toBe('2026-04-03T10:00:00.000Z');
  });

  it('creates and returns own events for authenticated author', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    const token = await loginAuthor('author-a', 'secret-123');

    const eventBody = {
      title: 'Test Event',
      description: 'Beschreibung',
      startDate: '2026-01-01T10:00:00Z',
      endDate: '2026-01-01T12:00:00Z',
      location: 'Ort',
      layerId: koelnLayerId,
    };

    const createResponse = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send(eventBody);
    expect(createResponse.status).toBe(201);
    expect(createResponse.body.event).toMatchObject({
      title: eventBody.title,
      description: eventBody.description,
      location: eventBody.location,
      layerId: eventBody.layerId,
      authorId: expect.any(Number),
    });

    const ownResponse = await request(app)
      .get('/api/author/events')
      .set('authorization', `Bearer ${token}`);
    expect(ownResponse.status).toBe(200);
    expect(ownResponse.body.events).toHaveLength(1);
    expect(ownResponse.body.events[0].title).toBe('Test Event');
  });

  it('persists and returns CTA button fields through create and update', async () => {
    await createAuthorForTesting({ username: 'author-cta', password: 'secret-123' });
    const token = await loginAuthor('author-cta', 'secret-123');

    const createResponse = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Event mit Buttons',
        description: 'Beschreibung',
        startDate: '2026-05-01T10:00:00Z',
        endDate: '2026-05-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
        cta1Label: 'Anmelden',
        cta1Url: 'https://example.org/anmeldung',
        cta2Label: 'Mehr Infos',
        cta2Url: 'https://example.org/infos',
      });
    expect(createResponse.status).toBe(201);
    expect(createResponse.body.event).toMatchObject({
      cta1Label: 'Anmelden',
      cta1Url: 'https://example.org/anmeldung',
      cta2Label: 'Mehr Infos',
      cta2Url: 'https://example.org/infos',
    });

    const eventId = createResponse.body.event.id as number;
    const publicResponse = await request(app).get('/api/events');
    expect(publicResponse.status).toBe(200);
    expect(publicResponse.body.events[0]).toMatchObject({
      cta1Label: 'Anmelden',
      cta1Url: 'https://example.org/anmeldung',
      cta2Label: 'Mehr Infos',
      cta2Url: 'https://example.org/infos',
    });

    const updateResponse = await request(app)
      .put(`/api/author/events/${eventId}`)
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Event mit Buttons aktualisiert',
        description: 'Beschreibung',
        startDate: '2026-05-01T10:00:00Z',
        endDate: '2026-05-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
        cta1Label: 'Jetzt anmelden',
        cta1Url: 'https://example.org/anmeldung-neu',
      });
    expect(updateResponse.status).toBe(200);
    expect(updateResponse.body.event).toMatchObject({
      cta1Label: 'Jetzt anmelden',
      cta1Url: 'https://example.org/anmeldung-neu',
    });
    expect(updateResponse.body.event.cta2Label).toBeUndefined();
    expect(updateResponse.body.event.cta2Url).toBeUndefined();
  });

  it('rejects events with an oversized title', async () => {
    await createAuthorForTesting({ username: 'author-oversized', password: 'secret-123' });
    const token = await loginAuthor('author-oversized', 'secret-123');

    const response = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'x'.repeat(101),
        description: 'Beschreibung',
        startDate: '2026-05-01T10:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(response.status).toBe(400);
  });

  it('rejects a CTA URL with a javascript: scheme', async () => {
    await createAuthorForTesting({ username: 'author-xss', password: 'secret-123' });
    const token = await loginAuthor('author-xss', 'secret-123');

    const response = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Event',
        description: 'Beschreibung',
        startDate: '2026-05-01T10:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
        cta1Label: 'Klick mich',
        cta1Url: 'javascript:alert(1)',
      });
    expect(response.status).toBe(400);
  });

  it('rejects an unknown layerId', async () => {
    await createAuthorForTesting({ username: 'author-unknown-layer', password: 'secret-123' });
    const token = await loginAuthor('author-unknown-layer', 'secret-123');

    const response = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Event',
        description: 'Beschreibung',
        startDate: '2026-05-01T10:00:00Z',
        location: 'Ort',
        layerId: 999999,
      });
    expect(response.status).toBe(400);
  });

  it('rejects a topicId that does not belong to the selected layer', async () => {
    await createAuthorForTesting({ username: 'author-bad-topic', password: 'secret-123' });
    const token = await loginAuthor('author-bad-topic', 'secret-123');

    const response = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Event',
        description: 'Beschreibung',
        startDate: '2026-05-01T10:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
        topicId: hamburgRoverTopicId,
      });
    expect(response.status).toBe(400);
  });

  it('accepts a topicId that belongs to the selected layer', async () => {
    await createAuthorForTesting({ username: 'author-good-topic', password: 'secret-123' });
    const token = await loginAuthor('author-good-topic', 'secret-123');

    const response = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Event',
        description: 'Beschreibung',
        startDate: '2026-05-01T10:00:00Z',
        location: 'Ort',
        layerId: hamburgLayerId,
        topicId: hamburgRoverTopicId,
      });
    expect(response.status).toBe(201);
    expect(response.body.event.topicId).toBe(hamburgRoverTopicId);
  });

  it('shows all events in public endpoint but only own events in author endpoint', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    await createAuthorForTesting({ username: 'author-b', password: 'secret-456' });
    const tokenA = await loginAuthor('author-a', 'secret-123');
    const tokenB = await loginAuthor('author-b', 'secret-456');

    await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${tokenA}`)
      .send({
        title: 'Event A',
        description: 'A',
        startDate: '2026-01-01T10:00:00Z',
        endDate: '2026-01-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${tokenB}`)
      .send({
        title: 'Event B',
        description: 'B',
        startDate: '2026-02-01T10:00:00Z',
        endDate: '2026-02-01T12:00:00Z',
        location: 'Ort',
        layerId: hamburgLayerId,
      });

    const publicResponse = await request(app).get('/api/events');
    expect(publicResponse.status).toBe(200);
    expect(publicResponse.body.events).toHaveLength(2);

    const ownResponse = await request(app)
      .get('/api/author/events')
      .set('authorization', `Bearer ${tokenA}`);
    expect(ownResponse.status).toBe(200);
    expect(ownResponse.body.events).toHaveLength(1);
    expect(ownResponse.body.events[0].title).toBe('Event A');
  });

  it('updates and deletes own event only', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    await createAuthorForTesting({ username: 'author-b', password: 'secret-456' });
    const tokenA = await loginAuthor('author-a', 'secret-123');
    const tokenB = await loginAuthor('author-b', 'secret-456');

    const createResponse = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${tokenA}`)
      .send({
        title: 'Original',
        description: 'Body',
        startDate: '2026-03-01T10:00:00Z',
        endDate: '2026-03-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    const eventId = createResponse.body.event.id as number;

    const foreignUpdate = await request(app)
      .put(`/api/author/events/${eventId}`)
      .set('authorization', `Bearer ${tokenB}`)
      .send({
        title: 'Updated',
        description: 'Body',
        startDate: '2026-03-01T10:00:00Z',
        endDate: '2026-03-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(foreignUpdate.status).toBe(404);

    const ownUpdate = await request(app)
      .put(`/api/author/events/${eventId}`)
      .set('authorization', `Bearer ${tokenA}`)
      .send({
        title: 'Updated',
        description: 'Body',
        startDate: '2026-03-01T10:00:00Z',
        endDate: '2026-03-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(ownUpdate.status).toBe(200);
    expect(ownUpdate.body.event.title).toBe('Updated');

    const foreignDelete = await request(app)
      .delete(`/api/author/events/${eventId}`)
      .set('authorization', `Bearer ${tokenB}`);
    expect(foreignDelete.status).toBe(404);

    const ownDelete = await request(app)
      .delete(`/api/author/events/${eventId}`)
      .set('authorization', `Bearer ${tokenA}`);
    expect(ownDelete.status).toBe(204);
  });

  it('requires password change after one-time password login', async () => {
    await createAuthorForTesting({
      username: 'author-otp',
      password: 'secret-123',
      oneTimePassword: 'otp-123456',
      mustChangePassword: false,
    });

    const token = await loginAuthor('author-otp', 'otp-123456');
    const meResponse = await request(app)
      .get('/api/auth/me')
      .set('authorization', `Bearer ${token}`);
    expect(meResponse.status).toBe(200);
    expect(meResponse.body.requiresPasswordChange).toBe(true);

    const createBlocked = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Blocked',
        description: 'Blocked',
        startDate: '2026-01-01T10:00:00Z',
        endDate: '2026-01-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(createBlocked.status).toBe(403);
    expect(createBlocked.body).toEqual({ error: 'Password change required' });

    const changeResponse = await request(app)
      .post('/api/auth/change-password')
      .set('authorization', `Bearer ${token}`)
      .send({
        newPassword: 'new-secret-123',
      });
    expect(changeResponse.status).toBe(204);

    const createAllowed = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Allowed',
        description: 'Allowed',
        startDate: '2026-01-01T10:00:00Z',
        endDate: '2026-01-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(createAllowed.status).toBe(401);

    const relogin = await request(app).post('/api/auth/login').send({
      username: 'author-otp',
      password: 'new-secret-123',
    });
    expect(relogin.status).toBe(200);
    const refreshedToken = relogin.body.token as string;

    const createAfterRelogin = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${refreshedToken}`)
      .send({
        title: 'Allowed after relogin',
        description: 'Allowed',
        startDate: '2026-01-01T10:00:00Z',
        endDate: '2026-01-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(createAfterRelogin.status).toBe(201);

    const loginWithOtpFails = await request(app).post('/api/auth/login').send({
      username: 'author-otp',
      password: 'otp-123456',
    });
    expect(loginWithOtpFails.status).toBe(401);
  });

  it('changes password with old password for regular login', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    const token = await loginAuthor('author-a', 'secret-123');

    const invalidOldPassword = await request(app)
      .post('/api/auth/change-password')
      .set('authorization', `Bearer ${token}`)
      .send({
        oldPassword: 'wrong-password',
        newPassword: 'new-secret-123',
      });
    expect(invalidOldPassword.status).toBe(400);

    const changeResponse = await request(app)
      .post('/api/auth/change-password')
      .set('authorization', `Bearer ${token}`)
      .send({
        oldPassword: 'secret-123',
        newPassword: 'new-secret-123',
      });
    expect(changeResponse.status).toBe(204);

    const oldLogin = await request(app).post('/api/auth/login').send({
      username: 'author-a',
      password: 'secret-123',
    });
    expect(oldLogin.status).toBe(401);
  });

  it('rotates refresh tokens and invalidates reused refresh tokens', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    const loginResponse = await request(app).post('/api/auth/login').send({
      username: 'author-a',
      password: 'secret-123',
    });
    expect(loginResponse.status).toBe(200);
    const refreshToken = loginResponse.body.refreshToken as string;
    expect(refreshToken).toEqual(expect.any(String));

    const refreshResponse = await request(app).post('/api/auth/refresh').send({ refreshToken });
    expect(refreshResponse.status).toBe(200);
    expect(refreshResponse.body.token).toEqual(expect.any(String));
    expect(refreshResponse.body.refreshToken).toEqual(expect.any(String));
    expect(refreshResponse.body.refreshToken).not.toBe(refreshToken);

    const replayResponse = await request(app).post('/api/auth/refresh').send({ refreshToken });
    expect(replayResponse.status).toBe(401);
  });

  it('revokes active sessions and refresh tokens on password change', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    const loginResponse = await request(app).post('/api/auth/login').send({
      username: 'author-a',
      password: 'secret-123',
    });
    expect(loginResponse.status).toBe(200);
    const token = loginResponse.body.token as string;
    const refreshToken = loginResponse.body.refreshToken as string;

    const changeResponse = await request(app)
      .post('/api/auth/change-password')
      .set('authorization', `Bearer ${token}`)
      .send({
        oldPassword: 'secret-123',
        newPassword: 'new-secret-123',
      });
    expect(changeResponse.status).toBe(204);

    const meResponse = await request(app)
      .get('/api/auth/me')
      .set('authorization', `Bearer ${token}`);
    expect(meResponse.status).toBe(401);

    const refreshResponse = await request(app).post('/api/auth/refresh').send({ refreshToken });
    expect(refreshResponse.status).toBe(401);
  });

  it('continues when notification sending fails', async () => {
    (sendEventNotification as jest.Mock).mockRejectedValueOnce(new Error('FCM down'));
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    const token = await loginAuthor('author-a', 'secret-123');

    const response = await request(app)
      .post('/api/events')
      .set('authorization', `Bearer ${token}`)
      .send({
        title: 'Notification Test',
        description: 'Should still create event',
        startDate: '2026-05-01T10:00:00Z',
        endDate: '2026-05-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });

    expect(response.status).toBe(201);
    expect(response.body.event).toMatchObject({ title: 'Notification Test' });
  });

  it('exposes creator metadata and edit rights to admins', async () => {
    await createAuthorForTesting({ username: 'author-a', password: 'secret-123' });
    await createAuthorForTesting({ username: 'admin', password: 'admin-123', isAdmin: true });
    const authorToken = await loginAuthor('author-a', 'secret-123');
    const adminToken = await loginAuthor('admin', 'admin-123');

    const createResponse = await request(app)
      .post('/api/author/events')
      .set('authorization', `Bearer ${authorToken}`)
      .send({
        title: 'Editable',
        description: 'Body',
        startDate: '2026-06-01T10:00:00Z',
        endDate: '2026-06-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    const eventId = createResponse.body.event.id as number;

    const publicResponse = await request(app).get('/api/events');
    expect(publicResponse.status).toBe(200);
    expect(publicResponse.body.events[0].canEdit).toBe(false);
    expect(publicResponse.body.events[0].createdBy).toBeUndefined();

    const adminResponse = await request(app)
      .get('/api/events')
      .set('authorization', `Bearer ${adminToken}`);
    expect(adminResponse.status).toBe(200);
    expect(adminResponse.body.events[0].canEdit).toBe(true);
    expect(adminResponse.body.events[0].createdBy).toBe('author-a');

    const adminUpdate = await request(app)
      .put(`/api/events/${eventId}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({
        title: 'Edited by admin',
        description: 'Body',
        startDate: '2026-06-01T10:00:00Z',
        endDate: '2026-06-01T12:00:00Z',
        location: 'Ort',
        layerId: koelnLayerId,
      });
    expect(adminUpdate.status).toBe(200);
    expect(adminUpdate.body.event.title).toBe('Edited by admin');
  });

  it('lets admins manage users from the admin area', async () => {
    await createAuthorForTesting({ username: 'admin', password: 'admin-123', isAdmin: true });
    const adminToken = await loginAuthor('admin', 'admin-123');

    const createUserResponse = await request(app)
      .post('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`)
      .send({ username: 'new-user' });
    expect(createUserResponse.status).toBe(201);
    expect(createUserResponse.body.author.username).toBe('new-user');
    expect(createUserResponse.body.oneTimePassword).toEqual(expect.any(String));

    const listResponse = await request(app)
      .get('/api/admin/users')
      .set('authorization', `Bearer ${adminToken}`);
    expect(listResponse.status).toBe(200);
    expect(listResponse.body.users.map((user: { username: string }) => user.username)).toContain('new-user');

    const newUser = listResponse.body.users.find((user: { username: string }) => user.username === 'new-user');
    const deleteActiveResponse = await request(app)
      .delete(`/api/admin/users/${newUser.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteActiveResponse.status).toBe(409);

    const deactivateResponse = await request(app)
      .patch(`/api/admin/users/${newUser.id}`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ isActive: false });
    expect(deactivateResponse.status).toBe(204);

    const resetResponse = await request(app)
      .post(`/api/admin/users/${newUser.id}/reset-password`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(resetResponse.status).toBe(200);
    expect(resetResponse.body.oneTimePassword).toEqual(expect.any(String));

    const deleteInactiveResponse = await request(app)
      .delete(`/api/admin/users/${newUser.id}`)
      .set('authorization', `Bearer ${adminToken}`);
    expect(deleteInactiveResponse.status).toBe(204);
  });
});

afterAll(async () => {
  await close();
});
