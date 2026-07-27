import { createHash, randomUUID } from 'crypto';
import { Client } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

let client: Client | null = null;

export function getDatabaseUrl(): string {
  return process.env.TEST_DATABASE_URL || process.env.DATABASE_URL || '';
}

export function ensureClient(): Client {
  if (!client) {
    throw new Error('Database is not connected');
  }
  return client;
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function positiveIntegerFromEnv(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) {
    return fallback;
  }
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

export function accessSessionTtlMinutes(): number {
  const direct = process.env.AUTH_SESSION_TTL_MINUTES?.trim();
  if (direct) {
    return positiveIntegerFromEnv('AUTH_SESSION_TTL_MINUTES', 20);
  }
  const legacyRaw = process.env.AUTH_SESSION_TTL_HOURS?.trim();
  if (!legacyRaw) {
    return 20;
  }
  return positiveIntegerFromEnv('AUTH_SESSION_TTL_HOURS', 1) * 60;
}

export function refreshSessionTtlHours(): number {
  return positiveIntegerFromEnv('AUTH_REFRESH_SESSION_TTL_HOURS', 720);
}

export function createRefreshTokenValue(): string {
  return `${randomUUID()}${randomUUID()}`;
}

export function buildTokenExpiry(minutes: number): string {
  return new Date(Date.now() + minutes * 60 * 1000).toISOString();
}

export function buildHoursExpiry(hours: number): string {
  return new Date(Date.now() + hours * 60 * 60 * 1000).toISOString();
}

export async function connectClient(): Promise<void> {
  const databaseUrl = getDatabaseUrl();
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is not set');
  }

  client = new Client({ connectionString: databaseUrl });
  await client.connect();
}

export async function close(): Promise<void> {
  if (!client) {
    return;
  }

  await client.end();
  client = null;
}
