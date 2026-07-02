import { randomUUID } from 'crypto';
import { Client, QueryConfig } from 'pg';
import dotenv from 'dotenv';
import { hashPassword, verifyPassword } from './password';

dotenv.config();

type EventRow = {
  id: number;
  title: string;
  description: string;
  start_date: string;
  end_date: string;
  location: string;
  dv: string;
  topic?: string;
  author_id: number | null;
  created_at: string;
  modified_at: string;
};

export type Event = {
  id: number;
  title: string;
  description: string;
  startDate: string;
  endDate: string;
  location: string;
  dv: string;
  topic?: string;
  authorId: number | null;
  createdAt: string;
  modifiedAt: string;
};

export type EventInput = {
  title: string;
  description: string;
  startDate: string;
  endDate: string;
  location: string;
  dv: string;
  topic?: string;
};

type AuthorRow = {
  id: number;
  username: string;
  password_hash: string;
  one_time_password_hash: string | null;
  must_change_password: boolean;
  is_active: boolean;
  is_admin: boolean;
};

export type AuthorIdentity = {
  id: number;
  username: string;
  isAdmin: boolean;
};

export type AuthSession = {
  token: string;
  author: AuthorIdentity;
  requiresPasswordChange: boolean;
  expiresAt: string;
};

let client: Client | null = null;

function getDatabaseUrl(): string {
  return process.env.TEST_DATABASE_URL || process.env.DATABASE_URL || '';
}

function ensureClient(): Client {
  if (!client) {
    throw new Error('Database is not connected');
  }
  return client;
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
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`
    CREATE TABLE IF NOT EXISTS events (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      start_date TIMESTAMPTZ NOT NULL,
      end_date TIMESTAMPTZ NOT NULL,
      location TEXT NOT NULL,
      dv TEXT NOT NULL,
      topic TEXT,
      author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS topic TEXT;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW();`);
  await client.query(`UPDATE events SET modified_at = created_at WHERE modified_at IS NULL;`);
  await ensureBootstrapAuthor();
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
     DO UPDATE SET one_time_password_hash = EXCLUDED.one_time_password_hash,
                   must_change_password = TRUE,
                   is_active = TRUE,
                   is_admin = TRUE,
                   updated_at = NOW()`,
    [bootstrapUsername, hashPassword(randomUUID()), hashPassword(bootstrapOneTimePassword)]
  );
}

export function mapEventRow(row: EventRow): Event {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    startDate: row.start_date,
    endDate: row.end_date,
    location: row.location,
    dv: row.dv,
    topic: row.topic ?? undefined,
    authorId: row.author_id,
    createdAt: row.created_at,
    modifiedAt: row.modified_at,
  };
}

export async function getEvents(dv?: string): Promise<Event[]> {
  const query: QueryConfig = dv
    ? { text: 'SELECT * FROM events WHERE dv = $1 ORDER BY start_date ASC', values: [dv] }
    : { text: 'SELECT * FROM events ORDER BY start_date ASC', values: [] };
  const result = await ensureClient().query<EventRow>(query);
  return result.rows.map(mapEventRow);
}

export async function createEvent(event: EventInput): Promise<Event> {
  return createAuthorEvent(event, null);
}

export async function createAuthorEvent(event: EventInput, authorId: number | null): Promise<Event> {
  const result = await ensureClient().query<EventRow>(
    `INSERT INTO events (title, description, start_date, end_date, location, dv, topic, author_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [event.title, event.description, event.startDate, event.endDate, event.location, event.dv, event.topic ?? null, authorId]
  );
  return mapEventRow(result.rows[0]);
}

export async function deleteEventById(id: number): Promise<boolean> {
  const result = await ensureClient().query('DELETE FROM events WHERE id = $1', [id]);
  return (result.rowCount ?? 0) > 0;
}

export async function getAuthorEvents(authorId: number): Promise<Event[]> {
  const result = await ensureClient().query<EventRow>(
    'SELECT * FROM events WHERE author_id = $1 ORDER BY start_date ASC',
    [authorId]
  );
  return result.rows.map(mapEventRow);
}

export async function updateAuthorEventById(id: number, authorId: number, event: EventInput): Promise<Event | null> {
  const result = await ensureClient().query<EventRow>(
    `UPDATE events
     SET title = $1,
         description = $2,
         start_date = $3,
         end_date = $4,
         location = $5,
         dv = $6,
         topic = $7,
         modified_at = NOW()
     WHERE id = $8 AND author_id = $9
     RETURNING *`,
    [event.title, event.description, event.startDate, event.endDate, event.location, event.dv, event.topic ?? null, id, authorId]
  );
  return result.rows[0] ? mapEventRow(result.rows[0]) : null;
}

