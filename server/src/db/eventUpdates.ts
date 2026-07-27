import { ensureClient } from './client';

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

export async function getEventUpdateById(id: number): Promise<EventUpdate | null> {
  const result = await ensureClient().query<EventUpdateRow>(
    `SELECT eu.*, a.username AS author_username
     FROM event_updates eu
     LEFT JOIN authors a ON a.id = eu.author_id
     WHERE eu.id = $1`,
    [id]
  );
  return result.rows[0] ? mapEventUpdateRow(result.rows[0]) : null;
}

export async function updateEventUpdateById(id: number, message: string): Promise<EventUpdate | null> {
  const result = await ensureClient().query<EventUpdateRow>(
    `UPDATE event_updates
     SET message = $1
     WHERE id = $2
     RETURNING *, (SELECT username FROM authors WHERE id = event_updates.author_id) AS author_username`,
    [message, id]
  );
  return result.rows[0] ? mapEventUpdateRow(result.rows[0]) : null;
}

export async function deleteEventUpdateById(id: number): Promise<boolean> {
  const result = await ensureClient().query('DELETE FROM event_updates WHERE id = $1', [id]);
  return (result.rowCount ?? 0) > 0;
}
