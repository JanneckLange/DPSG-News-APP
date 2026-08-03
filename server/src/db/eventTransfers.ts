import { ensureClient } from './client';

export type EventTransferRequestStatus = 'pending' | 'accepted' | 'rejected' | 'cancelled' | 'invalid';

type EventTransferRequestRow = {
  id: number;
  event_id: number;
  from_author_id: number;
  to_author_id: number;
  status: EventTransferRequestStatus;
  requested_at: string;
  resolved_at: string | null;
};

export type EventTransferRequest = {
  id: number;
  eventId: number;
  fromAuthorId: number;
  toAuthorId: number;
  status: EventTransferRequestStatus;
  requestedAt: string;
  resolvedAt: string | null;
};

export function mapEventTransferRequestRow(row: EventTransferRequestRow): EventTransferRequest {
  return {
    id: row.id,
    eventId: row.event_id,
    fromAuthorId: row.from_author_id,
    toAuthorId: row.to_author_id,
    status: row.status,
    requestedAt: row.requested_at,
    resolvedAt: row.resolved_at,
  };
}

// Storniert eine evtl. vorhandene offene Anfrage fuer dasselbe Event und legt die
// neue in derselben Transaktion an - pro Event ist immer nur eine Anfrage aktiv.
export async function createEventTransferRequest(
  eventId: number,
  fromAuthorId: number,
  toAuthorId: number
): Promise<EventTransferRequest> {
  const db = ensureClient();
  await db.query('BEGIN');
  try {
    await db.query(
      `UPDATE event_transfer_requests SET status = 'cancelled', resolved_at = NOW() WHERE event_id = $1 AND status = 'pending'`,
      [eventId]
    );
    const result = await db.query<EventTransferRequestRow>(
      `INSERT INTO event_transfer_requests (event_id, from_author_id, to_author_id)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [eventId, fromAuthorId, toAuthorId]
    );
    await db.query('COMMIT');
    return mapEventTransferRequestRow(result.rows[0]);
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  }
}

export async function getEventTransferRequestById(id: number): Promise<EventTransferRequest | null> {
  const result = await ensureClient().query<EventTransferRequestRow>(
    `SELECT * FROM event_transfer_requests WHERE id = $1`,
    [id]
  );
  return result.rows[0] ? mapEventTransferRequestRow(result.rows[0]) : null;
}

export async function getPendingEventTransferRequestForEvent(eventId: number): Promise<EventTransferRequest | null> {
  const result = await ensureClient().query<EventTransferRequestRow>(
    `SELECT * FROM event_transfer_requests WHERE event_id = $1 AND status = 'pending'`,
    [eventId]
  );
  return result.rows[0] ? mapEventTransferRequestRow(result.rows[0]) : null;
}

export async function getEventTransferRequestsForEvent(eventId: number): Promise<EventTransferRequest[]> {
  const result = await ensureClient().query<EventTransferRequestRow>(
    `SELECT * FROM event_transfer_requests WHERE event_id = $1 ORDER BY requested_at DESC`,
    [eventId]
  );
  return result.rows.map(mapEventTransferRequestRow);
}

export async function getIncomingEventTransferRequests(toAuthorId: number): Promise<EventTransferRequest[]> {
  const result = await ensureClient().query<EventTransferRequestRow>(
    `SELECT * FROM event_transfer_requests WHERE to_author_id = $1 AND status = 'pending' ORDER BY requested_at DESC`,
    [toAuthorId]
  );
  return result.rows.map(mapEventTransferRequestRow);
}

// Setzt den Endstatus einer Anfrage. Betrifft nur noch-pending Anfragen, damit
// eine bereits aufgeloeste Anfrage (Race zwischen zwei parallelen Requests) nicht
// nachtraeglich ueberschrieben wird.
export async function resolveEventTransferRequest(
  id: number,
  status: Exclude<EventTransferRequestStatus, 'pending'>
): Promise<EventTransferRequest | null> {
  const result = await ensureClient().query<EventTransferRequestRow>(
    `UPDATE event_transfer_requests SET status = $1, resolved_at = NOW() WHERE id = $2 AND status = 'pending' RETURNING *`,
    [status, id]
  );
  return result.rows[0] ? mapEventTransferRequestRow(result.rows[0]) : null;
}

export async function clearEventTransferRequests(): Promise<void> {
  await ensureClient().query('TRUNCATE TABLE event_transfer_requests RESTART IDENTITY CASCADE');
}
