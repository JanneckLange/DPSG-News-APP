import { QueryConfig } from 'pg';
import { ensureClient } from './client';

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
