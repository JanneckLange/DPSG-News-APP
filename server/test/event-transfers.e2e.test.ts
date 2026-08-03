import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
  sendEventTransferRequestNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { clearAuthorData, clearEvents, close, connect, createAuthorForTesting, removeAuthorLayerGrant } from '../src/db';
import { sendEventTransferRequestNotification } from '../src/fcm';

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
  jest.clearAllMocks();
});

afterAll(async () => {
  await close();
});

async function createOwnEvent(token: string, title: string): Promise<number> {
  const response = await request(app)
    .post('/api/author/events')
    .set('authorization', `Bearer ${token}`)
    .send({
      title,
      description: 'Beschreibung',
      startDate: '2026-05-01T10:00:00Z',
      endDate: '2026-05-01T12:00:00Z',
      layerId: koelnLayerId,
    });
  expect(response.status).toBe(201);
  return response.body.event.id as number;
}

describe('Event transfer requests API e2e', () => {
  it('lets an author offer an own event to an eligible target author and sends a push notification', async () => {
    await createAuthorForTesting({ username: 'from-author', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'to-author', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const fromToken = await loginAuthor('from-author', 'secret-123');
    const toAuthor = await request(app).post('/api/auth/login').send({ username: 'to-author', password: 'secret-123' });
    const toAuthorId = toAuthor.body.author.id as number;

    const eventId = await createOwnEvent(fromToken, 'Uebertragbares Event');

    const response = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${fromToken}`)
      .send({ toAuthorId });

    expect(response.status).toBe(201);
    expect(response.body.request).toMatchObject({ eventId, toAuthorId, status: 'pending' });
    expect(sendEventTransferRequestNotification).toHaveBeenCalledWith(
      expect.objectContaining({ toAuthorId, eventTitle: 'Uebertragbares Event' })
    );
  });

  it('rejects offering an event to oneself', async () => {
    const fromAuthor = await createAuthorForTesting({ username: 'self-author', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('self-author', 'secret-123');
    const eventId = await createOwnEvent(token, 'Self transfer');

    const response = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${token}`)
      .send({ toAuthorId: fromAuthor.id });

    expect(response.status).toBe(400);
  });

  it('rejects a target author without the required layer grant', async () => {
    await createAuthorForTesting({ username: 'from-author-2', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const ungrantedTarget = await createAuthorForTesting({ username: 'ungranted-target', password: 'secret-123', layerGrantIds: [] });
    const token = await loginAuthor('from-author-2', 'secret-123');
    const eventId = await createOwnEvent(token, 'Kein Grant fuer Ziel');

    const response = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${token}`)
      .send({ toAuthorId: ungrantedTarget.id });

    expect(response.status).toBe(400);
  });

  it('forbids offering an event that is not the caller\'s own', async () => {
    await createAuthorForTesting({ username: 'owner-author', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'other-author', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const target = await createAuthorForTesting({ username: 'target-author', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const ownerToken = await loginAuthor('owner-author', 'secret-123');
    const otherToken = await loginAuthor('other-author', 'secret-123');
    const eventId = await createOwnEvent(ownerToken, 'Fremdes Event');

    const response = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${otherToken}`)
      .send({ toAuthorId: target.id });

    expect(response.status).toBe(403);
  });

  it('cancels a previous pending request for the same event when a new one is created', async () => {
    await createAuthorForTesting({ username: 'from-author-3', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const firstTarget = await createAuthorForTesting({ username: 'first-target', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const secondTarget = await createAuthorForTesting({ username: 'second-target', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const token = await loginAuthor('from-author-3', 'secret-123');
    const eventId = await createOwnEvent(token, 'Nur eine aktive Anfrage');

    const first = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${token}`)
      .send({ toAuthorId: firstTarget.id });
    expect(first.status).toBe(201);

    const second = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${token}`)
      .send({ toAuthorId: secondTarget.id });
    expect(second.status).toBe(201);

    const statusResponse = await request(app)
      .get(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${token}`);
    expect(statusResponse.status).toBe(200);
    const requests = statusResponse.body.requests as Array<{ id: number; status: string; toAuthorId: number }>;
    expect(requests).toHaveLength(2);
    expect(requests.find((r) => r.id === first.body.request.id)?.status).toBe('cancelled');
    expect(requests.find((r) => r.id === second.body.request.id)?.status).toBe('pending');
  });

  it('transfers the event and records history when the target accepts', async () => {
    const fromAuthor = await createAuthorForTesting({ username: 'accept-from', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const toAuthor = await createAuthorForTesting({ username: 'accept-to', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const fromToken = await loginAuthor('accept-from', 'secret-123');
    const toToken = await loginAuthor('accept-to', 'secret-123');
    const eventId = await createOwnEvent(fromToken, 'Wird angenommen');

    const created = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${fromToken}`)
      .send({ toAuthorId: toAuthor.id });
    const requestId = created.body.request.id as number;

    const acceptResponse = await request(app)
      .post(`/api/events/transfer-requests/${requestId}/accept`)
      .set('authorization', `Bearer ${toToken}`)
      .send();

    expect(acceptResponse.status).toBe(200);
    expect(acceptResponse.body.event.authorId).toBe(toAuthor.id);
    expect(acceptResponse.body.request.status).toBe('accepted');

    const historyResponse = await request(app)
      .get(`/api/events/${eventId}/history`)
      .set('authorization', `Bearer ${toToken}`);
    expect(historyResponse.status).toBe(200);
    const change = historyResponse.body.history[0].changes.find((c: { field: string }) => c.field === 'authorId');
    expect(change).toMatchObject({ oldValue: fromAuthor.id, newValue: toAuthor.id });
  });

  it('forbids someone other than the target from accepting or rejecting', async () => {
    await createAuthorForTesting({ username: 'accept-from-2', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'accept-to-2', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'bystander', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const fromToken = await loginAuthor('accept-from-2', 'secret-123');
    const toAuthorId = (await request(app).post('/api/auth/login').send({ username: 'accept-to-2', password: 'secret-123' })).body.author.id;
    const bystanderToken = await loginAuthor('bystander', 'secret-123');
    const eventId = await createOwnEvent(fromToken, 'Nur Zielperson darf');

    const created = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${fromToken}`)
      .send({ toAuthorId });
    const requestId = created.body.request.id as number;

    const acceptResponse = await request(app)
      .post(`/api/events/transfer-requests/${requestId}/accept`)
      .set('authorization', `Bearer ${bystanderToken}`)
      .send();
    expect(acceptResponse.status).toBe(403);

    const rejectResponse = await request(app)
      .post(`/api/events/transfer-requests/${requestId}/reject`)
      .set('authorization', `Bearer ${bystanderToken}`)
      .send();
    expect(rejectResponse.status).toBe(403);
  });

  it('lets the target reject a request, leaving the event unchanged', async () => {
    const fromAuthor = await createAuthorForTesting({ username: 'reject-from', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const toAuthor = await createAuthorForTesting({ username: 'reject-to', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const fromToken = await loginAuthor('reject-from', 'secret-123');
    const toToken = await loginAuthor('reject-to', 'secret-123');
    const eventId = await createOwnEvent(fromToken, 'Wird abgelehnt');

    const created = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${fromToken}`)
      .send({ toAuthorId: toAuthor.id });
    const requestId = created.body.request.id as number;

    const rejectResponse = await request(app)
      .post(`/api/events/transfer-requests/${requestId}/reject`)
      .set('authorization', `Bearer ${toToken}`)
      .send();
    expect(rejectResponse.status).toBe(200);
    expect(rejectResponse.body.request.status).toBe('rejected');

    const ownEventsResponse = await request(app)
      .get('/api/author/events')
      .set('authorization', `Bearer ${fromToken}`);
    expect(ownEventsResponse.body.events.find((e: { id: number }) => e.id === eventId).authorId).toBe(fromAuthor.id);
  });

  it('invalidates the request and rejects acceptance when the target lost the required grant in the meantime', async () => {
    await createAuthorForTesting({ username: 'invalid-from', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    // Zweiter Layer-Grant, damit removeAuthorLayerGrant unten den Autor nicht
    // ueber maybeAutoDisableAuthor deaktiviert (und damit dessen Session revoked) -
    // getestet werden soll die Rechte-Revalidierung, nicht ein 401 wegen Logout.
    const toAuthor = await createAuthorForTesting({ username: 'invalid-to', password: 'secret-123', layerGrantIds: [koelnLayerId, hamburgLayerId] });
    const fromToken = await loginAuthor('invalid-from', 'secret-123');
    const toToken = await loginAuthor('invalid-to', 'secret-123');
    const eventId = await createOwnEvent(fromToken, 'Rechte werden entzogen');

    const created = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${fromToken}`)
      .send({ toAuthorId: toAuthor.id });
    const requestId = created.body.request.id as number;

    await removeAuthorLayerGrant(toAuthor.id, koelnLayerId);

    const acceptResponse = await request(app)
      .post(`/api/events/transfer-requests/${requestId}/accept`)
      .set('authorization', `Bearer ${toToken}`)
      .send();
    expect(acceptResponse.status).toBe(409);

    const statusResponse = await request(app)
      .get(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${fromToken}`);
    expect(statusResponse.body.requests.find((r: { id: number }) => r.id === requestId).status).toBe('invalid');
  });

  it('lists incoming pending requests with event and sender details', async () => {
    await createAuthorForTesting({ username: 'incoming-from', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const toAuthor = await createAuthorForTesting({ username: 'incoming-to', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const fromToken = await loginAuthor('incoming-from', 'secret-123');
    const toToken = await loginAuthor('incoming-to', 'secret-123');
    const eventId = await createOwnEvent(fromToken, 'Eingehende Anfrage');

    await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${fromToken}`)
      .send({ toAuthorId: toAuthor.id });

    const incomingResponse = await request(app)
      .get('/api/events/transfer-requests/incoming')
      .set('authorization', `Bearer ${toToken}`);

    expect(incomingResponse.status).toBe(200);
    expect(incomingResponse.body.requests).toHaveLength(1);
    expect(incomingResponse.body.requests[0]).toMatchObject({
      eventId,
      eventTitle: 'Eingehende Anfrage',
      fromAuthorUsername: 'incoming-from',
      status: 'pending',
    });
  });
});

describe('Admin direct event transfer API e2e (#23)', () => {
  it('lets an admin with matching layer scope transfer an event immediately, without consent', async () => {
    await createAuthorForTesting({ username: 'direct-owner', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const targetAuthor = await createAuthorForTesting({ username: 'direct-target', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'direct-admin', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const ownerToken = await loginAuthor('direct-owner', 'secret-123');
    const adminToken = await loginAuthor('direct-admin', 'admin-123');
    const eventId = await createOwnEvent(ownerToken, 'Direkt uebertragen');

    const response = await request(app)
      .post(`/api/events/${eventId}/transfer`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ toAuthorId: targetAuthor.id });

    expect(response.status).toBe(200);
    expect(response.body.event.authorId).toBe(targetAuthor.id);

    const historyResponse = await request(app)
      .get(`/api/events/${eventId}/history`)
      .set('authorization', `Bearer ${adminToken}`);
    const change = historyResponse.body.history[0].changes.find((c: { field: string }) => c.field === 'authorId');
    expect(change).toMatchObject({ newValue: targetAuthor.id });
  });

  it('forbids an admin without matching layer scope from transferring the event', async () => {
    await createAuthorForTesting({ username: 'scope-owner', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const targetAuthor = await createAuthorForTesting({ username: 'scope-target', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'scope-admin', password: 'admin-123', isAdmin: true, adminLayerIds: [hamburgLayerId] });
    const ownerToken = await loginAuthor('scope-owner', 'secret-123');
    const adminToken = await loginAuthor('scope-admin', 'admin-123');
    const eventId = await createOwnEvent(ownerToken, 'Ausserhalb des Scopes');

    const response = await request(app)
      .post(`/api/events/${eventId}/transfer`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ toAuthorId: targetAuthor.id });

    expect(response.status).toBe(403);
  });

  it("forbids the event owner from using the direct-transfer endpoint on their own event", async () => {
    const owner = await createAuthorForTesting({ username: 'owner-direct-attempt', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const targetAuthor = await createAuthorForTesting({ username: 'owner-direct-target', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const ownerToken = await loginAuthor('owner-direct-attempt', 'secret-123');
    const eventId = await createOwnEvent(ownerToken, 'Eigentuemer versucht Direktuebertragung');

    const response = await request(app)
      .post(`/api/events/${eventId}/transfer`)
      .set('authorization', `Bearer ${ownerToken}`)
      .send({ toAuthorId: targetAuthor.id });

    expect(response.status).toBe(403);

    const ownEventsResponse = await request(app)
      .get('/api/author/events')
      .set('authorization', `Bearer ${ownerToken}`);
    expect(ownEventsResponse.body.events.find((e: { id: number }) => e.id === eventId).authorId).toBe(owner.id);
  });

  it('rejects a target author without the required layer grant', async () => {
    await createAuthorForTesting({ username: 'direct-owner-2', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const ungrantedTarget = await createAuthorForTesting({ username: 'direct-ungranted-target', password: 'secret-123', layerGrantIds: [] });
    await createAuthorForTesting({ username: 'direct-admin-2', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const ownerToken = await loginAuthor('direct-owner-2', 'secret-123');
    const adminToken = await loginAuthor('direct-admin-2', 'admin-123');
    const eventId = await createOwnEvent(ownerToken, 'Kein Grant fuer Direktziel');

    const response = await request(app)
      .post(`/api/events/${eventId}/transfer`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ toAuthorId: ungrantedTarget.id });

    expect(response.status).toBe(400);
  });

  it('cancels an open author-initiated request for the same event on direct transfer', async () => {
    await createAuthorForTesting({ username: 'race-owner', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const offeredTarget = await createAuthorForTesting({ username: 'race-offered-target', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    const directTarget = await createAuthorForTesting({ username: 'race-direct-target', password: 'secret-123', layerGrantIds: [koelnLayerId] });
    await createAuthorForTesting({ username: 'race-admin', password: 'admin-123', isAdmin: true, adminLayerIds: [koelnLayerId] });
    const ownerToken = await loginAuthor('race-owner', 'secret-123');
    const adminToken = await loginAuthor('race-admin', 'admin-123');
    const eventId = await createOwnEvent(ownerToken, 'Wettlauf Anfrage vs Direktuebertragung');

    const created = await request(app)
      .post(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${ownerToken}`)
      .send({ toAuthorId: offeredTarget.id });
    const requestId = created.body.request.id as number;

    const directResponse = await request(app)
      .post(`/api/events/${eventId}/transfer`)
      .set('authorization', `Bearer ${adminToken}`)
      .send({ toAuthorId: directTarget.id });
    expect(directResponse.status).toBe(200);
    expect(directResponse.body.event.authorId).toBe(directTarget.id);

    // Der Event-Eigentuemer hat sich durch die Direktuebertragung geaendert -
    // die Anfrage-Historie ist jetzt nur noch fuer den neuen Eigentuemer sichtbar.
    const directTargetToken = await loginAuthor('race-direct-target', 'secret-123');
    const statusResponse = await request(app)
      .get(`/api/events/${eventId}/transfer-requests`)
      .set('authorization', `Bearer ${directTargetToken}`);
    expect(statusResponse.status).toBe(200);
    expect(statusResponse.body.requests.find((r: { id: number }) => r.id === requestId).status).toBe('cancelled');

    const offeredTargetToken = await loginAuthor('race-offered-target', 'secret-123');
    const acceptResponse = await request(app)
      .post(`/api/events/transfer-requests/${requestId}/accept`)
      .set('authorization', `Bearer ${offeredTargetToken}`)
      .send();
    expect(acceptResponse.status).toBe(409);
  });
});
