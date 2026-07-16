import { mapEventRow } from '../src/db';

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
      author_id: 42,
      created_at: '2026-01-01T00:00:00Z',
      modified_at: '2026-01-02T00:00:00Z',
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
      authorId: 42,
      createdAt: '2026-01-01T00:00:00Z',
      modifiedAt: '2026-01-02T00:00:00Z',
    });
  });

  it('maps CTA button fields when present', () => {
    const row = {
      id: 1,
      title: 'Test',
      description: 'Beschreibung',
      start_date: '2026-01-01T10:00:00Z',
      end_date: '2026-01-01T12:00:00Z',
      location: 'Ort',
      dv: 'Köln',
      cta1_label: 'Anmelden',
      cta1_url: 'https://example.org/anmeldung',
      cta2_label: 'Mehr Infos',
      cta2_url: 'https://example.org/infos',
      author_id: 42,
      created_at: '2026-01-01T00:00:00Z',
      modified_at: '2026-01-02T00:00:00Z',
    };

    const event = mapEventRow(row);
    expect(event.cta1Label).toBe('Anmelden');
    expect(event.cta1Url).toBe('https://example.org/anmeldung');
    expect(event.cta2Label).toBe('Mehr Infos');
    expect(event.cta2Url).toBe('https://example.org/infos');
  });
});
