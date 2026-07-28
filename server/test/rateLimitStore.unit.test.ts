import { createRateLimitStore } from '../src/rateLimitStore';

describe('createRateLimitStore (in-memory backend)', () => {
  const originalBackend = process.env.RATE_LIMIT_STORE;

  afterEach(() => {
    if (originalBackend === undefined) {
      delete process.env.RATE_LIMIT_STORE;
    } else {
      process.env.RATE_LIMIT_STORE = originalBackend;
    }
  });

  it('defaults to the in-memory backend when unset', async () => {
    delete process.env.RATE_LIMIT_STORE;
    const store = createRateLimitStore();
    const result = await store.increment('key-a', 60_000, 1_000);
    expect(result).toEqual({ count: 1, resetAtMs: 61_000 });
  });

  it('accepts an explicit, case-insensitively trimmed "memory" value', async () => {
    process.env.RATE_LIMIT_STORE = ' Memory ';
    const store = createRateLimitStore();
    const result = await store.increment('key-a', 60_000, 1_000);
    expect(result).toEqual({ count: 1, resetAtMs: 61_000 });
  });

  it('rejects an unknown backend value', () => {
    process.env.RATE_LIMIT_STORE = 'sqlite';
    expect(() => createRateLimitStore()).toThrow('RATE_LIMIT_STORE must be one of: memory, redis');
  });

  it('rejects the redis backend when no redis URL is configured', () => {
    process.env.RATE_LIMIT_STORE = 'redis';
    delete process.env.RATE_LIMIT_REDIS_URL;
    expect(() => createRateLimitStore()).toThrow('RATE_LIMIT_REDIS_URL must be set when RATE_LIMIT_STORE=redis');
  });

  describe('increment behavior', () => {
    it('starts a new window with count 1 for a fresh key', async () => {
      const store = createRateLimitStore();
      const result = await store.increment('fresh-key', 10_000, 5_000);
      expect(result).toEqual({ count: 1, resetAtMs: 15_000 });
    });

    it('increments the count within the same window without moving resetAtMs', async () => {
      const store = createRateLimitStore();
      const first = await store.increment('sliding-key', 10_000, 0);
      const second = await store.increment('sliding-key', 10_000, 4_000);
      const third = await store.increment('sliding-key', 10_000, 9_999);

      expect(first).toEqual({ count: 1, resetAtMs: 10_000 });
      expect(second).toEqual({ count: 2, resetAtMs: 10_000 });
      expect(third).toEqual({ count: 3, resetAtMs: 10_000 });
    });

    it('starts a brand new window once the previous one has expired', async () => {
      const store = createRateLimitStore();
      await store.increment('expiring-key', 10_000, 0);
      await store.increment('expiring-key', 10_000, 5_000);
      const afterExpiry = await store.increment('expiring-key', 10_000, 10_000);

      expect(afterExpiry).toEqual({ count: 1, resetAtMs: 20_000 });
    });

    it('tracks independent keys without interference', async () => {
      const store = createRateLimitStore();
      const a1 = await store.increment('key-a', 10_000, 0);
      const b1 = await store.increment('key-b', 10_000, 0);
      const a2 = await store.increment('key-a', 10_000, 100);

      expect(a1).toEqual({ count: 1, resetAtMs: 10_000 });
      expect(b1).toEqual({ count: 1, resetAtMs: 10_000 });
      expect(a2).toEqual({ count: 2, resetAtMs: 10_000 });
    });
  });
});
