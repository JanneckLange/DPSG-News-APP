import { createClient, RedisClientType } from 'redis';
import { logInfo, logWarn } from './logger';

export type RateLimitStoreResult = {
  count: number;
  resetAtMs: number;
};

export interface RateLimitStore {
  increment(key: string, windowMs: number, nowMs: number): Promise<RateLimitStoreResult>;
}

class InMemoryRateLimitStore implements RateLimitStore {
  private counters = new Map<string, { count: number; resetAtMs: number }>();

  async increment(key: string, windowMs: number, nowMs: number): Promise<RateLimitStoreResult> {
    const current = this.counters.get(key);
    if (!current || current.resetAtMs <= nowMs) {
      const resetAtMs = nowMs + windowMs;
      this.counters.set(key, { count: 1, resetAtMs });
      return { count: 1, resetAtMs };
    }

    current.count += 1;
    if (this.counters.size > 10_000) {
      for (const [entryKey, entry] of this.counters.entries()) {
        if (entry.resetAtMs <= nowMs) {
          this.counters.delete(entryKey);
        }
      }
    }
    return { count: current.count, resetAtMs: current.resetAtMs };
  }
}

const REDIS_INCREMENT_SCRIPT = `
local current = redis.call('INCR', KEYS[1])
if current == 1 then
  redis.call('PEXPIRE', KEYS[1], ARGV[1])
end
local ttl = redis.call('PTTL', KEYS[1])
return { current, ttl }
`;

class RedisRateLimitStore implements RateLimitStore {
  private readonly client: RedisClientType;
  private readonly connectPromise: Promise<void>;

  constructor(redisUrl: string) {
    this.client = createClient({ url: redisUrl });
    this.client.on('error', (error) => {
      logWarn('Redis rate limit client error', { errorMessage: error.message });
    });
    this.connectPromise = this.client.connect().then(() => {
      logInfo('Redis rate limit store connected');
    });
  }

  async increment(key: string, windowMs: number, nowMs: number): Promise<RateLimitStoreResult> {
    await this.connectPromise;
    const [countRaw, ttlRaw] = await this.client.eval(REDIS_INCREMENT_SCRIPT, {
      keys: [key],
      arguments: [String(windowMs)],
    }) as [number, number];
    const count = Number(countRaw);
    const ttl = Number(ttlRaw);
    const ttlMs = ttl > 0 ? ttl : windowMs;
    return {
      count,
      resetAtMs: nowMs + ttlMs,
    };
  }
}

export function createRateLimitStore(): RateLimitStore {
  const backend = (process.env.RATE_LIMIT_STORE || 'memory').trim().toLowerCase();
  if (backend === 'memory') {
    return new InMemoryRateLimitStore();
  }
  if (backend === 'redis') {
    const redisUrl = process.env.RATE_LIMIT_REDIS_URL?.trim();
    if (!redisUrl) {
      throw new Error('RATE_LIMIT_REDIS_URL must be set when RATE_LIMIT_STORE=redis');
    }
    return new RedisRateLimitStore(redisUrl);
  }
  throw new Error('RATE_LIMIT_STORE must be one of: memory, redis');
}
