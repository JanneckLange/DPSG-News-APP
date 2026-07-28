import dotenv from 'dotenv';
dotenv.config();

const mockQuery = jest.fn();
const mockConnect = jest.fn();
const mockEnd = jest.fn();
const mockClientConstructor = jest.fn();

jest.mock('pg', () => ({
  Client: jest.fn().mockImplementation(({ connectionString }: { connectionString: string }) => {
    mockClientConstructor(connectionString);
    return {
      connect: mockConnect,
      query: mockQuery,
      end: mockEnd,
    };
  }),
}));

import { connect, close, getEvents, createEvent, deleteEventById, deleteAllEvents } from '../src/db';
import { BUNDESVERBAND_NAME } from '../src/seedLayers';

describe('Database helper', () => {
  beforeEach(async () => {
    jest.clearAllMocks();
    process.env.TEST_DATABASE_URL = 'postgres://dpsg:dpsg@localhost:5433/dpsg_news_test';
    // Default: queries that RETURNING an id (e.g. the layer seed inserts) resolve with a row so
    // connect() can complete; everything else resolves empty unless overridden per-test.
    mockQuery.mockImplementation((query: unknown) => {
      const text = typeof query === 'string' ? query : (query as { text?: string })?.text ?? '';
      if (text.includes('RETURNING id')) {
        return Promise.resolve({ rows: [{ id: 1 }], rowCount: 1 });
      }
      return Promise.resolve({ rows: [], rowCount: 0 });
    });
  });

  afterEach(async () => {
    await close();
  });

  it('connects to the database and initializes the events table', async () => {
    await connect();

    expect(mockClientConstructor).toHaveBeenCalledWith(
      'postgres://dpsg:dpsg@localhost:5433/dpsg_news_test'
    );
    expect(mockConnect).toHaveBeenCalled();
    expect(mockQuery.mock.calls.some((call) => String(call[0]).includes('CREATE TABLE IF NOT EXISTS events'))).toBe(true);
    expect(mockQuery.mock.calls.some((call) => String(call[0]).includes('CREATE TABLE IF NOT EXISTS author_refresh_sessions'))).toBe(true);
  });

  it('creates the layers table and seeds Bundesverband + Diözesanverbände', async () => {
    await connect();

    expect(mockQuery.mock.calls.some((call) => String(call[0]).includes('CREATE TABLE IF NOT EXISTS layers'))).toBe(true);
    const layerInserts = mockQuery.mock.calls.filter(
      (call) => String(call[0]).includes('INSERT INTO layers') && String(call[0]).includes('RETURNING id')
    );

    const bundesverbandInsert = layerInserts.find(
      (call) => Array.isArray(call[1]) && call[1].length === 1
    );
    expect(bundesverbandInsert).toBeDefined();
    expect(bundesverbandInsert?.[1]).toEqual([BUNDESVERBAND_NAME]);

    const dvInserts = layerInserts.filter(
      (call) => Array.isArray(call[1]) && call[1].length === 2
    );
    expect(dvInserts).toHaveLength(25);
  });

  it('migrates events.dv and drafts.dv to layer_id, then drops the dv column', async () => {
    await connect();

    expect(mockQuery.mock.calls.some((call) => String(call[0]).includes('ALTER TABLE events ADD COLUMN IF NOT EXISTS layer_id'))).toBe(true);
    expect(mockQuery.mock.calls.some((call) => String(call[0]).includes('ALTER TABLE drafts ADD COLUMN IF NOT EXISTS layer_id'))).toBe(true);
  });

  it('throws when DATABASE_URL is not set', async () => {
    delete process.env.TEST_DATABASE_URL;
    delete process.env.DATABASE_URL;

    await expect(connect()).rejects.toThrow('DATABASE_URL is not set');
  });

  it('returns events with and without layerId filter', async () => {
    await connect();

    const row = {
      id: 1,
      title: 'Test',
      description: 'Beschreibung',
      start_date: '2026-01-01T10:00:00Z',
      end_date: '2026-01-01T12:00:00Z',
      location: 'Ort',
      layer_id: 7,
      is_public: false,
      publish_at: null,
      created_at: '2026-01-01T00:00:00Z',
      updated_at: '2026-01-01T00:00:00Z',
    };

    mockQuery.mockResolvedValueOnce({ rows: [row], rowCount: 1 });
    let events = await getEvents();
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ layerId: 7, isPublic: false });
    expect(mockQuery).toHaveBeenLastCalledWith({
      text: 'SELECT e.*, (SELECT MAX(eu.created_at) FROM event_updates eu WHERE eu.event_id = e.id) AS last_update_at FROM events e WHERE (e.publish_at IS NULL OR e.publish_at <= NOW()) ORDER BY e.start_date ASC',
      values: [],
    });

    mockQuery.mockResolvedValueOnce({ rows: [row], rowCount: 1 });
    events = await getEvents(7);
    expect(events[0]).toMatchObject({ layerId: 7 });
    expect(mockQuery).toHaveBeenLastCalledWith({
      text: 'SELECT e.*, (SELECT MAX(eu.created_at) FROM event_updates eu WHERE eu.event_id = e.id) AS last_update_at FROM events e WHERE e.layer_id = $1 AND (e.publish_at IS NULL OR e.publish_at <= NOW()) ORDER BY e.start_date ASC',
      values: [7],
    });

    mockQuery.mockResolvedValueOnce({ rows: [row], rowCount: 1 });
    events = await getEvents(undefined, { includeUnpublished: true });
    expect(events[0]).toMatchObject({ layerId: 7 });
    expect(mockQuery).toHaveBeenLastCalledWith({
      text: 'SELECT e.*, (SELECT MAX(eu.created_at) FROM event_updates eu WHERE eu.event_id = e.id) AS last_update_at FROM events e ORDER BY e.start_date ASC',
      values: [],
    });
  });

  it('creates an event and deletes events by id and all', async () => {
    await connect();

    const insertRow = {
      id: 1,
      title: 'Created',
      description: 'Beschreibung',
      start_date: '2026-01-01T10:00:00Z',
      end_date: '2026-01-01T12:00:00Z',
      location: 'Ort',
      layer_id: 7,
      created_at: '2026-01-01T00:00:00Z',
      updated_at: '2026-01-01T00:00:00Z',
    };

    mockQuery.mockResolvedValueOnce({ rows: [insertRow], rowCount: 1 });
    const created = await createEvent({
      title: 'Created',
      description: 'Beschreibung',
      startDate: '2026-01-01T10:00:00Z',
      endDate: '2026-01-01T12:00:00Z',
      location: 'Ort',
      layerId: 7,
    });

    expect(created.id).toBe(1);
    expect(created).toMatchObject({ title: 'Created', layerId: 7 });

    mockQuery.mockResolvedValueOnce({ rowCount: 0, rows: [] });
    expect(await deleteEventById(1)).toBe(false);

    mockQuery.mockResolvedValueOnce({ rowCount: 1, rows: [] });
    expect(await deleteEventById(1)).toBe(true);

    mockQuery.mockResolvedValueOnce({ rowCount: 2, rows: [] });
    expect(await deleteAllEvents()).toBe(2);
  });

  it('closes the client without error when not connected', async () => {
    await close();
    expect(mockEnd).not.toHaveBeenCalled();
  });
});
