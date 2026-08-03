import { QueryConfig } from 'pg';
import { ensureClient } from './client';

type EventRow = {
  id: number;
  title: string;
  description: string | null;
  start_date: string | null;
  end_date: string | null;
  location_address: string | null;
  location_lat: number | null;
  location_lng: number | null;
  layer_id: number | null;
  topic_id?: number | null;
  cta1_url: string | null;
  cta2_url: string | null;
  is_public: boolean;
  publish_at: string | null;
  registration_deadline: string | null;
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
  locationAddress?: string;
  locationLat?: number;
  locationLng?: number;
  layerId: number | null;
  topicId?: number;
  cta1Url?: string;
  cta2Url?: string;
  isPublic: boolean;
  publishAt?: string;
  registrationDeadline?: string;
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
  locationAddress?: string;
  locationLat?: number;
  locationLng?: number;
  layerId?: number;
  topicId?: number;
  cta1Url?: string;
  cta2Url?: string;
  isPublic?: boolean;
  publishAt?: string;
  registrationDeadline?: string;
};

export function mapEventRow(row: EventRow): Event {
  const out: Event = {
    id: row.id,
    title: row.title,
    description: row.description ?? '',
    startDate: row.start_date ?? '',
    endDate: row.end_date ?? '',
    layerId: row.layer_id,
    isPublic: row.is_public,
    authorId: row.author_id,
    createdAt: row.created_at,
    modifiedAt: row.modified_at,
  };
  if (row.topic_id != null) {
    out.topicId = row.topic_id;
  }
  if (row.location_address != null) out.locationAddress = row.location_address;
  if (row.location_lat != null) out.locationLat = row.location_lat;
  if (row.location_lng != null) out.locationLng = row.location_lng;
  if (row.cta1_url != null) out.cta1Url = row.cta1_url;
  if (row.cta2_url != null) out.cta2Url = row.cta2_url;
  if (row.publish_at != null) out.publishAt = row.publish_at;
  if (row.registration_deadline != null) out.registrationDeadline = row.registration_deadline;
  if (row.last_update_at != null) out.lastUpdateAt = row.last_update_at;
  return out;
}

const EVENT_SELECT_WITH_LAST_UPDATE = `SELECT e.*, (SELECT MAX(eu.created_at) FROM event_updates eu WHERE eu.event_id = e.id) AS last_update_at FROM events e`;

export type GetEventsOptions = {
  includeUnpublished?: boolean;
};

export async function getEvents(layerId?: number, options: GetEventsOptions = {}): Promise<Event[]> {
  const conditions: string[] = [];
  const values: unknown[] = [];
  if (layerId) {
    values.push(layerId);
    conditions.push(`e.layer_id = $${values.length}`);
  }
  if (!options.includeUnpublished) {
    conditions.push(`(e.publish_at IS NULL OR e.publish_at <= NOW())`);
  }
  const where = conditions.length > 0 ? ` WHERE ${conditions.join(' AND ')}` : '';
  const query: QueryConfig = {
    text: `${EVENT_SELECT_WITH_LAST_UPDATE}${where} ORDER BY e.start_date ASC`,
    values,
  };
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
  const layerId = event.layerId ?? null;

  const result = await ensureClient().query<EventRow>(
    `INSERT INTO events (title, description, start_date, end_date, location_address, location_lat, location_lng, layer_id, topic_id, cta1_url, cta2_url, is_public, publish_at, registration_deadline, author_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
     RETURNING *`,
    [event.title, description, startDate, endDate, event.locationAddress ?? null, event.locationLat ?? null, event.locationLng ?? null, layerId, event.topicId ?? null, event.cta1Url ?? null, event.cta2Url ?? null, event.isPublic ?? false, event.publishAt ?? null, event.registrationDeadline ?? null, authorId]
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
         location_address = $5,
         location_lat = $6,
         location_lng = $7,
         layer_id = $8,
         topic_id = $9,
         cta1_url = $10,
         cta2_url = $11,
         is_public = $12,
         publish_at = $13,
         registration_deadline = $14,
         modified_at = NOW()
    WHERE id = $15 AND author_id = $16
     RETURNING *`,
    [event.title, event.description, event.startDate, endDate, event.locationAddress ?? null, event.locationLat ?? null, event.locationLng ?? null, event.layerId ?? null, event.topicId ?? null, event.cta1Url ?? null, event.cta2Url ?? null, event.isPublic ?? false, event.publishAt ?? null, event.registrationDeadline ?? null, id, authorId]
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
         location_address = $5,
         location_lat = $6,
         location_lng = $7,
         layer_id = $8,
         topic_id = $9,
         cta1_url = $10,
         cta2_url = $11,
         is_public = $12,
         publish_at = $13,
         registration_deadline = $14,
         modified_at = NOW()
    WHERE id = $15
     RETURNING *`,
    [event.title, event.description, event.startDate, endDate, event.locationAddress ?? null, event.locationLat ?? null, event.locationLng ?? null, event.layerId ?? null, event.topicId ?? null, event.cta1Url ?? null, event.cta2Url ?? null, event.isPublic ?? false, event.publishAt ?? null, event.registrationDeadline ?? null, id]
  );
  return result.rows[0] ? mapEventRow(result.rows[0]) : null;
}

export async function deleteAuthorEventById(id: number, authorId: number): Promise<boolean> {
  const result = await ensureClient().query('DELETE FROM events WHERE id = $1 AND author_id = $2', [id, authorId]);
  return (result.rowCount ?? 0) > 0;
}

// Schreibt ausschliesslich author_id um (Event-Uebertragung, #22/#23) - anders
// als updateEventById/updateAuthorEventById wird kein vollstaendiges EventInput
// verlangt, da sich an den restlichen Feldern nichts aendert.
export async function transferEventAuthorById(id: number, authorId: number): Promise<Event | null> {
  const result = await ensureClient().query<EventRow>(
    `UPDATE events SET author_id = $1, modified_at = NOW() WHERE id = $2 RETURNING *`,
    [authorId, id]
  );
  return result.rows[0] ? mapEventRow(result.rows[0]) : null;
}

export async function deleteAllEvents(): Promise<number> {
  const result = await ensureClient().query('DELETE FROM events');
  return result.rowCount ?? 0;
}

export async function clearEvents(): Promise<void> {
  await ensureClient().query('TRUNCATE TABLE events RESTART IDENTITY CASCADE');
}
