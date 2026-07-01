import { Client, QueryConfig } from 'pg';
import dotenv from 'dotenv';

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
  created_at: string;
  updated_at: string;
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
  createdAt: string;
  updatedAt: string;
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
    CREATE TABLE IF NOT EXISTS events (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      start_date TIMESTAMPTZ NOT NULL,
      end_date TIMESTAMPTZ NOT NULL,
      location TEXT NOT NULL,
      dv TEXT NOT NULL,
      topic TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS topic TEXT;`);
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
    createdAt: row.created_at,
    updatedAt: row.updated_at,
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
  const result = await ensureClient().query<EventRow>(
    `INSERT INTO events (title, description, start_date, end_date, location, dv, topic)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [event.title, event.description, event.startDate, event.endDate, event.location, event.dv, event.topic ?? null]
  );
  return mapEventRow(result.rows[0]);
}

export async function deleteEventById(id: number): Promise<boolean> {
  const result = await ensureClient().query('DELETE FROM events WHERE id = $1', [id]);
  return (result.rowCount ?? 0) > 0;
}

export async function deleteAllEvents(): Promise<number> {
  const result = await ensureClient().query('DELETE FROM events');
  return result.rowCount ?? 0;
}

export async function clearEvents(): Promise<void> {
  await ensureClient().query('TRUNCATE TABLE events RESTART IDENTITY CASCADE');
}

export async function close(): Promise<void> {
  if (!client) {
    return;
  }

  await client.end();
  client = null;
}
