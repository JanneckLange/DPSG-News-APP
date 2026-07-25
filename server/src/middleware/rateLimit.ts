import { NextFunction, Request, Response } from 'express';
import { createRateLimitStore } from '../rateLimitStore';

export function positiveIntegerFromEnv(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) {
    return fallback;
  }
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return parsed;
}

type RateLimiterOptions = {
  scope: string;
  windowMs: number;
  maxRequests: number;
  errorMessage: string;
  keyFactory: (req: Request) => string;
};

const rateLimitStore = createRateLimitStore();

export function createRateLimiter(options: RateLimiterOptions) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const nowMs = Date.now();
      const key = `${options.scope}:${options.keyFactory(req)}`;
      const current = await rateLimitStore.increment(key, options.windowMs, nowMs);
      if (current.count > options.maxRequests) {
        const retryAfterSeconds = Math.max(1, Math.ceil((current.resetAtMs - nowMs) / 1000));
        res.setHeader('Retry-After', String(retryAfterSeconds));
        res.status(429).json({ error: options.errorMessage });
        return;
      }
      next();
    } catch (error) {
      next(error);
    }
  };
}

const globalRateLimitWindowMs = positiveIntegerFromEnv('GLOBAL_RATE_LIMIT_WINDOW_MS', 60_000);
const globalRateLimitMax = positiveIntegerFromEnv('GLOBAL_RATE_LIMIT_MAX_REQUESTS', 300);
const authRateLimitWindowMs = positiveIntegerFromEnv('AUTH_RATE_LIMIT_WINDOW_MS', 60_000);
const authRateLimitMax = positiveIntegerFromEnv('AUTH_RATE_LIMIT_MAX_REQUESTS', 10);

export const globalRateLimiter = createRateLimiter({
  scope: 'global',
  windowMs: globalRateLimitWindowMs,
  maxRequests: globalRateLimitMax,
  errorMessage: 'Too many requests',
  keyFactory: (req) => req.ip || 'unknown',
});

export const authRateLimiter = createRateLimiter({
  scope: 'auth',
  windowMs: authRateLimitWindowMs,
  maxRequests: authRateLimitMax,
  errorMessage: 'Too many login attempts',
  keyFactory: (req) => {
    const username = typeof req.body?.username === 'string' ? req.body.username.trim().toLowerCase() : '';
    return `${req.ip || 'unknown'}:${username}`;
  },
});
