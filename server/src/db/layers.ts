import { ADMIN_LAYER_IDS_SUBQUERY, mapAuthorRecord, maybeAutoDisableAuthor, syncAdminFlag } from './authors';
import { ensureClient } from './client';
import { AuthorRecord, AuthorRowWithGrants } from './types';

type LayerRow = {
  id: number;
  name: string;
  parent_id: number | null;
  created_at: string;
  updated_at: string;
  has_authors: boolean;
  author_count?: number;
};

export type Layer = {
  id: number;
  name: string;
  parentId: number | null;
  createdAt: string;
  updatedAt: string;
  hasAuthors: boolean;
  authorCount?: number;
};

export type LayerInput = {
  name: string;
  parentId?: number | null;
};

// `id` bleibt unqualifiziert, damit die Subquery unabhaengig vom
// FROM-Alias der jeweiligen Query (layers, descendants, RETURNING-Zeile)
// korrekt auf die aeussere Zeile korreliert -- author_layer_grants hat
// selbst keine Spalte `id`, daher ist das nie mehrdeutig.
const HAS_AUTHORS_SUBQUERY = `EXISTS (SELECT 1 FROM author_layer_grants alg WHERE alg.layer_id = id) AS has_authors`;

// Nur fuer getLayerSubtree() (Admin-Baum) -- explizite Korrelation ueber
// descendants.id statt bare `id`, weil die innere IN-Subquery ueber
// `authors` eine eigene Spalte `id` mitbringt: ein direkter JOIN gegen
// authors wuerde das bare `id` in `WHERE alg.layer_id = id` faelschlich
// auf authors.id statt auf die aeussere Zeile binden (stiller Zaehlfehler,
// kein SQL-Fehler). Die IN-Subquery ist bewusst unkorreliert gehalten.
const LAYER_AUTHOR_COUNT_SUBQUERY = `(
  SELECT COUNT(*)::int FROM author_layer_grants alg
  WHERE alg.layer_id = descendants.id
) AS author_count`;

export function mapLayerRow(row: LayerRow): Layer {
  return {
    id: row.id,
    name: row.name,
    parentId: row.parent_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    hasAuthors: row.has_authors,
    authorCount: row.author_count,
  };
}

export async function getLayers(): Promise<Layer[]> {
  const result = await ensureClient().query<LayerRow>(
    `SELECT *, ${HAS_AUTHORS_SUBQUERY} FROM layers ORDER BY name ASC`
  );
  return result.rows.map(mapLayerRow);
}

export async function getLayerById(id: number): Promise<Layer | null> {
  const result = await ensureClient().query<LayerRow>(
    `SELECT *, ${HAS_AUTHORS_SUBQUERY} FROM layers WHERE id = $1`,
    [id]
  );
  return result.rows[0] ? mapLayerRow(result.rows[0]) : null;
}

export async function getRootLayerId(): Promise<number | null> {
  const result = await ensureClient().query<{ id: number }>(
    `SELECT id FROM layers WHERE parent_id IS NULL LIMIT 1`
  );
  return result.rows[0]?.id ?? null;
}

export async function isLayerInAdminScope(adminLayerIds: number[], targetLayerId: number): Promise<boolean> {
  if (adminLayerIds.length === 0) {
    return false;
  }
  const result = await ensureClient().query(
    `WITH RECURSIVE ancestors AS (
       SELECT id, parent_id FROM layers WHERE id = $1
       UNION ALL
       SELECT l.id, l.parent_id FROM layers l
       JOIN ancestors a ON l.id = a.parent_id
     )
     SELECT 1 FROM ancestors WHERE id = ANY($2::int[]) LIMIT 1`,
    [targetLayerId, adminLayerIds]
  );
  return result.rows.length > 0;
}

export async function getLayerSubtree(rootLayerIds: number[]): Promise<Layer[]> {
  if (rootLayerIds.length === 0) {
    return [];
  }
  const result = await ensureClient().query<LayerRow>(
    `WITH RECURSIVE descendants AS (
       SELECT * FROM layers WHERE id = ANY($1::int[])
       UNION ALL
       SELECT l.* FROM layers l
       JOIN descendants d ON l.parent_id = d.id
     )
     SELECT DISTINCT *, ${HAS_AUTHORS_SUBQUERY}, ${LAYER_AUTHOR_COUNT_SUBQUERY} FROM descendants ORDER BY name ASC`,
    [rootLayerIds]
  );
  return result.rows.map(mapLayerRow);
}

