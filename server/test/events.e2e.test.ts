import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { connect, clearEvents, close } from '../src/db';
import { sendEventNotification } from '../src/fcm';

beforeAll(async () => {
  process.env.TEST_DATABASE_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  await connect();
});

beforeEach(async () => {
  await clearEvents();
});

afterAll(async () => {
  await close();
});

afterEach(async () => {
  await clearEvents();
});

describe('Events API e2e', () => {
  it('returns empty list when no events exist', async () => {
    const response = await request(app).get('/api/events');
    expect(response.status).toBe(200);
    expect(response.body.events).toEqual([]);
  });

  it('creates an event and returns it', async () => {
    const eventBody = {
      title: 'Test Event',
      description: 'Beschreibung',
      startDate: '2026-01-01T10:00:00Z',
      endDate: '2026-01-01T12:00:00Z',
      location: 'Ort',
      dv: 'Köln',
    };

    const response = await request(app).post('/api/events').send(eventBody);
    expect(response.status).toBe(201);
    expect(response.body.event).toMatchObject({
      title: eventBody.title,
      description: eventBody.description,
      location: eventBody.location,
      dv: eventBody.dv,
    });
    expect(new Date(response.body.event.startDate).toISOString()).toBe(new Date(eventBody.startDate).toISOString());
    expect(new Date(response.body.event.endDate).toISOString()).toBe(new Date(eventBody.endDate).toISOString());
  });

  it('returns 400 when event payload is incomplete', async () => {
    const response = await request(app).post('/api/events').send({
      title: 'Incomplete Event',
      description: 'Missing fields',
      startDate: '2026-01-01T10:00:00Z',
    });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({ error: 'Missing required event fields' });
  });

  it('returns 400 for invalid delete id and 404 when event is not found', async () => {
    const invalidResponse = await request(app).delete('/api/events/abc');
    expect(invalidResponse.status).toBe(400);
    expect(invalidResponse.body).toEqual({ error: 'Invalid event id' });

    const notFoundResponse = await request(app).delete('/api/events/123');
    expect(notFoundResponse.status).toBe(404);
    expect(notFoundResponse.body).toEqual({ error: 'Event not found' });
  });

  it('continues when notification sending fails', async () => {
    (sendEventNotification as jest.Mock).mockRejectedValueOnce(new Error('FCM down'));

    const response = await request(app).post('/api/events').send({
      title: 'Notification Test',
      description: 'Should still create event',
      startDate: '2026-05-01T10:00:00Z',
      endDate: '2026-05-01T12:00:00Z',
      location: 'Ort',
      dv: 'Köln',
    });

    expect(response.status).toBe(201);
    expect(response.body.event).toMatchObject({ title: 'Notification Test' });
  });

  it('filters events by dv', async () => {
    const eventA = {
      title: 'Event A',
      description: 'A',
      startDate: '2026-01-01T10:00:00Z',
      endDate: '2026-01-01T12:00:00Z',
      location: 'Ort',
      dv: 'Köln',
    };
    const eventB = {
      title: 'Event B',
      description: 'B',
      startDate: '2026-02-01T10:00:00Z',
      endDate: '2026-02-01T12:00:00Z',
      location: 'Ort',
      dv: 'Hamburg',
    };

    await request(app).post('/api/events').send(eventA);
    await request(app).post('/api/events').send(eventB);

    const response = await request(app).get('/api/events').query({ dv: 'Köln' });
    expect(response.status).toBe(200);
    expect(response.body.events).toHaveLength(1);
    expect(response.body.events[0]).toMatchObject({ title: 'Event A', dv: 'Köln' });
  });

  it('deletes an event by id', async () => {
    const eventResponse = await request(app).post('/api/events').send({
      title: 'Delete Event',
      description: 'Delete this event',
      startDate: '2026-03-01T10:00:00Z',
      endDate: '2026-03-01T12:00:00Z',
      location: 'Ort',
      dv: 'Köln',
    });

    const eventId = eventResponse.body.event.id;
    const deleteResponse = await request(app).delete(`/api/events/${eventId}`);
    expect(deleteResponse.status).toBe(204);

    const listResponse = await request(app).get('/api/events');
    expect(listResponse.body.events).toEqual([]);
  });

  it('deletes all events', async () => {
    await request(app).post('/api/events').send({
      title: 'Event 1',
      description: 'A',
      startDate: '2026-03-01T10:00:00Z',
      endDate: '2026-03-01T12:00:00Z',
      location: 'Ort',
      dv: 'Köln',
    });
    await request(app).post('/api/events').send({
      title: 'Event 2',
      description: 'B',
      startDate: '2026-04-01T10:00:00Z',
      endDate: '2026-04-01T12:00:00Z',
      location: 'Ort',
      dv: 'Hamburg',
    });

    const deleteResponse = await request(app).delete('/api/events');
    expect(deleteResponse.status).toBe(200);
    expect(deleteResponse.body).toEqual({ deletedCount: 2 });

    const listResponse = await request(app).get('/api/events');
    expect(listResponse.body.events).toEqual([]);
  });
});
