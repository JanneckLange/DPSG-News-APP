import { randomUUID } from 'crypto';
import { hashPassword } from '../password';
import { BUNDESVERBAND_NAME, SEED_DVS } from '../seedLayers';
import { cleanupExpiredSessions } from './authors';
import { connectClient, ensureClient } from './client';
import { cleanupExpiredDrafts } from './drafts';

export async function connect(): Promise<void> {
  await connectClient();
  const client = ensureClient();
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
  await client.query(`ALTER TABLE authors ADD COLUMN IF NOT EXISTS created_by_author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL;`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS author_sessions (
      token TEXT PRIMARY KEY,
      author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
      expires_at TIMESTAMPTZ NOT NULL,
      refresh_token_hash TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`ALTER TABLE author_sessions ADD COLUMN IF NOT EXISTS refresh_token_hash TEXT;`);
  await client.query(`CREATE INDEX IF NOT EXISTS author_sessions_author_id_idx ON author_sessions(author_id);`);
  await client.query(`CREATE INDEX IF NOT EXISTS author_sessions_refresh_token_hash_idx ON author_sessions(refresh_token_hash);`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS author_refresh_sessions (
      token_hash TEXT PRIMARY KEY,
      author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
      family_id TEXT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      revoked_at TIMESTAMPTZ,
      replaced_by_token_hash TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`CREATE INDEX IF NOT EXISTS author_refresh_sessions_author_id_idx ON author_refresh_sessions(author_id);`);
  await client.query(`CREATE INDEX IF NOT EXISTS author_refresh_sessions_family_id_idx ON author_refresh_sessions(family_id);`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS layers (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      parent_id INTEGER REFERENCES layers(id) ON DELETE CASCADE,
      url TEXT,
      groups TEXT[],
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE NULLS NOT DISTINCT (name, parent_id)
    );
  `);
  await client.query(`CREATE INDEX IF NOT EXISTS layers_parent_id_idx ON layers(parent_id);`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS topics (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      layer_id INTEGER NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE NULLS NOT DISTINCT (layer_id, name)
    );
  `);
  await client.query(`CREATE INDEX IF NOT EXISTS topics_layer_id_idx ON topics(layer_id);`);
  await ensureSeedLayers();
  await client.query(`ALTER TABLE layers DROP COLUMN IF EXISTS groups;`);
  await client.query(`ALTER TABLE layers DROP COLUMN IF EXISTS url;`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS events (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      start_date TIMESTAMPTZ,
      end_date TIMESTAMPTZ,
      location_address TEXT,
      location_lat DOUBLE PRECISION,
      location_lng DOUBLE PRECISION,
      dv TEXT,
      topic TEXT,
      cta1_url TEXT,
      cta2_url TEXT,
      author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS topic TEXT;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS cta1_url TEXT;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS cta2_url TEXT;`);
  await client.query(`ALTER TABLE events DROP COLUMN IF EXISTS cta1_label;`);
  await client.query(`ALTER TABLE events DROP COLUMN IF EXISTS cta2_label;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS location_address TEXT;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION;`);
  await client.query(`ALTER TABLE events DROP COLUMN IF EXISTS location;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW();`);
  await client.query(`UPDATE events SET modified_at = created_at WHERE modified_at IS NULL;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT FALSE;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS publish_at TIMESTAMPTZ;`);
  await client.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS registration_deadline TIMESTAMPTZ;`);
  await client.query(`
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'events' AND column_name = 'is_draft'
      ) THEN
        DELETE FROM events WHERE is_draft = TRUE;
      END IF;
    END $$;
  `);
  await client.query(`ALTER TABLE events DROP COLUMN IF EXISTS is_draft;`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS drafts (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      start_date TIMESTAMPTZ,
      end_date TIMESTAMPTZ,
      location_address TEXT,
      location_lat DOUBLE PRECISION,
      location_lng DOUBLE PRECISION,
      dv TEXT,
      topic TEXT,
      cta1_url TEXT,
      cta2_url TEXT,
      author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS cta1_url TEXT;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS cta2_url TEXT;`);
  await client.query(`ALTER TABLE drafts DROP COLUMN IF EXISTS cta1_label;`);
  await client.query(`ALTER TABLE drafts DROP COLUMN IF EXISTS cta2_label;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS location_address TEXT;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION;`);
  await client.query(`ALTER TABLE drafts DROP COLUMN IF EXISTS location;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT FALSE;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS publish_at TIMESTAMPTZ;`);
  await client.query(`ALTER TABLE drafts ADD COLUMN IF NOT EXISTS registration_deadline TIMESTAMPTZ;`);
  await client.query(`CREATE INDEX IF NOT EXISTS drafts_author_id_idx ON drafts(author_id);`);
  await migrateDvToLayerId('events');
  await migrateDvToLayerId('drafts');
  // Die freie "Typ"-Klassifizierung (bundesverband/bezirk/stamm/dv/...) wird
  // nicht mehr gebraucht: jeder Layer ist gleichermassen waehlbar, der
  // Wurzel-Layer wird ausschliesslich strukturell ueber parent_id IS NULL
  // erkannt. migrateDvToLayerId() (oben) braucht dafuer noch die alte
  // type-Spalte, muss also vor diesem Drop laufen.
  await client.query(`ALTER TABLE layers DROP CONSTRAINT IF EXISTS layers_type_name_parent_id_key;`);
  await client.query(`ALTER TABLE layers DROP COLUMN IF EXISTS type;`);
  await client.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'layers_name_parent_id_key'
      ) THEN
        ALTER TABLE layers ADD CONSTRAINT layers_name_parent_id_key UNIQUE NULLS NOT DISTINCT (name, parent_id);
      END IF;
    END $$;
  `);
  await migrateTopicToTopicId('events');
  await migrateTopicToTopicId('drafts');
  await client.query(`
    CREATE TABLE IF NOT EXISTS event_updates (
      id SERIAL PRIMARY KEY,
      event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
      author_id INTEGER REFERENCES authors(id) ON DELETE SET NULL,
      message TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await client.query(`CREATE INDEX IF NOT EXISTS event_updates_event_id_idx ON event_updates(event_id);`);
  await cleanupExpiredSessions(true);
  await cleanupExpiredDrafts(true);
  await ensureBootstrapAuthor();
  await migrateAdminLayerId();
  await migrateAuthorAdminLayers();
  await migrateAuthorLayerGrants();
  await migrateAuthorTopicGrants();
}

async function ensureSeedLayers(): Promise<void> {
  const db = ensureClient();
  const existingRoot = await db.query<{ id: number }>(
    `SELECT id FROM layers WHERE name = $1 AND parent_id IS NULL LIMIT 1`,
    [BUNDESVERBAND_NAME]
  );
  const bundesverbandId = existingRoot.rows[0]
    ? existingRoot.rows[0].id
    : (
        await db.query<{ id: number }>(
          `INSERT INTO layers (name, parent_id) VALUES ($1, NULL) RETURNING id`,
          [BUNDESVERBAND_NAME]
        )
      ).rows[0].id;

  for (const dv of SEED_DVS) {
    const existingDv = await db.query<{ id: number }>(
      `SELECT id FROM layers WHERE name = $1 AND parent_id = $2 LIMIT 1`,
      [dv.name, bundesverbandId]
    );
    const dvId = existingDv.rows[0]
      ? existingDv.rows[0].id
      : (
          await db.query<{ id: number }>(
            `INSERT INTO layers (name, parent_id) VALUES ($1, $2) RETURNING id`,
            [dv.name, bundesverbandId]
          )
        ).rows[0].id;
    for (const group of dv.groups ?? []) {
      await db.query(
        `INSERT INTO topics (name, layer_id)
         VALUES ($1, $2)
         ON CONFLICT (layer_id, name) DO NOTHING`,
        [group, dvId]
      );
    }
  }
}

async function migrateAdminLayerId(): Promise<void> {
  const db = ensureClient();
  await db.query(`ALTER TABLE authors ADD COLUMN IF NOT EXISTS admin_layer_id INTEGER REFERENCES layers(id);`);
  await db.query(
    `UPDATE authors
     SET admin_layer_id = (SELECT id FROM layers WHERE parent_id IS NULL LIMIT 1)
     WHERE is_admin = TRUE AND admin_layer_id IS NULL`
  );
}

// Ersetzt die alte Einzel-Layer-Zuordnung (admin_layer_id) durch eine
// Viele-zu-viele-Zuordnung: ein Admin kann mehreren Layern zugeordnet sein,
// jeweils mit "Layer und darunter"-Vererbung bei der Autorisierung. Die
// admin_layer_id-Spalte bleibt unangetastet (nicht-destruktiv) und wird nur
// einmalig fuer das Backfill gelesen; neuer Code schreibt sie nicht mehr.
async function migrateAuthorAdminLayers(): Promise<void> {
  const db = ensureClient();
  await db.query(`
    CREATE TABLE IF NOT EXISTS author_admin_layers (
      author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
      layer_id INTEGER NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (author_id, layer_id)
    );
  `);
  await db.query(`CREATE INDEX IF NOT EXISTS author_admin_layers_layer_id_idx ON author_admin_layers(layer_id);`);
  await db.query(`
    INSERT INTO author_admin_layers (author_id, layer_id)
    SELECT id, admin_layer_id FROM authors
    WHERE is_admin = TRUE AND admin_layer_id IS NOT NULL
    ON CONFLICT (author_id, layer_id) DO NOTHING
  `);
}

// Issue #15: flache (nicht vererbte) Autoren-Rechtezuordnung fuer
// Nicht-Admin-Autoren. Anders als bei author_admin_layers gilt hier
// ausschliesslich der exakt zugeordnete Layer/Topic, keine Subtree-Vererbung.
async function migrateAuthorLayerGrants(): Promise<void> {
  const db = ensureClient();
  await db.query(`
    CREATE TABLE IF NOT EXISTS author_layer_grants (
      author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
      layer_id INTEGER NOT NULL REFERENCES layers(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (author_id, layer_id)
    );
  `);
  await db.query(`CREATE INDEX IF NOT EXISTS author_layer_grants_layer_id_idx ON author_layer_grants(layer_id);`);
}

async function migrateAuthorTopicGrants(): Promise<void> {
  const db = ensureClient();
  await db.query(`
    CREATE TABLE IF NOT EXISTS author_topic_grants (
      author_id INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
      topic_id INTEGER NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (author_id, topic_id)
    );
  `);
  await db.query(`CREATE INDEX IF NOT EXISTS author_topic_grants_topic_id_idx ON author_topic_grants(topic_id);`);
}

async function migrateTopicToTopicId(table: 'events' | 'drafts'): Promise<void> {
  const db = ensureClient();
  await db.query(`ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS topic_id INTEGER REFERENCES topics(id);`);

  const topicColumnExists = await db.query<{ exists: boolean }>(
    `SELECT EXISTS (
       SELECT 1 FROM information_schema.columns
       WHERE table_name = $1 AND column_name = 'topic'
     ) AS exists`,
    [table]
  );
  if (!topicColumnExists.rows[0]?.exists) {
    return;
  }

  await db.query(
    `UPDATE ${table} t
     SET topic_id = tp.id
     FROM topics tp
     WHERE t.topic_id IS NULL
       AND t.layer_id = tp.layer_id
       AND tp.name = t.topic`
  );
  const unmatched = await db.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM ${table} WHERE topic_id IS NULL AND topic IS NOT NULL`
  );
  const unmatchedCount = Number(unmatched.rows[0]?.count ?? '0');
  if (unmatchedCount > 0) {
    console.warn(`[migrateTopicToTopicId] ${unmatchedCount} row(s) in "${table}" could not be matched from topic (free text) to a topic_id and need manual fixup.`);
  }
  await db.query(`ALTER TABLE ${table} DROP COLUMN IF EXISTS topic;`);
}

async function migrateDvToLayerId(table: 'events' | 'drafts'): Promise<void> {
  const db = ensureClient();
  await db.query(`ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS layer_id INTEGER REFERENCES layers(id);`);

  const dvColumnExists = await db.query<{ exists: boolean }>(
    `SELECT EXISTS (
       SELECT 1 FROM information_schema.columns
       WHERE table_name = $1 AND column_name = 'dv'
     ) AS exists`,
    [table]
  );
  if (!dvColumnExists.rows[0]?.exists) {
    return;
  }

  await db.query(
    `UPDATE ${table} t
     SET layer_id = l.id
     FROM layers l
     WHERE t.layer_id IS NULL
       AND l.type = 'dv'
       AND l.name = t.dv`
  );
  const unmatched = await db.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM ${table} WHERE layer_id IS NULL AND dv IS NOT NULL`
  );
  const unmatchedCount = Number(unmatched.rows[0]?.count ?? '0');
  if (unmatchedCount > 0) {
    console.warn(`[migrateDvToLayerId] ${unmatchedCount} row(s) in "${table}" could not be matched from dv (free text) to a layer_id and need manual fixup.`);
  }
  await db.query(`ALTER TABLE ${table} DROP COLUMN IF EXISTS dv;`);
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
     DO NOTHING`,
    [bootstrapUsername, hashPassword(randomUUID()), hashPassword(bootstrapOneTimePassword)]
  );
}
