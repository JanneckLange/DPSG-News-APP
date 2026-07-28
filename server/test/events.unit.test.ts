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
      layer_id: 7,
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
      layerId: 7,
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

  it('maps isPublic, publishAt and registrationDeadline', () => {
    const row = {
      id: 1,
      title: 'Test',
      description: 'Beschreibung',
      start_date: '2026-01-01T10:00:00Z',
      end_date: '2026-01-01T12:00:00Z',
      location: 'Ort',
      is_public: true,
      publish_at: '2026-02-01T00:00:00Z',
      registration_deadline: '2026-01-15T00:00:00Z',
      author_id: 42,
      created_at: '2026-01-01T00:00:00Z',
      modified_at: '2026-01-02T00:00:00Z',
    };

    const event = mapEventRow(row);
    expect(event.isPublic).toBe(true);
    expect(event.publishAt).toBe('2026-02-01T00:00:00Z');
    expect(event.registrationDeadline).toBe('2026-01-15T00:00:00Z');
  });

  it('defaults isPublic to false and omits publishAt/registrationDeadline when absent', () => {
    const row = {
      id: 1,
      title: 'Test',
      description: 'Beschreibung',
      start_date: '2026-01-01T10:00:00Z',
      end_date: '2026-01-01T12:00:00Z',
      location: 'Ort',
      is_public: false,
      author_id: 42,
      created_at: '2026-01-01T00:00:00Z',
      modified_at: '2026-01-02T00:00:00Z',
    };

    const event = mapEventRow(row);
    expect(event.isPublic).toBe(false);
    expect(event.publishAt).toBeUndefined();
    expect(event.registrationDeadline).toBeUndefined();
  });
});
