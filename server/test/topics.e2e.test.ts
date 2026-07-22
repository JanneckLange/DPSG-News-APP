import dotenv from 'dotenv';
dotenv.config();

jest.mock('../src/fcm', () => ({
  sendEventNotification: jest.fn().mockResolvedValue('mocked'),
}));

import request from 'supertest';
import app from '../src/app';
import { close, connect } from '../src/db';

async function getLayerIdByName(name: string): Promise<number> {
  const response = await request(app).get('/api/layers');
  expect(response.status).toBe(200);
  const layer = (response.body.layers as Array<{ id: number; name: string }>).find((l) => l.name === name);
  if (!layer) {
    throw new Error(`Layer "${name}" not found in seeded layers`);
  }
  return layer.id;
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
