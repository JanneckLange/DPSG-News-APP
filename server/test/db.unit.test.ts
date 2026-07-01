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

describe('Database helper', () => {
  beforeEach(async () => {
    jest.clearAllMocks();
    process.env.TEST_DATABASE_URL = 'postgres://dpsg:dpsg@localhost:5433/dpsg_news_test';
    mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });
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
    expect(mockQuery).toHaveBeenCalledTimes(2);
    expect(mockQuery.mock.calls[0][0]).toEqual(
      expect.stringContaining('CREATE TABLE IF NOT EXISTS events')
    );
    expect(mockQuery.mock.calls[0][1]).toBeUndefined();
    expect(mockQuery.mock.calls[1][0]).toEqual(
      expect.stringContaining('ALTER TABLE events ADD COLUMN IF NOT EXISTS topic TEXT')
    );
    expect(mockQuery.mock.calls[1][1]).toBeUndefined();
  });

  it('throws when DATABASE_URL is not set', async () => {
    delete process.env.TEST_DATABASE_URL;
    delete process.env.DATABASE_URL;

    await expect(connect()).rejects.toThrow('DATABASE_URL is not set');
  });

  it('returns events with and without dv filter', async () => {
    await connect();

    const row = {
      id: 1,
      title: 'Test',
      description: 'Beschreibung',
      start_date: '2026-01-01T10:00:00Z',
      end_date: '2026-01-01T12:00:00Z',
      location: 'Ort',
      dv: 'Köln',
      created_at: '2026-01-01T00:00:00Z',
      updated_at: '2026-01-01T00:00:00Z',
    };

    mockQuery.mockResolvedValueOnce({ rows: [row], rowCount: 1 });
    let events = await getEvents();
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ dv: 'Köln' });
    expect(mockQuery).toHaveBeenLastCalledWith({
      text: 'SELECT * FROM events ORDER BY start_date ASC',
      values: [],
    });

    mockQuery.mockResolvedValueOnce({ rows: [row], rowCount: 1 });
    events = await getEvents('Köln');
    expect(events[0]).toMatchObject({ dv: 'Köln' });
    expect(mockQuery).toHaveBeenLastCalledWith({
      text: 'SELECT * FROM events WHERE dv = $1 ORDER BY start_date ASC',
      values: ['Köln'],
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
      dv: 'Köln',
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
      dv: 'Köln',
    });

    expect(created.id).toBe(1);
    expect(created).toMatchObject({ title: 'Created', dv: 'Köln' });

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
