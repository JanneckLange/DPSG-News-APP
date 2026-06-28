const { mapEventRow } = require('../src/db');

describe('Event DB mapping', () => {
  it('maps row fields to camelCase event object', () => {
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

    const event = mapEventRow(row);
    expect(event).toEqual({
      id: 1,
      title: 'Test',
      description: 'Beschreibung',
      startDate: '2026-01-01T10:00:00Z',
      endDate: '2026-01-01T12:00:00Z',
      location: 'Ort',
      dv: 'Köln',
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    });
  });
});