export async function updateEventById(id: number, event: EventInput): Promise<Event | null> {
  const result = await ensureClient().query<EventRow>(
    `UPDATE events
     SET title = $1,
         description = $2,
         start_date = $3,
         end_date = $4,
         location = $5,
         dv = $6,
         topic = $7,
         modified_at = NOW()
     WHERE id = $8
     RETURNING *`,
    [event.title, event.description, event.startDate, event.endDate, event.location, event.dv, event.topic ?? null, id]
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

export async function clearAuthorData(): Promise<void> {
  await ensureClient().query('DELETE FROM author_sessions');
  await ensureClient().query('DELETE FROM authors');
}

function normalizeAuthor(row: AuthorRow): AuthorIdentity {
  return { id: row.id, username: row.username, isAdmin: row.is_admin };
}

export async function createAuthorForTesting(options: {
  username: string;
  password: string;
  oneTimePassword?: string;
  mustChangePassword?: boolean;
  isAdmin?: boolean;
}): Promise<AuthorIdentity> {
  const result = await ensureClient().query<AuthorRow>(
    `INSERT INTO authors (username, password_hash, one_time_password_hash, must_change_password, is_active, is_admin)
     VALUES ($1, $2, $3, $4, TRUE, $5)
     RETURNING *`,
    [
      options.username,
      hashPassword(options.password),
      options.oneTimePassword ? hashPassword(options.oneTimePassword) : null,
      options.mustChangePassword ?? false,
      options.isAdmin ?? false,
    ]
  );
  return normalizeAuthor(result.rows[0]);
}

function sessionTtlHours(): number {
  const raw = Number(process.env.AUTH_SESSION_TTL_HOURS ?? 720);
  if (!Number.isFinite(raw) || raw <= 0) {
    return 720;
  }
  return raw;
}

export async function loginAuthor(username: string, password: string): Promise<AuthSession | null> {
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

  const token = randomUUID();
  const expiresAt = new Date(Date.now() + sessionTtlHours() * 60 * 60 * 1000).toISOString();
  await ensureClient().query(
    `INSERT INTO author_sessions (token, author_id, expires_at)
     VALUES ($1, $2, $3)`,
    [token, author.id, expiresAt]
  );

  return {
    token,
    author: normalizeAuthor(author),
    requiresPasswordChange,
    expiresAt,
  };
}

export async function getAuthorSession(token: string): Promise<AuthSession | null> {
  const result = await ensureClient().query<(AuthorRow & { expires_at: string })>(
    `SELECT a.*, s.expires_at
     FROM author_sessions s
     JOIN authors a ON a.id = s.author_id
     WHERE s.token = $1
       AND s.expires_at > NOW()
       AND a.is_active = TRUE
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

export type AuthorRecord = {
  id: number;
  username: string;
  isAdmin: boolean;
  isActive: boolean;
  requiresPasswordChange: boolean;
};

export async function listAuthors(): Promise<AuthorRecord[]> {
  const result = await ensureClient().query<AuthorRow>(
    'SELECT * FROM authors ORDER BY username ASC'
  );
  return result.rows.map((row) => ({
    id: row.id,
    username: row.username,
    isAdmin: row.is_admin,
    isActive: row.is_active,
    requiresPasswordChange: row.must_change_password,
  }));
}

export async function createAuthor(options: {
  username: string;
  isAdmin?: boolean;
}): Promise<{ author: AuthorRecord; oneTimePassword: string }> {
  const oneTimePassword = randomUUID().split('-')[0];
  const result = await ensureClient().query<AuthorRow>(
    `INSERT INTO authors (username, password_hash, one_time_password_hash, must_change_password, is_active, is_admin)
     VALUES ($1, $2, $3, TRUE, TRUE, $4)
     RETURNING *`,
    [options.username, hashPassword(randomUUID()), hashPassword(oneTimePassword), options.isAdmin ?? false]
  );
  const row = result.rows[0];
  return {
    author: {
      id: row.id,
      username: row.username,
      isAdmin: row.is_admin,
      isActive: row.is_active,
      requiresPasswordChange: row.must_change_password,
    },
    oneTimePassword,
  };
}

export async function setAuthorActive(authorId: number, isActive: boolean): Promise<boolean> {
  const result = await ensureClient().query(
    'UPDATE authors SET is_active = $1, updated_at = NOW() WHERE id = $2',
    [isActive, authorId]
  );
  if (isActive === false) {
    await ensureClient().query('DELETE FROM author_sessions WHERE author_id = $1', [authorId]);
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
  return oneTimePassword;
}

export async function logoutAuthor(token: string): Promise<void> {
  await ensureClient().query('DELETE FROM author_sessions WHERE token = $1', [token]);
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
  return 'success';
}

export async function close(): Promise<void> {
  if (!client) {
    return;
  }

  await client.end();
  client = null;
}
