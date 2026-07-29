import { ensureClient } from './client';
import { Event } from './events';

const TRACKED_FIELDS: (keyof Event)[] = [
  'title',
  'description',
  'startDate',
  'endDate',
  'locationAddress',
  'locationLat',
  'locationLng',
  'layerId',
  'topicId',
  'cta1Url',
  'cta2Url',
  'isPublic',
  'publishAt',
  'registrationDeadline',
];

export type FieldChange = {
  field: string;
  oldValue: unknown;
  newValue: unknown;
};

type EventHistoryRow = {
  id: number;
  event_id: number;
  author_id: number | null;
  changes: FieldChange[];
  created_at: string;
  author_username: string | null;
};

export type EventHistoryEntry = {
  id: number;
  eventId: number;
  authorId: number | null;
  authorUsername: string | null;
  changes: FieldChange[];
  createdAt: string;
};

export function mapEventHistoryRow(row: EventHistoryRow): EventHistoryEntry {
  return {
    id: row.id,
    eventId: row.event_id,
    authorId: row.author_id,
    authorUsername: row.author_username,
    changes: row.changes,
    createdAt: row.created_at,
  };
}

export function diffEventFields(before: Event, after: Event): FieldChange[] {
  const changes: FieldChange[] = [];
  for (const field of TRACKED_FIELDS) {
    const oldValue = before[field] ?? null;
    const newValue = after[field] ?? null;
    if (oldValue !== newValue) {
      changes.push({ field, oldValue, newValue });
    }
  }
  return changes;
}

export async function recordEventHistory(eventId: number, editorId: number, before: Event, after: Event): Promise<void> {
  const changes = diffEventFields(before, after);
  if (changes.length === 0) {
    return;
  }
  await ensureClient().query(
    `INSERT INTO event_history (event_id, author_id, changes) VALUES ($1, $2, $3)`,
    [eventId, editorId, JSON.stringify(changes)]
  );
}

export async function getEventHistory(eventId: number): Promise<EventHistoryEntry[]> {
  const result = await ensureClient().query<EventHistoryRow>(
    `SELECT eh.*, a.username AS author_username
     FROM event_history eh
     LEFT JOIN authors a ON a.id = eh.author_id
     WHERE eh.event_id = $1
     ORDER BY eh.created_at DESC`,
    [eventId]
  );
  return result.rows.map(mapEventHistoryRow);
}
