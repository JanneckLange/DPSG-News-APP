const clearEvents = jest.fn();
const clearDrafts = jest.fn();
const clearAuthorData = jest.fn();
const createAuthorForTesting = jest.fn();

jest.mock('../src/db', () => ({
  clearEvents: (...args: unknown[]) => clearEvents(...args),
  clearDrafts: (...args: unknown[]) => clearDrafts(...args),
  clearAuthorData: (...args: unknown[]) => clearAuthorData(...args),
  createAuthorForTesting: (...args: unknown[]) => createAuthorForTesting(...args),
}));

import express from 'express';
import request from 'supertest';
import { testOnlyRouter } from '../src/routes/testOnly';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use(testOnlyRouter);
  app.use((_req, res) => res.status(404).json({ error: 'Not found' }));
  return app;
}

describe('testOnly routes are gated behind explicit env flags', () => {
  const originalEnableTestEndpoints = process.env.ENABLE_TEST_ENDPOINTS;
  const originalTestRun = process.env.TEST_RUN;

  beforeEach(() => {
    jest.clearAllMocks();
    clearEvents.mockResolvedValue(undefined);
    clearDrafts.mockResolvedValue(undefined);
    clearAuthorData.mockResolvedValue(undefined);
    createAuthorForTesting.mockResolvedValue({ id: 1, username: 'seed-author' });
    delete process.env.ENABLE_TEST_ENDPOINTS;
    delete process.env.TEST_RUN;
  });

  afterAll(() => {
    if (originalEnableTestEndpoints === undefined) {
      delete process.env.ENABLE_TEST_ENDPOINTS;
    } else {
      process.env.ENABLE_TEST_ENDPOINTS = originalEnableTestEndpoints;
    }
    if (originalTestRun === undefined) {
      delete process.env.TEST_RUN;
    } else {
      process.env.TEST_RUN = originalTestRun;
    }
  });

  describe('POST /__test/reset', () => {
    it('returns 404 and touches no data when ENABLE_TEST_ENDPOINTS is unset', async () => {
      const response = await request(buildApp()).post('/__test/reset').send({});

      expect(response.status).toBe(404);
      expect(response.body).toEqual({ error: 'Not found' });
      expect(clearEvents).not.toHaveBeenCalled();
      expect(clearAuthorData).not.toHaveBeenCalled();
    });

    it('returns 404 when ENABLE_TEST_ENDPOINTS is set to a non-"true" value', async () => {
      process.env.ENABLE_TEST_ENDPOINTS = 'false';

      const response = await request(buildApp()).post('/__test/reset').send({});

      expect(response.status).toBe(404);
      expect(clearEvents).not.toHaveBeenCalled();
    });

    it('clears events, drafts and author data when explicitly enabled', async () => {
      process.env.ENABLE_TEST_ENDPOINTS = 'true';

      const response = await request(buildApp()).post('/__test/reset').send({});

      expect(response.status).toBe(200);
      expect(response.body).toEqual({ ok: true });
      expect(clearEvents).toHaveBeenCalledTimes(1);
      expect(clearDrafts).toHaveBeenCalledTimes(1);
      expect(clearAuthorData).toHaveBeenCalledTimes(1);
      expect(createAuthorForTesting).not.toHaveBeenCalled();
    });

    it('seeds an author when seedAuthor is provided, defaulting the one-time password to the password', async () => {
      process.env.ENABLE_TEST_ENDPOINTS = 'true';

      const response = await request(buildApp())
        .post('/__test/reset')
        .send({ seedAuthor: { username: 'seed-user', password: 'seed-pass' } });

      expect(response.status).toBe(200);
      expect(createAuthorForTesting).toHaveBeenCalledWith({
        username: 'seed-user',
        password: 'seed-pass',
        oneTimePassword: 'seed-pass',
        isAdmin: false,
      });
    });

    it('honors an explicit oneTimePassword and isAdmin flag on seedAuthor', async () => {
      process.env.ENABLE_TEST_ENDPOINTS = 'true';

      const response = await request(buildApp())
        .post('/__test/reset')
        .send({ seedAuthor: { username: 'seed-admin', password: 'seed-pass', oneTimePassword: 'otp', isAdmin: true } });

      expect(response.status).toBe(200);
      expect(createAuthorForTesting).toHaveBeenCalledWith({
        username: 'seed-admin',
        password: 'seed-pass',
        oneTimePassword: 'otp',
        isAdmin: true,
      });
    });

    it('returns 500 without leaking internals when clearing data fails', async () => {
      process.env.ENABLE_TEST_ENDPOINTS = 'true';
      clearEvents.mockRejectedValueOnce(new Error('db exploded'));

      const response = await request(buildApp()).post('/__test/reset').send({});

      expect(response.status).toBe(500);
      expect(response.body).toEqual({ error: 'Unable to reset test data' });
    });
  });

  describe('GET /__test/health', () => {
    it('returns 404 when TEST_RUN is unset', async () => {
      const response = await request(buildApp()).get('/__test/health');
      expect(response.status).toBe(404);
    });

    it('returns 404 when TEST_RUN is set to a non-"true" value', async () => {
      process.env.TEST_RUN = 'false';
      const response = await request(buildApp()).get('/__test/health');
      expect(response.status).toBe(404);
    });

    it('returns the test-mode health payload when TEST_RUN is "true"', async () => {
      process.env.TEST_RUN = 'true';
      const response = await request(buildApp()).get('/__test/health');
      expect(response.status).toBe(200);
      expect(response.body).toEqual({ ok: true, mode: 'test' });
    });
  });
});
