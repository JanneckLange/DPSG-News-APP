import { createHash, randomUUID } from 'crypto';
import { Client, QueryConfig } from 'pg';
import dotenv from 'dotenv';
import { hashPassword, verifyPassword } from './password';
import { BUNDESVERBAND_NAME, SEED_DVS } from './seedLayers';

dotenv.config();

type EventRow = {
  id: number;
  title: string;
  description: string | null;
  start_date: string | null;
  end_date: string | null;
  location: string | null;
  layer_id: number | null;
  topic_id?: number | null;
  cta1_label: string | null;
  cta1_url: string | null;
  cta2_label: string | null;
  cta2_url: string | null;
  author_id: number | null;
  created_at: string;
  modified_at: string;
  last_update_at: string | null;
};

export type Event = {
  id: number;
  title: string;
  description: string;
  startDate: string;
  endDate: string;
  location: string;
  layerId: number | null;
  topicId?: number;
  cta1Label?: string;
  cta1Url?: string;
  cta2Label?: string;
  cta2Url?: string;
  authorId: number | null;
  createdAt: string;
  modifiedAt: string;
  lastUpdateAt?: string;
};

export type EventInput = {
  title: string;
  description?: string;
  startDate?: string;
  endDate?: string;
  location?: string;
  layerId?: number;
  topicId?: number;
  cta1Label?: string;
  cta1Url?: string;
  cta2Label?: string;
  cta2Url?: string;
};

type DraftRow = {
  id: number;
  title: string;
  description: string | null;
  start_date: string | null;
  end_date: string | null;
  location: string | null;
  layer_id: number | null;
  topic_id?: number | null;
  cta1_label: string | null;
  cta1_url: string | null;
  cta2_label: string | null;
  cta2_url: string | null;
  author_id: number;
  created_at: string;
  modified_at: string;
};

export type Draft = {
  id: number;
  title: string;
  description: string;
  startDate: string;
  endDate: string;
  location: string;
  layerId: number | null;
  topicId?: number;
  cta1Label?: string;
  cta1Url?: string;
  cta2Label?: string;
  cta2Url?: string;
  authorId: number;
  createdAt: string;
  modifiedAt: string;
  timeUntilDeletion: number;
};

export type DraftInput = {
  title: string;
  description?: string;
  startDate?: string;
  endDate?: string;
  location?: string;
  layerId?: number;
  topicId?: number;
  cta1Label?: string;
  cta1Url?: string;
  cta2Label?: string;
  cta2Url?: string;
};

type LayerRow = {
  id: number;
  name: string;
  type: string;
  parent_id: number | null;
  url: string | null;
  created_at: string;
  updated_at: string;
};

export type Layer = {
  id: number;
  name: string;
  type: string;
  parentId: number | null;
  url: string | null;
  createdAt: string;
  updatedAt: string;
};

export type LayerInput = {
  name: string;
  type: string;
  parentId?: number | null;
  url?: string | null;
};

type TopicRow = {
  id: number;
  name: string;
  layer_id: number;
  created_at: string;
  updated_at: string;
};

export type Topic = {
  id: number;
  name: string;
  layerId: number;
  createdAt: string;
  updatedAt: string;
};

export type TopicInput = {
  name: string;
  layerId: number;
};

type EventUpdateRow = {
  id: number;
  event_id: number;
  author_id: number | null;
  message: string;
  created_at: string;
  author_username: string | null;
};

export type EventUpdate = {
  id: number;
  eventId: number;
  authorId: number | null;
  authorUsername: string | null;
  message: string;
  createdAt: string;
};

type AuthorRow = {
  id: number;
  username: string;
  password_hash: string;
  one_time_password_hash: string | null;
  must_change_password: boolean;
  is_active: boolean;
  is_admin: boolean;
  admin_layer_id: number | null;
};

export type AuthorIdentity = {
  id: number;
  username: string;
  isAdmin: boolean;
  adminLayerId: number | null;
};

export type AuthSession = {
  token: string;
  author: AuthorIdentity;
  requiresPasswordChange: boolean;
  expiresAt: string;
};

export type AuthLoginSession = AuthSession & {
  refreshToken: string;
  refreshExpiresAt: string;
};

let client: Client | null = null;
let lastSessionCleanupAtMs = 0;
let lastDraftCleanupAtMs = 0;

function getDatabaseUrl(): string {
  return process.env.TEST_DATABASE_URL || process.env.DATABASE_URL || '';
}

function draftRetentionDays(): number {
  return positiveIntegerFromEnv('DRAFT_RETENTION_DAYS', 90);
}