export type LayerAdminRecord = AuthorRecord & { scope: 'direct' | 'inherited' };

export async function getLayerAdmins(layerId: number): Promise<LayerAdminRecord[]> {
  const result = await ensureClient().query<AuthorRowWithGrants & { is_direct: boolean }>(
    `WITH RECURSIVE ancestors AS (
       SELECT id, parent_id FROM layers WHERE id = $1
       UNION ALL
       SELECT l.id, l.parent_id FROM layers l
       JOIN ancestors a ON l.id = a.parent_id
     )
     SELECT a.*,
       ${ADMIN_LAYER_IDS_SUBQUERY},
       (SELECT COALESCE(array_agg(layer_id), ARRAY[]::int[]) FROM author_layer_grants WHERE author_id = a.id) AS layer_grant_ids,
       (SELECT COALESCE(array_agg(topic_id), ARRAY[]::int[]) FROM author_topic_grants WHERE author_id = a.id) AS topic_grant_ids,
       EXISTS (
         SELECT 1 FROM author_admin_layers aal WHERE aal.author_id = a.id AND aal.layer_id = $1
       ) AS is_direct
     FROM authors a
     WHERE a.is_admin = TRUE
       AND a.is_active = TRUE
       AND EXISTS (
         SELECT 1 FROM author_admin_layers aal
         JOIN ancestors anc ON anc.id = aal.layer_id
         WHERE aal.author_id = a.id
       )
     ORDER BY a.username ASC`,
    [layerId]
  );
  return result.rows.map((row) => ({
    ...mapAuthorRecord(row),
    scope: row.is_direct ? ('direct' as const) : ('inherited' as const),
  }));
}

export type RemoveAdminLayerResult = 'removed' | 'not_found' | 'last_layer';

export async function getAdminLayerIds(authorId: number): Promise<number[]> {
  const result = await ensureClient().query<{ layer_id: number }>(
    'SELECT layer_id FROM author_admin_layers WHERE author_id = $1 ORDER BY layer_id ASC',
    [authorId]
  );
  return result.rows.map((row) => row.layer_id);
}

export async function addAdminLayer(authorId: number, layerId: number): Promise<void> {
  await ensureClient().query(
    'INSERT INTO author_admin_layers (author_id, layer_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
    [authorId, layerId]
  );
  await syncAdminFlag(authorId);
}

export async function removeAdminLayer(authorId: number, layerId: number): Promise<RemoveAdminLayerResult> {
  const db = ensureClient();
  const current = await db.query<{ layer_id: number }>(
    'SELECT layer_id FROM author_admin_layers WHERE author_id = $1',
    [authorId]
  );
  const hasLayer = current.rows.some((row) => row.layer_id === layerId);
  if (!hasLayer) {
    return 'not_found';
  }
  if (current.rows.length <= 1) {
    return 'last_layer';
  }
  await db.query('DELETE FROM author_admin_layers WHERE author_id = $1 AND layer_id = $2', [authorId, layerId]);
  await syncAdminFlag(authorId);
  await maybeAutoDisableAuthor(authorId);
  return 'removed';
}

export async function getAuthorLayerGrantIds(authorId: number): Promise<number[]> {
  const result = await ensureClient().query<{ layer_id: number }>(
    'SELECT layer_id FROM author_layer_grants WHERE author_id = $1 ORDER BY layer_id ASC',
    [authorId]
  );
  return result.rows.map((row) => row.layer_id);
}

export async function addAuthorLayerGrant(authorId: number, layerId: number): Promise<void> {
  await ensureClient().query(
    'INSERT INTO author_layer_grants (author_id, layer_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
    [authorId, layerId]
  );
}

export async function removeAuthorLayerGrant(authorId: number, layerId: number): Promise<void> {
  await ensureClient().query(
    'DELETE FROM author_layer_grants WHERE author_id = $1 AND layer_id = $2',
    [authorId, layerId]
  );
  await maybeAutoDisableAuthor(authorId);
}

export async function createLayer(input: LayerInput): Promise<Layer> {
  const result = await ensureClient().query<LayerRow>(
    `INSERT INTO layers (name, parent_id)
     VALUES ($1, $2)
     RETURNING *, FALSE AS has_authors`,
    [input.name, input.parentId ?? null]
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
         parent_id = $2,
         updated_at = NOW()
     WHERE id = $3
     RETURNING *, ${HAS_AUTHORS_SUBQUERY}`,
    [input.name, nextParentId, id]
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
