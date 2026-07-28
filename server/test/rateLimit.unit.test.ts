import express from 'express';
import request from 'supertest';
import { createRateLimiter, positiveIntegerFromEnv } from '../src/middleware/rateLimit';

describe('positiveIntegerFromEnv', () => {
  const KEY = 'TEST_POSITIVE_INT_ENV';

  afterEach(() => {
    delete process.env[KEY];
  });

  it('returns the fallback when the variable is unset', () => {
    expect(positiveIntegerFromEnv(KEY, 42)).toBe(42);
  });

  it('parses a valid positive integer from the environment', () => {
    process.env[KEY] = '7';
    expect(positiveIntegerFromEnv(KEY, 42)).toBe(7);
  });

  it('rejects a non-integer value instead of silently truncating', () => {
    process.env[KEY] = '3.5';
    expect(() => positiveIntegerFromEnv(KEY, 42)).toThrow(`${KEY} must be a positive integer`);
  });

  it('rejects a zero value', () => {
    process.env[KEY] = '0';
    expect(() => positiveIntegerFromEnv(KEY, 42)).toThrow(`${KEY} must be a positive integer`);
  });

  it('rejects a non-numeric value', () => {
    process.env[KEY] = 'not-a-number';
    expect(() => positiveIntegerFromEnv(KEY, 42)).toThrow(`${KEY} must be a positive integer`);
  });
});

describe('createRateLimiter', () => {
  function buildApp(scope: string, maxRequests: number, keyFactory: (req: express.Request) => string = () => 'fixed-key') {
    const limiter = createRateLimiter({
      scope,
      windowMs: 60_000,
      maxRequests,
      errorMessage: 'Too many test requests',
      keyFactory,
    });
    const app = express();
    app.get('/limited', limiter, (_req, res) => res.status(200).json({ ok: true }));
    return app;
  }

  it('allows requests while the count stays within the limit', async () => {
    const app = buildApp('rl-allow', 2);

    const first = await request(app).get('/limited');
    const second = await request(app).get('/limited');

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
  });

  it('rejects the request that exceeds the limit with 429 and a Retry-After header', async () => {
    const app = buildApp('rl-reject', 1);

    const first = await request(app).get('/limited');
    const second = await request(app).get('/limited');

    expect(first.status).toBe(200);
    expect(second.status).toBe(429);
    expect(second.body).toEqual({ error: 'Too many test requests' });
    expect(second.headers['retry-after']).toBeDefined();
    expect(Number(second.headers['retry-after'])).toBeGreaterThanOrEqual(1);
  });

  it('tracks separate keys independently so one key cannot exhaust another', async () => {
    let call = 0;
    const app = buildApp('rl-per-key', 1, () => `key-${call++ % 2}`);

    const first = await request(app).get('/limited'); // key-0, count 1 -> ok
    const second = await request(app).get('/limited'); // key-1, count 1 -> ok
    const third = await request(app).get('/limited'); // key-0, count 2 -> exceeded

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect(third.status).toBe(429);
  });

  it('propagates store errors via next(error) instead of crashing the request', async () => {
    const limiter = createRateLimiter({
      scope: 'rl-error',
      windowMs: 60_000,
      maxRequests: 1,
      errorMessage: 'Too many test requests',
      keyFactory: () => {
        throw new Error('key factory boom');
      },
    });
    const app = express();
    app.get('/limited', limiter, (_req, res) => res.status(200).json({ ok: true }));
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
      res.status(500).json({ error: 'handled', message: err.message });
    });

    const response = await request(app).get('/limited');

    expect(response.status).toBe(500);
    expect(response.body).toEqual({ error: 'handled', message: 'key factory boom' });
  });
});