function ensureClient(): Client {
  if (!client) {
    throw new Error('Database is not connected');
  }
  return client;
}

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function positiveIntegerFromEnv(name: string, fallback: number): number {
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

function accessSessionTtlMinutes(): number {
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

function refreshSessionTtlHours(): number {
  return positiveIntegerFromEnv('AUTH_REFRESH_SESSION_TTL_HOURS', 720);
}

async function cleanupExpiredSessions(force = false): Promise<void> {
  const nowMs = Date.now();
  if (!force && nowMs - lastSessionCleanupAtMs < 5 * 60 * 1000) {
    return;
  }
  lastSessionCleanupAtMs = nowMs;
  const db = ensureClient();
  await db.query('DELETE FROM author_sessions WHERE expires_at <= NOW()');
  await db.query(
    `DELETE FROM author_refresh_sessions
     WHERE expires_at <= NOW()
        OR (revoked_at IS NOT NULL AND revoked_at <= NOW() - INTERVAL '7 days')`
  );
}

function computeDraftTimeUntilDeletion(modifiedAt: string): number {
  const retentionMs = draftRetentionDays() * 24 * 60 * 60 * 1000;
  const modifiedMs = Date.parse(modifiedAt);
  const remainingMs = Math.max(0, retentionMs - (Date.now() - modifiedMs));
  return Math.floor(remainingMs / 1000);
}

async function cleanupExpiredDraftsInternal(force = false): Promise<void> {
  const nowMs = Date.now();
  if (!force && nowMs - lastDraftCleanupAtMs < 5 * 60 * 1000) {
    return;
  }
  lastDraftCleanupAtMs = nowMs;
  const db = ensureClient();
  const retention = draftRetentionDays();
  await db.query(
    `DELETE FROM drafts
     WHERE modified_at <= NOW() - $1::interval`,
    [`${retention} days`]
  );
}

export async function cleanupExpiredDrafts(force = false): Promise<void> {
  return cleanupExpiredDraftsInternal(force);
}

async function revokeAuthorSessions(authorId: number): Promise<void> {
  const db = ensureClient();
  await db.query('DELETE FROM author_sessions WHERE author_id = $1', [authorId]);
  await db.query(
    `UPDATE author_refresh_sessions
     SET revoked_at = NOW()
     WHERE author_id = $1
       AND revoked_at IS NULL`,
    [authorId]
  );
}

async function revokeRefreshFamily(familyId: string): Promise<void> {
  const db = ensureClient();
  await db.query(
    `UPDATE author_refresh_sessions
     SET revoked_at = NOW()
     WHERE family_id = $1
       AND revoked_at IS NULL`,
    [familyId]
  );
  await db.query(
    `DELETE FROM author_sessions
     WHERE refresh_token_hash IN (
       SELECT token_hash FROM author_refresh_sessions WHERE family_id = $1
     )`,
    [familyId]
  );
}

function buildTokenExpiry(minutes: number): string {
  return new Date(Date.now() + minutes * 60 * 1000).toISOString();
}

function buildHoursExpiry(hours: number): string {
  return new Date(Date.now() + hours * 60 * 60 * 1000).toISOString();
}

function createRefreshTokenValue(): string {
  return `${randomUUID()}${randomUUID()}`;
}

async function createAuthorLoginSession(author: AuthorRow, requiresPasswordChange: boolean): Promise<AuthLoginSession> {
  const db = ensureClient();
  const token = randomUUID();
  const accessExpiresAt = buildTokenExpiry(accessSessionTtlMinutes());
  const refreshToken = createRefreshTokenValue();
  const refreshTokenHash = hashToken(refreshToken);
  const refreshExpiresAt = buildHoursExpiry(refreshSessionTtlHours());
  const familyId = randomUUID();
  await db.query('BEGIN');
  try {
    await db.query(
      `INSERT INTO author_refresh_sessions (token_hash, author_id, family_id, expires_at)
       VALUES ($1, $2, $3, $4)`,
      [refreshTokenHash, author.id, familyId, refreshExpiresAt]
    );
    await db.query(
      `INSERT INTO author_sessions (token, author_id, expires_at, refresh_token_hash)
       VALUES ($1, $2, $3, $4)`,
      [token, author.id, accessExpiresAt, refreshTokenHash]
    );
    await db.query('COMMIT');
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  }
  return {
    token,
    author: normalizeAuthor(author),
    requiresPasswordChange,
    expiresAt: accessExpiresAt,
    refreshToken,
    refreshExpiresAt,
  };
}

export async function connect(): Promise<void> {
  const databaseUrl = getDatabaseUrl();
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is not set');
  }

  client = new Client({ connectionString: databaseUrl });
  await client.connect();
  await client.query(`
    CREATE TABLE IF NOT EXISTS authors (
      id SERIAL PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      one_time_password_hash TEXT,
      must_change_password BOOLEAN NOT NULL DEFAULT TRUE,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      is_admin BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`ALTER TABLE authors ADD COLUMN IF NOT EXISTS one_time_password_hash TEXT;`);
  await client.query(`ALTER TABLE authors ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT TRUE;`);
  await client.query(`ALTER TABLE authors ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;`);
  await client.query(`ALTER TABLE authors ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS author_sessions (
      token TEXT PRIMARY KEY,
      author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
      expires_at TIMESTAMPTZ NOT NULL,
      refresh_token_hash TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`ALTER TABLE author_sessions ADD COLUMN IF NOT EXISTS refresh_token_hash TEXT;`);
  await client.query(`CREATE INDEX IF NOT EXISTS author_sessions_author_id_idx ON author_sessions(author_id);`);
  await client.query(`CREATE INDEX IF NOT EXISTS author_sessions_refresh_token_hash_idx ON author_sessions(refresh_token_hash);`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS author_refresh_sessions (
      token_hash TEXT PRIMARY KEY,
      author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
      family_id TEXT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      revoked_at TIMESTAMPTZ,
      replaced_by_token_hash TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`CREATE INDEX IF NOT EXISTS author_refresh_sessions_author_id_idx ON author_refresh_sessions(author_id);`);
  await client.query(`CREATE INDEX IF NOT EXISTS author_refresh_sessions_family_id_idx ON author_refresh_sessions(family_id);`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS layers (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      parent_id INTEGER REFERENCES layers(id) ON DELETE CASCADE,
      url TEXT,
      groups TEXT[],
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE NULLS NOT DISTINCT (type, name, parent_id)
    );
  `);
  await client.query(`CREATE INDEX IF NOT EXISTS layers_parent_id_idx ON layers(parent_id);`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS topics (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      layer_id INTEGER NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE NULLS NOT DISTINCT (layer_id, name)
    );
  `);
  await client.query(`CREATE INDEX IF NOT EXISTS topics_layer_id_idx ON topics(layer_id);`);
  await ensureSeedLayers();
  await client.query(`ALTER TABLE layers DROP COLUMN IF EXISTS groups;`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS events (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      start_date TIMESTAMPTZ,
      end_date TIMESTAMPTZ,
      location TEXT,
      dv TEXT,
      topic TEXT,
      cta1_label TEXT,
      cta1_url TEXT,
      cta2_label TEXT,
      cta2_url TEXT,
      author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS topic TEXT;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS cta1_label TEXT;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS cta1_url TEXT;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS cta2_label TEXT;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS cta2_url TEXT;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW();`);
  await client.query(`UPDATE events SET modified_at = created_at WHERE modified_at IS NULL;`);
  await client.query(`
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'events' AND column_name = 'is_draft'
      ) THEN
        DELETE FROM events WHERE is_draft = TRUE;
      END IF;
    END $$;
  `);
  await client.query(`ALTER TABLE events DROP COLUMN IF EXISTS is_draft;`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS drafts (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      start_date TIMESTAMPTZ,
      end_date TIMESTAMPTZ,
      location TEXT,
      dv TEXT,
      topic TEXT,
      cta1_label TEXT,
      cta1_url TEXT,
      cta2_label TEXT,
      cta2_url TEXT,
      author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS cta1_label TEXT;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS cta1_url TEXT;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS cta2_label TEXT;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS cta2_url TEXT;`);
  await client.query(`CREATE INDEX IF NOT EXISTS drafts_author_id_idx ON drafts(author_id);`);
  await migrateDvToLayerId('events');
  await migrateDvToLayerId('drafts');
  await migrateTopicToTopicId('events');
  await migrateTopicToTopicId('drafts');
  await client.query(`
    CREATE TABLE IF NOT EXISTS event_updates (
      id SERIAL PRIMARY KEY,
      event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
      author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL,
      message TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`CREATE INDEX IF NOT EXISTS event_updates_event_id_idx ON event_updates(event_id);`);
  await cleanupExpiredSessions(true);
  await cleanupExpiredDrafts(true);
  await ensureBootstrapAuthor();
  await migrateAdminLayerId();
}

async function ensureSeedLayers(): Promise<void> {
  const db = ensureClient();
  const bundesverbandResult = await db.query<{ id: number }>(
    `INSERT INTO layers (name, type, parent_id)
     VALUES ($1, 'bundesverband', NULL)
     ON CONFLICT (type, name, parent_id) DO UPDATE SET name = EXCLUDED.name
     RETURNING id`,
    [BUNDESVERBAND_NAME]
  );
  const bundesverbandId = bundesverbandResult.rows[0].id;

  for (const dv of SEED_DVS) {
    const dvResult = await db.query<{ id: number }>(
      `INSERT INTO layers (name, type, parent_id, url)
       VALUES ($1, 'dv', $2, $3)
       ON CONFLICT (type, name, parent_id) DO UPDATE SET url = EXCLUDED.url
       RETURNING id`,
      [dv.name, bundesverbandId, dv.url ?? null]
    );
    const dvId = dvResult.rows[0].id;
    for (const group of dv.groups ?? []) {
      await db.query(
        `INSERT INTO topics (name, layer_id)
         VALUES ($1, $2)
         ON CONFLICT (layer_id, name) DO NOTHING`,
        [group, dvId]
      );
    }
  }
}

async function migrateAdminLayerId(): Promise<void> {
  const db = ensureClient();
  await db.query(`ALTER TABLE authors ADD COLUMN IF NOT EXISTS admin_layer_id INTEGER REFERENCES layers(id);`);
  await db.query(
    `UPDATE authors
     SET admin_layer_id = (SELECT id FROM layers WHERE type = 'bundesverband' AND parent_id IS NULL)
     WHERE is_admin = TRUE AND admin_layer_id IS NULL`
  );
}

async function migrateTopicToTopicId(table: 'events' | 'drafts'): Promise<void> {
  const db = ensureClient();
  await db.query(`ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS topic_id INTEGER REFERENCES topics(id);`);

  const topicColumnExists = await db.query<{ exists: boolean }>(
    `SELECT EXISTS (
       SELECT 1 FROM information_schema.columns
       WHERE table_name = $1 AND column_name = 'topic'
     ) AS exists`,
    [table]
  );
  if (!topicColumnExists.rows[0]?.exists) {
    return;
  }

  await db.query(
    `UPDATE ${table} t
     SET topic_id = tp.id
     FROM topics tp
     WHERE t.topic_id IS NULL
       AND t.layer_id = tp.layer_id
       AND tp.name = t.topic`
  );
  const unmatched = await db.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM ${table} WHERE topic_id IS NULL AND topic IS NOT NULL`
  );
  const unmatchedCount = Number(unmatched.rows[0]?.count ?? '0');
  if (unmatchedCount > 0) {
    console.warn(`[migrateTopicToTopicId] ${unmatchedCount} row(s) in "${table}" could not be matched from topic (free text) to a topic_id and need manual fixup.`);
  }
  await db.query(`ALTER TABLE ${table} DROP COLUMN IF EXISTS topic;`);
}

async function migrateDvToLayerId(table: 'events' | 'drafts'): Promise<void> {
  const db = ensureClient();
  await db.query(`ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS layer_id INTEGER REFERENCES layers(id);`);

  const dvColumnExists = await db.query<{ exists: boolean }>(
    `SELECT EXISTS (
       SELECT 1 FROM information_schema.columns
       WHERE table_name = $1 AND column_name = 'dv'
     ) AS exists`,
    [table]
  );
  if (!dvColumnExists.rows[0]?.exists) {
    return;
  }

  await db.query(
    `UPDATE ${table} t
     SET layer_id = l.id
     FROM layers l
     WHERE t.layer_id IS NULL
       AND l.type = 'dv'
       AND l.name = t.dv`
  );
  const unmatched = await db.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM ${table} WHERE layer_id IS NULL AND dv IS NOT NULL`
  );
  const unmatchedCount = Number(unmatched.rows[0]?.count ?? '0');
  if (unmatchedCount > 0) {
    console.warn(`[migrateDvToLayerId] ${unmatchedCount} row(s) in "${table}" could not be matched from dv (free text) to a layer_id and need manual fixup.`);
  }
  await db.query(`ALTER TABLE ${table} DROP COLUMN IF EXISTS dv;`);
}

async function ensureBootstrapAuthor(): Promise<void> {
  const bootstrapUsername = process.env.AUTHOR_BOOTSTRAP_USERNAME?.trim();
  const bootstrapOneTimePassword = process.env.AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD?.trim();
  if (!bootstrapUsername || !bootstrapOneTimePassword) {
    throw new Error('AUTHOR_BOOTSTRAP_USERNAME and AUTHOR_BOOTSTRAP_ONE_TIME_PASSWORD must be set');
  }

  await ensureClient().query(
    `INSERT INTO authors (username, password_hash, one_time_password_hash, must_change_password, is_active, is_admin)
     VALUES ($1, $2, $3, TRUE, TRUE, TRUE)
     ON CONFLICT (username)
     DO NOTHING`,
    [bootstrapUsername, hashPassword(randomUUID()), hashPassword(bootstrapOneTimePassword)]
  );
}

export function mapEventRow(row: EventRow): Event {
  const out: Event = {
    id: row.id,
    title: row.title,
    description: row.description ?? '',
    startDate: row.start_date ?? '',
    endDate: row.end_date ?? '',
    location: row.location ?? '',
    layerId: row.layer_id,
    authorId: row.author_id,
    createdAt: row.created_at,
    modifiedAt: row.modified_at,
  };
  if (row.topic_id != null) {
    out.topicId = row.topic_id;
  }
  if (row.cta1_label != null) out.cta1Label = row.cta1_label;
  if (row.cta1_url != null) out.cta1Url = row.cta1_url;
  if (row.cta2_label != null) out.cta2Label = row.cta2_label;
  if (row.cta2_url != null) out.cta2Url = row.cta2_url;
  if (row.last_update_at != null) out.lastUpdateAt = row.last_update_at;
  return out;
}

export function mapDraftRow(row: DraftRow): Draft {
  const out: Draft = {
    id: row.id,
    title: row.title,
    description: row.description ?? '',
    startDate: row.start_date ?? '',
    endDate: row.end_date ?? '',
    location: row.location ?? '',
    layerId: row.layer_id,
    authorId: row.author_id,
    createdAt: row.created_at,
    modifiedAt: row.modified_at,
    timeUntilDeletion: computeDraftTimeUntilDeletion(row.modified_at),
  };
  if (row.topic_id != null) {
    out.topicId = row.topic_id;
  }
  if (row.cta1_label != null) out.cta1Label = row.cta1_label;
  if (row.cta1_url != null) out.cta1Url = row.cta1_url;
  if (row.cta2_label != null) out.cta2Label = row.cta2_label;
  if (row.cta2_url != null) out.cta2Url = row.cta2_url;
  return out;
}

export function mapLayerRow(row: LayerRow): Layer {
  return {
    id: row.id,
    name: row.name,
    type: row.type,
    parentId: row.parent_id,
    url: row.url,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function mapTopicRow(row: TopicRow): Topic {
  return {
    id: row.id,
    name: row.name,
    layerId: row.layer_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function mapEventUpdateRow(row: EventUpdateRow): EventUpdate {
  return {
    id: row.id,
    eventId: row.event_id,
    authorId: row.author_id,
    authorUsername: row.author_username,
    message: row.message,
    createdAt: row.created_at,
  };
}

const EVENT_SELECT_WITH_LAST_UPDATE = `SELECT e.*, (SELECT MAX(eu.created_at) FROM event_updates eu WHERE eu.event_id = e.id) AS last_update_at FROM events e`;

export async function getEvents(layerId?: number): Promise<Event[]> {
  const query: QueryConfig = layerId
    ? { text: `${EVENT_SELECT_WITH_LAST_UPDATE} WHERE e.layer_id = $1 ORDER BY e.start_date ASC`, values: [layerId] }
    : { text: `${EVENT_SELECT_WITH_LAST_UPDATE} ORDER BY e.start_date ASC`, values: [] };
  const result = await ensureClient().query<EventRow>(query);
  return result.rows.map(mapEventRow);
}

export async function createEvent(event: EventInput): Promise<Event> {
  return createAuthorEvent(event, null);
}

export async function createAuthorEvent(event: EventInput, authorId: number | null): Promise<Event> {
  const description = event.description ?? '';
  const startDate = event.startDate ?? new Date().toISOString();
  const endDate = event.endDate ?? startDate;
  const location = event.location ?? '';
  const layerId = event.layerId ?? null;

  const result = await ensureClient().query<EventRow>(
    `INSERT INTO events (title, description, start_date, end_date, location, layer_id, topic_id, cta1_label, cta1_url, cta2_label, cta2_url, author_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     RETURNING *`,
    [event.title, description, startDate, endDate, location, layerId, event.topicId ?? null, event.cta1Label ?? null, event.cta1Url ?? null, event.cta2Label ?? null, event.cta2Url ?? null, authorId]
  );
  return mapEventRow(result.rows[0]);
}

export async function createAuthorDraft(draft: DraftInput, authorId: number): Promise<Draft> {
  const result = await ensureClient().query<DraftRow>(
    `INSERT INTO drafts (title, description, start_date, end_date, location, layer_id, topic_id, cta1_label, cta1_url, cta2_label, cta2_url, author_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     RETURNING *`,
    [draft.title, draft.description ?? null, draft.startDate ?? null, draft.endDate ?? null, draft.location ?? null, draft.layerId ?? null, draft.topicId ?? null, draft.cta1Label ?? null, draft.cta1Url ?? null, draft.cta2Label ?? null, draft.cta2Url ?? null, authorId]
  );
  return mapDraftRow(result.rows[0]);
}

export async function deleteEventById(id: number): Promise<boolean> {
  const result = await ensureClient().query('DELETE FROM events WHERE id = $1', [id]);
  return (result.rowCount ?? 0) > 0;
}

export async function getAuthorEvents(authorId: number): Promise<Event[]> {
  const result = await ensureClient().query<EventRow>(
    `${EVENT_SELECT_WITH_LAST_UPDATE} WHERE e.author_id = $1 ORDER BY e.start_date ASC`,
    [authorId]
  );
  return result.rows.map(mapEventRow);
}

export async function updateAuthorEventById(id: number, authorId: number, event: EventInput): Promise<Event | null> {
  const endDate = event.endDate ?? event.startDate;
  const result = await ensureClient().query<EventRow>(
    `UPDATE events
     SET title = $1,
         description = $2,
         start_date = $3,
         end_date = $4,
         location = $5,
         layer_id = $6,
         topic_id = $7,
         cta1_label = $8,
         cta1_url = $9,
         cta2_label = $10,
         cta2_url = $11,
         modified_at = NOW()
    WHERE id = $12 AND author_id = $13
     RETURNING *`,
    [event.title, event.description, event.startDate, endDate, event.location, event.layerId ?? null, event.topicId ?? null, event.cta1Label ?? null, event.cta1Url ?? null, event.cta2Label ?? null, event.cta2Url ?? null, id, authorId]
  );
  return result.rows[0] ? mapEventRow(result.rows[0]) : null;
}

export async function updateEventById(id: number, event: EventInput): Promise<Event | null> {
  const endDate = event.endDate ?? event.startDate;
  const result = await ensureClient().query<EventRow>(
    `UPDATE events
     SET title = $1,
         description = $2,
         start_date = $3,
         end_date = $4,
         location = $5,
         layer_id = $6,
         topic_id = $7,
         cta1_label = $8,
         cta1_url = $9,
         cta2_label = $10,
         cta2_url = $11,
         modified_at = NOW()
    WHERE id = $12
     RETURNING *`,
    [event.title, event.description, event.startDate, endDate, event.location, event.layerId ?? null, event.topicId ?? null, event.cta1Label ?? null, event.cta1Url ?? null, event.cta2Label ?? null, event.cta2Url ?? null, id]
  );
  return result.rows[0] ? mapEventRow(result.rows[0]) : null;
}

export async function deleteAuthorEventById(id: number, authorId: number): Promise<boolean> {
  const result = await ensureClient().query('DELETE FROM events WHERE id = $1 AND author_id = $2', [id, authorId]);
  return (result.rowCount ?? 0) > 0;
}

export async function deleteAllEvents(): Promise<number> {
  const result = await ensureClient().query('DELETE FROM events');
  return result.rowCount ?? 0;
}

export async function clearEvents(): Promise<void> {
  await ensureClient().query('TRUNCATE TABLE events RESTART IDENTITY CASCADE');
}

export async function getAuthorDrafts(authorId: number): Promise<Draft[]> {
  await cleanupExpiredDrafts(true);
  const result = await ensureClient().query<DraftRow>(
    'SELECT * FROM drafts WHERE author_id = $1 ORDER BY modified_at DESC',
    [authorId]
  );
  return result.rows.map(mapDraftRow);
}

export async function updateAuthorDraftById(id: number, authorId: number, draft: DraftInput): Promise<Draft | null> {
  const result = await ensureClient().query<DraftRow>(
    `UPDATE drafts
     SET title = $1,
         description = $2,
         start_date = $3,
         end_date = $4,
         location = $5,
         layer_id = $6,
         topic_id = $7,
         cta1_label = $8,
         cta1_url = $9,
         cta2_label = $10,
         cta2_url = $11,
         modified_at = NOW()
    WHERE id = $12 AND author_id = $13
     RETURNING *`,
    [draft.title, draft.description, draft.startDate, draft.endDate, draft.location, draft.layerId ?? null, draft.topicId ?? null, draft.cta1Label ?? null, draft.cta1Url ?? null, draft.cta2Label ?? null, draft.cta2Url ?? null, id, authorId]
  );
  return result.rows[0] ? mapDraftRow(result.rows[0]) : null;
}

export async function deleteAuthorDraftById(id: number, authorId: number): Promise<boolean> {
  const result = await ensureClient().query('DELETE FROM drafts WHERE id = $1 AND author_id = $2', [id, authorId]);
  return (result.rowCount ?? 0) > 0;
}

export async function clearDrafts(): Promise<void> {
  await ensureClient().query('TRUNCATE TABLE drafts RESTART IDENTITY CASCADE');
}

export async function createEventUpdate(eventId: number, authorId: number, message: string): Promise<EventUpdate> {
  const result = await ensureClient().query<EventUpdateRow>(
    `INSERT INTO event_updates (event_id, author_id, message)
     VALUES ($1, $2, $3)
     RETURNING *, (SELECT username FROM authors WHERE id = $2) AS author_username`,
    [eventId, authorId, message]
  );
  return mapEventUpdateRow(result.rows[0]);
}

export async function getEventUpdates(eventId: number): Promise<EventUpdate[]> {
  const result = await ensureClient().query<EventUpdateRow>(
    `SELECT eu.*, a.username AS author_username
     FROM event_updates eu
     LEFT JOIN authors a ON a.id = eu.author_id
     WHERE eu.event_id = $1
     ORDER BY eu.created_at DESC`,
    [eventId]
  );
  return result.rows.map(mapEventUpdateRow);
}

export async function clearAuthorData(): Promise<void> {
  await ensureClient().query('DELETE FROM author_sessions');
  await ensureClient().query('DELETE FROM author_refresh_sessions');
  await ensureClient().query('DELETE FROM authors');
}

function normalizeAuthor(row: AuthorRow): AuthorIdentity {
  return { id: row.id, username: row.username, isAdmin: row.is_admin, adminLayerId: row.admin_layer_id };
}

export async function createAuthorForTesting(options: {
  username: string;
  password: string;
  oneTimePassword?: string;
  mustChangePassword?: boolean;
  isAdmin?: boolean;
  adminLayerId?: number | null;
}): Promise<AuthorIdentity> {
  const db = ensureClient();
  let adminLayerId = options.adminLayerId ?? null;
  if ((options.isAdmin ?? false) && adminLayerId == null) {
    const root = await db.query<{ id: number }>(
      `SELECT id FROM layers WHERE type = 'bundesverband' AND parent_id IS NULL LIMIT 1`
    );
    adminLayerId = root.rows[0]?.id ?? null;
  }
  const result = await db.query<AuthorRow>(
    `INSERT INTO authors (username, password_hash, one_time_password_hash, must_change_password, is_active, is_admin, admin_layer_id)
     VALUES ($1, $2, $3, $4, TRUE, $5, $6)
     RETURNING *`,
    [
      options.username,
      hashPassword(options.password),
      options.oneTimePassword ? hashPassword(options.oneTimePassword) : null,
      options.mustChangePassword ?? false,
      options.isAdmin ?? false,
      adminLayerId,
    ]
  );
  return normalizeAuthor(result.rows[0]);
}

export async function loginAuthor(username: string, password: string): Promise<AuthLoginSession | null> {
  await cleanupExpiredSessions();
  const result = await ensureClient().query<AuthorRow>(
    'SELECT * FROM authors WHERE username = $1 AND is_active = TRUE LIMIT 1',
    [username]
  );
  const author = result.rows[0];
  if (!author) {
    return null;
  }

  const matchesPassword = !author.must_change_password && verifyPassword(password, author.password_hash);
  const matchesOneTimePassword = author.one_time_password_hash
    ? verifyPassword(password, author.one_time_password_hash)
    : false;

  if (!matchesPassword && !matchesOneTimePassword) {
    return null;
  }

  const requiresPasswordChange = author.must_change_password || matchesOneTimePassword;
  if (matchesOneTimePassword) {
    await ensureClient().query(
      `UPDATE authors
       SET one_time_password_hash = NULL,
           must_change_password = TRUE,
           updated_at = NOW()
       WHERE id = $1`,
     [author.id]
    );
  }
  return createAuthorLoginSession(author, requiresPasswordChange);
}

export async function getAuthorSession(token: string): Promise<AuthSession | null> {
  await cleanupExpiredSessions();
  const result = await ensureClient().query<(AuthorRow & { expires_at: string })>(
    `SELECT a.*, s.expires_at
     FROM author_sessions s
     JOIN authors a ON a.id = s.author_id
     LEFT JOIN author_refresh_sessions r ON r.token_hash = s.refresh_token_hash
     WHERE s.token = $1
       AND s.expires_at > NOW()
       AND a.is_active = TRUE
      AND (
        s.refresh_token_hash IS NULL
        OR (r.revoked_at IS NULL AND r.expires_at > NOW())
      )
     LIMIT 1`,
    [token]
  );
  const session = result.rows[0];
  if (!session) {
    return null;
  }

  return {
    token,
    author: normalizeAuthor(session),
    requiresPasswordChange: session.must_change_password,
    expiresAt: session.expires_at,
  };
}

export async function refreshAuthorSession(refreshToken: string): Promise<AuthLoginSession | null> {
  await cleanupExpiredSessions();
  const db = ensureClient();
  const refreshTokenHash = hashToken(refreshToken);
  const candidateResult = await db.query<(AuthorRow & {
    token_hash: string;
    family_id: string;
    expires_at: string;
    revoked_at: string | null;
    replaced_by_token_hash: string | null;
  })>(
    `SELECT r.token_hash,
            r.family_id,
            r.expires_at,
            r.revoked_at,
            r.replaced_by_token_hash,
            a.*
     FROM author_refresh_sessions r
     JOIN authors a ON a.id = r.author_id
     WHERE r.token_hash = $1
     LIMIT 1`,
    [refreshTokenHash]
  );
  const session = candidateResult.rows[0];
  if (!session || !session.is_active) {
    return null;
  }
  if (session.revoked_at || session.replaced_by_token_hash || new Date(session.expires_at).getTime() <= Date.now()) {
    await revokeRefreshFamily(session.family_id);
    return null;
  }

  const nextRefreshToken = createRefreshTokenValue();
  const nextRefreshTokenHash = hashToken(nextRefreshToken);
  const accessToken = randomUUID();
  const accessExpiresAt = buildTokenExpiry(accessSessionTtlMinutes());
  const refreshExpiresAt = buildHoursExpiry(refreshSessionTtlHours());

  await db.query('BEGIN');
  try {
    const updated = await db.query<{ family_id: string }>(
      `UPDATE author_refresh_sessions
       SET replaced_by_token_hash = $2,
           last_used_at = NOW()
       WHERE token_hash = $1
         AND revoked_at IS NULL
         AND replaced_by_token_hash IS NULL
         AND expires_at > NOW()
       RETURNING family_id`,
      [refreshTokenHash, nextRefreshTokenHash]
    );
    if (!updated.rows[0]) {
      await db.query('ROLLBACK');
      await revokeRefreshFamily(session.family_id);
      return null;
    }

    await db.query(
      `INSERT INTO author_refresh_sessions (token_hash, author_id, family_id, expires_at)
       VALUES ($1, $2, $3, $4)`,
      [nextRefreshTokenHash, session.id, session.family_id, refreshExpiresAt]
    );
    await db.query('DELETE FROM author_sessions WHERE refresh_token_hash = $1', [refreshTokenHash]);
    await db.query(
      `INSERT INTO author_sessions (token, author_id, expires_at, refresh_token_hash)
       VALUES ($1, $2, $3, $4)`,
      [accessToken, session.id, accessExpiresAt, nextRefreshTokenHash]
    );
    await db.query('COMMIT');
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  }

  return {
    token: accessToken,
    author: normalizeAuthor(session),
    requiresPasswordChange: session.must_change_password,
    expiresAt: accessExpiresAt,
    refreshToken: nextRefreshToken,
    refreshExpiresAt,
  };
}

export type AuthorRecord = {
  id: number;
  username: string;
  isAdmin: boolean;
  isActive: boolean;
  requiresPasswordChange: boolean;
  adminLayerId: number | null;
};

function mapAuthorRecord(row: AuthorRow): AuthorRecord {
  return {
    id: row.id,
    username: row.username,
    isAdmin: row.is_admin,
    isActive: row.is_active,
    requiresPasswordChange: row.must_change_password,
    adminLayerId: row.admin_layer_id,
  };
}

export async function listAuthors(): Promise<AuthorRecord[]> {
  const result = await ensureClient().query<AuthorRow>(
    'SELECT * FROM authors ORDER BY username ASC'
  );
  return result.rows.map(mapAuthorRecord);
}

export async function getAuthorById(authorId: number): Promise<AuthorRecord | null> {
  const result = await ensureClient().query<AuthorRow>('SELECT * FROM authors WHERE id = $1', [authorId]);
  return result.rows[0] ? mapAuthorRecord(result.rows[0]) : null;
}

export async function createAuthor(options: {
  username: string;
  isAdmin?: boolean;
  adminLayerId?: number | null;
}): Promise<{ author: AuthorRecord; oneTimePassword: string }> {
  const oneTimePassword = randomUUID().split('-')[0];
  const result = await ensureClient().query<AuthorRow>(
    `INSERT INTO authors (username, password_hash, one_time_password_hash, must_change_password, is_active, is_admin, admin_layer_id)
     VALUES ($1, $2, $3, TRUE, TRUE, $4, $5)
     RETURNING *`,
    [
      options.username,
      hashPassword(randomUUID()),
      hashPassword(oneTimePassword),
      options.isAdmin ?? false,
      options.adminLayerId ?? null,
    ]
  );
  return { author: mapAuthorRecord(result.rows[0]), oneTimePassword };
}

export async function setAuthorActive(authorId: number, isActive: boolean): Promise<boolean> {
  const result = await ensureClient().query(
    'UPDATE authors SET is_active = $1, updated_at = NOW() WHERE id = $2',
    [isActive, authorId]
  );
  if (isActive === false) {
    await revokeAuthorSessions(authorId);
  }
  return (result.rowCount ?? 0) > 0;
}

export async function deleteAuthorById(authorId: number): Promise<boolean> {
  const result = await ensureClient().query(
    'DELETE FROM authors WHERE id = $1 AND is_active = FALSE',
    [authorId]
  );
  return (result.rowCount ?? 0) > 0;
}

export async function resetAuthorPassword(authorId: number): Promise<string | null> {
  const oneTimePassword = randomUUID().split('-')[0];
  const result = await ensureClient().query<AuthorRow>(
    `UPDATE authors
     SET one_time_password_hash = $1,
         must_change_password = TRUE,
         updated_at = NOW()
     WHERE id = $2
     RETURNING *`,
    [hashPassword(oneTimePassword), authorId]
  );
  if (!result.rows[0]) {
    return null;
  }
  await revokeAuthorSessions(authorId);
  return oneTimePassword;
}

export async function logoutAuthor(token: string): Promise<void> {
  const db = ensureClient();
  const result = await db.query<{ refresh_token_hash: string | null }>(
    'DELETE FROM author_sessions WHERE token = $1 RETURNING refresh_token_hash',
    [token]
  );
  const refreshTokenHash = result.rows[0]?.refresh_token_hash;
  if (!refreshTokenHash) {
    return;
  }
  await db.query(
    `UPDATE author_refresh_sessions
     SET revoked_at = NOW()
     WHERE token_hash = $1
       AND revoked_at IS NULL`,
    [refreshTokenHash]
  );
  await db.query('DELETE FROM author_sessions WHERE refresh_token_hash = $1', [refreshTokenHash]);
}

export type ChangePasswordResult =
  | 'success'
  | 'invalid_old_password'
  | 'author_not_found';

export async function changeAuthorPassword(
  authorId: number,
  newPassword: string,
  oldPassword?: string
): Promise<ChangePasswordResult> {
  const result = await ensureClient().query<AuthorRow>(
    'SELECT * FROM authors WHERE id = $1 AND is_active = TRUE LIMIT 1',
    [authorId]
  );
  const author = result.rows[0];
  if (!author) {
    return 'author_not_found';
  }

  if (!author.must_change_password) {
    if (!oldPassword || !verifyPassword(oldPassword, author.password_hash)) {
      return 'invalid_old_password';
    }
  }

  const nextHash = hashPassword(newPassword);
  await ensureClient().query(
    `UPDATE authors
     SET password_hash = $1,
         one_time_password_hash = NULL,
         must_change_password = FALSE,
         updated_at = NOW()
     WHERE id = $2`,
    [nextHash, authorId]
  );
  await revokeAuthorSessions(authorId);
  return 'success';
}

export async function getLayers(): Promise<Layer[]> {
  const result = await ensureClient().query<LayerRow>('SELECT * FROM layers ORDER BY type ASC, name ASC');
  return result.rows.map(mapLayerRow);
}

export async function getLayerById(id: number): Promise<Layer | null> {
  const result = await ensureClient().query<LayerRow>('SELECT * FROM layers WHERE id = $1', [id]);
  return result.rows[0] ? mapLayerRow(result.rows[0]) : null;
}

export async function isLayerInAdminScope(adminLayerId: number, targetLayerId: number): Promise<boolean> {
  const result = await ensureClient().query(
    `WITH RECURSIVE ancestors AS (
       SELECT id, parent_id FROM layers WHERE id = $1
       UNION ALL
       SELECT l.id, l.parent_id FROM layers l
       JOIN ancestors a ON l.id = a.parent_id
     )
     SELECT 1 FROM ancestors WHERE id = $2 LIMIT 1`,
    [targetLayerId, adminLayerId]
  );
  return result.rows.length > 0;
}

export async function getLayerSubtree(rootLayerId: number): Promise<Layer[]> {
  const result = await ensureClient().query<LayerRow>(
    `WITH RECURSIVE descendants AS (
       SELECT * FROM layers WHERE id = $1
       UNION ALL
       SELECT l.* FROM layers l
       JOIN descendants d ON l.parent_id = d.id
     )
     SELECT * FROM descendants ORDER BY type ASC, name ASC`,
    [rootLayerId]
  );
  return result.rows.map(mapLayerRow);
}

export async function getTopics(layerId?: number): Promise<Topic[]> {
  const query: QueryConfig = layerId
    ? { text: 'SELECT * FROM topics WHERE layer_id = $1 ORDER BY name ASC', values: [layerId] }
    : { text: 'SELECT * FROM topics ORDER BY name ASC', values: [] };
  const result = await ensureClient().query<TopicRow>(query);
  return result.rows.map(mapTopicRow);
}

export async function getTopicById(id: number): Promise<Topic | null> {
  const result = await ensureClient().query<TopicRow>('SELECT * FROM topics WHERE id = $1', [id]);
  return result.rows[0] ? mapTopicRow(result.rows[0]) : null;
}

export async function createTopic(input: TopicInput): Promise<Topic> {
  const result = await ensureClient().query<TopicRow>(
    `INSERT INTO topics (name, layer_id)
     VALUES ($1, $2)
     RETURNING *`,
    [input.name, input.layerId]
  );
  return mapTopicRow(result.rows[0]);
}

export async function updateTopic(id: number, name: string): Promise<Topic | null> {
  const result = await ensureClient().query<TopicRow>(
    `UPDATE topics
     SET name = $1,
         updated_at = NOW()
     WHERE id = $2
     RETURNING *`,
    [name, id]
  );
  return result.rows[0] ? mapTopicRow(result.rows[0]) : null;
}

export type DeleteTopicResult = 'deleted' | 'not_found' | 'in_use';

export async function deleteTopic(id: number): Promise<DeleteTopicResult> {
  const db = ensureClient();
  const existing = await db.query('SELECT 1 FROM topics WHERE id = $1', [id]);
  if (!existing.rows[0]) {
    return 'not_found';
  }

  const referencedByEvents = await db.query('SELECT 1 FROM events WHERE topic_id = $1 LIMIT 1', [id]);
  const referencedByDrafts = await db.query('SELECT 1 FROM drafts WHERE topic_id = $1 LIMIT 1', [id]);
  if (referencedByEvents.rows[0] || referencedByDrafts.rows[0]) {
    return 'in_use';
  }

  await db.query('DELETE FROM topics WHERE id = $1', [id]);
  return 'deleted';
}

export async function createLayer(input: LayerInput): Promise<Layer> {
  const result = await ensureClient().query<LayerRow>(
    `INSERT INTO layers (name, type, parent_id, url)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [input.name, input.type, input.parentId ?? null, input.url ?? null]
  );
  return mapLayerRow(result.rows[0]);
}

export type UpdateLayerResult =
  | { status: 'updated'; layer: Layer }
  | { status: 'not_found' }
  | { status: 'is_root' }
  | { status: 'would_create_second_root' };

export async function updateLayer(id: number, input: LayerInput): Promise<UpdateLayerResult> {
  const db = ensureClient();
  const existing = await db.query<{ parent_id: number | null }>('SELECT parent_id FROM layers WHERE id = $1', [id]);
  const existingRow = existing.rows[0];
  if (!existingRow) {
    return { status: 'not_found' };
  }

  const currentParentId = existingRow.parent_id;
  const nextParentId = input.parentId ?? null;
  if (currentParentId === null && nextParentId !== null) {
    return { status: 'is_root' };
  }
  if (currentParentId !== null && nextParentId === null) {
    return { status: 'would_create_second_root' };
  }

  const result = await db.query<LayerRow>(
    `UPDATE layers
     SET name = $1,
         type = $2,
         parent_id = $3,
         url = $4,
         updated_at = NOW()
     WHERE id = $5
     RETURNING *`,
    [input.name, input.type, nextParentId, input.url ?? null, id]
  );
  if (!result.rows[0]) {
    return { status: 'not_found' };
  }
  return { status: 'updated', layer: mapLayerRow(result.rows[0]) };
}

export type DeleteLayerResult = 'deleted' | 'not_found' | 'is_root' | 'has_children' | 'in_use';

export async function deleteLayer(id: number): Promise<DeleteLayerResult> {
  const db = ensureClient();
  const existing = await db.query<{ parent_id: number | null }>('SELECT parent_id FROM layers WHERE id = $1', [id]);
  if (!existing.rows[0]) {
    return 'not_found';
  }
  if (existing.rows[0].parent_id === null) {
    return 'is_root';
  }

  const children = await db.query('SELECT 1 FROM layers WHERE parent_id = $1 LIMIT 1', [id]);
  if (children.rows[0]) {
    return 'has_children';
  }

  const referencedByEvents = await db.query('SELECT 1 FROM events WHERE layer_id = $1 LIMIT 1', [id]);
  const referencedByDrafts = await db.query('SELECT 1 FROM drafts WHERE layer_id = $1 LIMIT 1', [id]);
  if (referencedByEvents.rows[0] || referencedByDrafts.rows[0]) {
    return 'in_use';
  }

  await db.query('DELETE FROM layers WHERE id = $1', [id]);
  return 'deleted';
}

export async function close(): Promise<void> {
  if (!client) {
    return;
  }

  await client.end();
  client = null;
}
