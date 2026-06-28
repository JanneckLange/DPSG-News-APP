const dotenv = require('dotenv');
dotenv.config();

const request = require('supertest');
const app = require('../src/app');
const { connect, clearEvents, close } = require('../src/db');

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
});
