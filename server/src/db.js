const { Client } = require('pg');
const dotenv = require('dotenv');

dotenv.config();

let client;

function getDatabaseUrl() {
  return process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
}

async function connect() {
  const databaseUrl = getDatabaseUrl();
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is not set');
  }

  client = new Client({ connectionString: databaseUrl });
  await client.connect();
  await client.query(`
    CREATE TABLE IF NOT EXISTS events (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      start_date TIMESTAMPTZ NOT NULL,
      end_date TIMESTAMPTZ NOT NULL,
      location TEXT NOT NULL,
      dv TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
}

function mapEventRow(row) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    startDate: row.start_date,
    endDate: row.end_date,
    location: row.location,
    dv: row.dv,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function getEvents(dv) {
  const query = dv
    ? { text: 'SELECT * FROM events WHERE dv = $1 ORDER BY start_date ASC', values: [dv] }
    : { text: 'SELECT * FROM events ORDER BY start_date ASC', values: [] };
  const result = await client.query(query);
  return result.rows.map(mapEventRow);
}

async function createEvent(event) {
  const result = await client.query(
    `INSERT INTO events (title, description, start_date, end_date, location, dv)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [
      event.title,
      event.description,
      event.startDate,
      event.endDate,
      event.location,
      event.dv,
    ]
  );
  return mapEventRow(result.rows[0]);
}

async function clearEvents() {
  await client.query('TRUNCATE TABLE events RESTART IDENTITY CASCADE');
}

async function close() {
  await client.end();
}

module.exports = {
  connect,
  getEvents,
  createEvent,
  clearEvents,
  close,
  mapEventRow,
};
