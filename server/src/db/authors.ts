import { randomUUID } from 'crypto';
import { hashPassword, verifyPassword } from '../password';
import {
  accessSessionTtlMinutes,
  buildHoursExpiry,
  buildTokenExpiry,
  createRefreshTokenValue,
  ensureClient,
  hashToken,
  refreshSessionTtlHours,
} from './client';
import { AuthorRecord, AuthorRow, AuthorRowWithGrants } from './types';

export type AuthorIdentity = {
  id: number;
  username: string;
  isAdmin: boolean;
  adminLayerIds: number[];
  layerGrantIds: number[];
  topicGrantIds: number[];
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

let lastSessionCleanupAtMs = 0;

export async function cleanupExpiredSessions(force = false): Promise<void> {
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

async function createAuthorLoginSession(author: AuthorRowWithGrants, requiresPasswordChange: boolean): Promise<AuthLoginSession> {
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

export async function clearAuthorData(): Promise<void> {
  await ensureClient().query('DELETE FROM author_sessions');
  await ensureClient().query('DELETE FROM author_refresh_sessions');
  await ensureClient().query('DELETE FROM authors');
}

function normalizeAuthor(row: AuthorRowWithGrants): AuthorIdentity {
  return {
    id: row.id,
    username: row.username,
    isAdmin: row.is_admin,
    adminLayerIds: row.admin_layer_ids,
    layerGrantIds: row.layer_grant_ids,
    topicGrantIds: row.topic_grant_ids,
  };
}

export const ADMIN_LAYER_IDS_SUBQUERY = `(
  SELECT COALESCE(array_agg(layer_id), ARRAY[]::int[])
  FROM author_admin_layers
  WHERE author_id = a.id
) AS admin_layer_ids`;

const LAYER_GRANT_IDS_SUBQUERY = `(
  SELECT COALESCE(array_agg(layer_id), ARRAY[]::int[])
  FROM author_layer_grants
  WHERE author_id = a.id
) AS layer_grant_ids`;

const TOPIC_GRANT_IDS_SUBQUERY = `(
  SELECT COALESCE(array_agg(topic_id), ARRAY[]::int[])
  FROM author_topic_grants
  WHERE author_id = a.id
) AS topic_grant_ids`;

export async function createAuthorForTesting(options: {
  username: string;
  password: string;
  oneTimePassword?: string;
  mustChangePassword?: boolean;
  isAdmin?: boolean;
  adminLayerIds?: number[];
  layerGrantIds?: number[];
  topicGrantIds?: number[];
}): Promise<AuthorIdentity> {
  const db = ensureClient();
  let adminLayerIds = options.adminLayerIds ?? [];
  if ((options.isAdmin ?? false) && adminLayerIds.length === 0) {
    const root = await db.query<{ id: number }>(
      `SELECT id FROM layers WHERE parent_id IS NULL LIMIT 1`
    );
    const rootId = root.rows[0]?.id;
    adminLayerIds = rootId ? [rootId] : [];
  }
  const layerGrantIds = options.layerGrantIds ?? [];
  const topicGrantIds = options.topicGrantIds ?? [];
  await db.query('BEGIN');
  try {
    const result = await db.query<AuthorRow>(
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
    const author = result.rows[0];
    for (const layerId of adminLayerIds) {
      await db.query(
        `INSERT INTO author_admin_layers (author_id, layer_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [author.id, layerId]
      );
    }
    for (const layerId of layerGrantIds) {
      await db.query(
        `INSERT INTO author_layer_grants (author_id, layer_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [author.id, layerId]
      );
    }
    for (const topicId of topicGrantIds) {
      await db.query(
        `INSERT INTO author_topic_grants (author_id, topic_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [author.id, topicId]
      );
    }
    await db.query('COMMIT');
    return normalizeAuthor({ ...author, admin_layer_ids: adminLayerIds, layer_grant_ids: layerGrantIds, topic_grant_ids: topicGrantIds });
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  }
}

export async function loginAuthor(username: string, password: string): Promise<AuthLoginSession | null> {
  await cleanupExpiredSessions();
  const result = await ensureClient().query<AuthorRowWithGrants>(
    `SELECT a.*, ${ADMIN_LAYER_IDS_SUBQUERY}, ${LAYER_GRANT_IDS_SUBQUERY}, ${TOPIC_GRANT_IDS_SUBQUERY}
     FROM authors a WHERE a.username = $1 AND a.is_active = TRUE LIMIT 1`,
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
  const result = await ensureClient().query<(AuthorRowWithGrants & { expires_at: string })>(
    `SELECT a.*, s.expires_at, ${ADMIN_LAYER_IDS_SUBQUERY}, ${LAYER_GRANT_IDS_SUBQUERY}, ${TOPIC_GRANT_IDS_SUBQUERY}
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
  const candidateResult = await db.query<(AuthorRowWithGrants & {
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
            a.*,
            ${ADMIN_LAYER_IDS_SUBQUERY},
            ${LAYER_GRANT_IDS_SUBQUERY},
            ${TOPIC_GRANT_IDS_SUBQUERY}
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

const AUTHOR_GRANTS_SELECT = `
  SELECT a.*,
    ${ADMIN_LAYER_IDS_SUBQUERY},
    ${LAYER_GRANT_IDS_SUBQUERY},
    ${TOPIC_GRANT_IDS_SUBQUERY}
  FROM authors a
`;

export function mapAuthorRecord(row: AuthorRowWithGrants): AuthorRecord {
  return {
    id: row.id,
    username: row.username,
    isAdmin: row.is_admin,
    isActive: row.is_active,
    requiresPasswordChange: row.must_change_password,
    adminLayerIds: row.admin_layer_ids,
    layerGrantIds: row.layer_grant_ids,
    topicGrantIds: row.topic_grant_ids,
  };
}

export async function listAuthors(): Promise<AuthorRecord[]> {
  const result = await ensureClient().query<AuthorRowWithGrants>(
    `${AUTHOR_GRANTS_SELECT} ORDER BY a.username ASC`
  );
  return result.rows.map(mapAuthorRecord);
}

export async function getAuthorById(authorId: number): Promise<AuthorRecord | null> {
  const result = await ensureClient().query<AuthorRowWithGrants>(
    `${AUTHOR_GRANTS_SELECT} WHERE a.id = $1`,
    [authorId]
  );
  return result.rows[0] ? mapAuthorRecord(result.rows[0]) : null;
}

export async function createAuthor(options: {
  username: string;
  isAdmin?: boolean;
  adminLayerIds?: number[];
}): Promise<{ author: AuthorRecord; oneTimePassword: string }> {
  const db = ensureClient();
  const oneTimePassword = randomUUID().split('-')[0];
  const adminLayerIds = options.isAdmin ? (options.adminLayerIds ?? []) : [];
  await db.query('BEGIN');
  try {
    const result = await db.query<AuthorRow>(
      `INSERT INTO authors (username, password_hash, one_time_password_hash, must_change_password, is_active, is_admin)
       VALUES ($1, $2, $3, TRUE, TRUE, $4)
       RETURNING *`,
      [options.username, hashPassword(randomUUID()), hashPassword(oneTimePassword), options.isAdmin ?? false]
    );
    const author = result.rows[0];
    for (const layerId of adminLayerIds) {
      await db.query(
        `INSERT INTO author_admin_layers (author_id, layer_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [author.id, layerId]
      );
    }
    await db.query('COMMIT');
    return {
      author: mapAuthorRecord({ ...author, admin_layer_ids: adminLayerIds, layer_grant_ids: [], topic_grant_ids: [] }),
      oneTimePassword,
    };
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  }
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

// Haelt is_admin synchron mit dem tatsaechlichen Besitz von Admin-Layern, damit ein
// Autor durch Zuweisen/Entfernen von Admin-Layern automatisch zum Admin wird bzw.
// diesen Status wieder verliert, statt is_admin separat pflegen zu muessen.
export async function syncAdminFlag(authorId: number): Promise<void> {
  await ensureClient().query(
    `UPDATE authors SET is_admin = EXISTS(
       SELECT 1 FROM author_admin_layers WHERE author_id = $1
     ), updated_at = NOW() WHERE id = $1`,
    [authorId]
  );
}

// Deaktiviert den Autor automatisch, sobald keinerlei Rechte (Admin-Layer, Layer- oder
// Topic-Grants) mehr vorhanden sind, statt ihn aktiv aber voellig rechtelos zu belassen.
export async function maybeAutoDisableAuthor(authorId: number): Promise<void> {
  const result = await ensureClient().query<{ has_any: boolean }>(
    `SELECT EXISTS(
       SELECT 1 FROM author_admin_layers WHERE author_id = $1
       UNION SELECT 1 FROM author_layer_grants WHERE author_id = $1
       UNION SELECT 1 FROM author_topic_grants WHERE author_id = $1
     ) AS has_any`,
    [authorId]
  );
  if (!result.rows[0]?.has_any) {
    await setAuthorActive(authorId, false);
  }
}
