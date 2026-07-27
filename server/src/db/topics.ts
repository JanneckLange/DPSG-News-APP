import { maybeAutoDisableAuthor } from './authors';
import { ensureClient } from './client';
import { QueryConfig } from 'pg';

type TopicRow = {
  id: number;
  name: string;
  layer_id: number;
  created_at: string;
  updated_at: string;
};

export type Topic = {
  id: number;
  name: string;
  layerId: number;
  createdAt: string;
  updatedAt: string;
};

export type TopicInput = {
  name: string;
  layerId: number;
};

export function mapTopicRow(row: TopicRow): Topic {
  return {
    id: row.id,
    name: row.name,
    layerId: row.layer_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function getAuthorTopicGrantIds(authorId: number): Promise<number[]> {
  const result = await ensureClient().query<{ topic_id: number }>(
    'SELECT topic_id FROM author_topic_grants WHERE author_id = $1 ORDER BY topic_id ASC',
    [authorId]
  );
  return result.rows.map((row) => row.topic_id);
}

export async function addAuthorTopicGrant(authorId: number, topicId: number): Promise<void> {
  await ensureClient().query(
    'INSERT INTO author_topic_grants (author_id, topic_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
    [authorId, topicId]
  );
}

export async function removeAuthorTopicGrant(authorId: number, topicId: number): Promise<void> {
  await ensureClient().query(
    'DELETE FROM author_topic_grants WHERE author_id = $1 AND topic_id = $2',
    [authorId, topicId]
  );
  await maybeAutoDisableAuthor(authorId);
}

export async function getTopics(layerId?: number): Promise<Topic[]> {
  const query: QueryConfig = layerId
    ? { text: 'SELECT * FROM topics WHERE layer_id = $1 ORDER BY name ASC', values: [layerId] }
    : { text: 'SELECT * FROM topics ORDER BY name ASC', values: [] };
  const result = await ensureClient().query<TopicRow>(query);
  return result.rows.map(mapTopicRow);
}

export async function getTopicById(id: number): Promise<Topic | null> {
  const result = await ensureClient().query<TopicRow>('SELECT * FROM topics WHERE id = $1', [id]);
  return result.rows[0] ? mapTopicRow(result.rows[0]) : null;
}

export async function createTopic(input: TopicInput): Promise<Topic> {
  const result = await ensureClient().query<TopicRow>(
    `INSERT INTO topics (name, layer_id)
     VALUES ($1, $2)
     RETURNING *`,
    [input.name, input.layerId]
  );
  return mapTopicRow(result.rows[0]);
}

export async function updateTopic(id: number, name: string): Promise<Topic | null> {
  const result = await ensureClient().query<TopicRow>(
    `UPDATE topics
     SET name = $1,
         updated_at = NOW()
     WHERE id = $2
     RETURNING *`,
    [name, id]
  );
  return result.rows[0] ? mapTopicRow(result.rows[0]) : null;
}

export type DeleteTopicResult = 'deleted' | 'not_found' | 'in_use';

export async function deleteTopic(id: number): Promise<DeleteTopicResult> {
  const db = ensureClient();
  const existing = await db.query('SELECT 1 FROM topics WHERE id = $1', [id]);
  if (!existing.rows[0]) {
    return 'not_found';
  }

  const referencedByEvents = await db.query('SELECT 1 FROM events WHERE topic_id = $1 LIMIT 1', [id]);
  const referencedByDrafts = await db.query('SELECT 1 FROM drafts WHERE topic_id = $1 LIMIT 1', [id]);
  if (referencedByEvents.rows[0] || referencedByDrafts.rows[0]) {
    return 'in_use';
  }

  await db.query('DELETE FROM topics WHERE id = $1', [id]);
  return 'deleted';
}
