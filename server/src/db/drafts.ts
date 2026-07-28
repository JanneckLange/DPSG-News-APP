import { ensureClient, positiveIntegerFromEnv } from './client';

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
  is_public: boolean;
  publish_at: string | null;
  registration_deadline: string | null;
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
  isPublic: boolean;
  publishAt?: string;
  registrationDeadline?: string;
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
  isPublic?: boolean;
  publishAt?: string;
  registrationDeadline?: string;
};

let lastDraftCleanupAtMs = 0;

function draftRetentionDays(): number {
  return positiveIntegerFromEnv('DRAFT_RETENTION_DAYS', 90);
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

export function mapDraftRow(row: DraftRow): Draft {
  const out: Draft = {
    id: row.id,
    title: row.title,
    description: row.description ?? '',
    startDate: row.start_date ?? '',
    endDate: row.end_date ?? '',
    location: row.location ?? '',
    layerId: row.layer_id,
    isPublic: row.is_public,
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
  if (row.publish_at != null) out.publishAt = row.publish_at;
  if (row.registration_deadline != null) out.registrationDeadline = row.registration_deadline;
  return out;
}

export async function createAuthorDraft(draft: DraftInput, authorId: number): Promise<Draft> {
  const result = await ensureClient().query<DraftRow>(
    `INSERT INTO drafts (title, description, start_date, end_date, location, layer_id, topic_id, cta1_label, cta1_url, cta2_label, cta2_url, is_public, publish_at, registration_deadline, author_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
     RETURNING *`,
    [draft.title, draft.description ?? null, draft.startDate ?? null, draft.endDate ?? null, draft.location ?? null, draft.layerId ?? null, draft.topicId ?? null, draft.cta1Label ?? null, draft.cta1Url ?? null, draft.cta2Label ?? null, draft.cta2Url ?? null, draft.isPublic ?? false, draft.publishAt ?? null, draft.registrationDeadline ?? null, authorId]
  );
  return mapDraftRow(result.rows[0]);
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
         is_public = $12,
         publish_at = $13,
         registration_deadline = $14,
         modified_at = NOW()
    WHERE id = $15 AND author_id = $16
     RETURNING *`,
    [draft.title, draft.description, draft.startDate, draft.endDate, draft.location, draft.layerId ?? null, draft.topicId ?? null, draft.cta1Label ?? null, draft.cta1Url ?? null, draft.cta2Label ?? null, draft.cta2Url ?? null, draft.isPublic ?? false, draft.publishAt ?? null, draft.registrationDeadline ?? null, id, authorId]
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
