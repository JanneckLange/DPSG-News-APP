import { diffEventFields, mapEventHistoryRow, Event } from '../src/db';

function makeEvent(overrides: Partial<Event> = {}): Event {
  return {
    id: 1,
    title: 'Titel',
    description: 'Beschreibung',
    startDate: '2026-01-01T10:00:00Z',
    endDate: '2026-01-01T12:00:00Z',
    layerId: 7,
    isPublic: false,
    authorId: 42,
    createdAt: '2026-01-01T00:00:00Z',
    modifiedAt: '2026-01-02T00:00:00Z',
    ...overrides,
  };
}

describe('diffEventFields', () => {
  it('returns no changes for identical events', () => {
    const before = makeEvent();
    const after = makeEvent();
    expect(diffEventFields(before, after)).toEqual([]);
  });

  it('detects a changed text field', () => {
    const before = makeEvent({ title: 'Alter Titel' });
    const after = makeEvent({ title: 'Neuer Titel' });
    expect(diffEventFields(before, after)).toEqual([
      { field: 'title', oldValue: 'Alter Titel', newValue: 'Neuer Titel' },
    ]);
  });

  it('detects multiple changed fields in one diff', () => {
    const before = makeEvent({ title: 'Alt', locationAddress: 'Köln' });
    const after = makeEvent({ title: 'Neu', locationAddress: 'Berlin' });
    const changes = diffEventFields(before, after);
    expect(changes).toHaveLength(2);
    expect(changes).toEqual(
      expect.arrayContaining([
        { field: 'title', oldValue: 'Alt', newValue: 'Neu' },
        { field: 'locationAddress', oldValue: 'Köln', newValue: 'Berlin' },
      ])
    );
  });

  it('treats undefined and null as equal (no change)', () => {
    const before = makeEvent({ locationAddress: undefined });
    const after = makeEvent({ locationAddress: undefined });
    expect(diffEventFields(before, after)).toEqual([]);
  });

  it('ignores untracked fields like id, authorId, createdAt, modifiedAt', () => {
    const before = makeEvent({ id: 1, authorId: 42, createdAt: 'a', modifiedAt: 'b' });
    const after = makeEvent({ id: 2, authorId: 99, createdAt: 'c', modifiedAt: 'd' });
    expect(diffEventFields(before, after)).toEqual([]);
  });

  it('detects boolean field changes', () => {
    const before = makeEvent({ isPublic: false });
    const after = makeEvent({ isPublic: true });
    expect(diffEventFields(before, after)).toEqual([
      { field: 'isPublic', oldValue: false, newValue: true },
    ]);
  });
});

describe('mapEventHistoryRow', () => {
  it('maps snake_case row to camelCase entry', () => {
    const row = {
      id: 5,
      event_id: 10,
      author_id: 42,
      changes: [{ field: 'title', oldValue: 'Alt', newValue: 'Neu' }],
      created_at: '2026-01-01T00:00:00Z',
      author_username: 'max.mustermann',
    };
    expect(mapEventHistoryRow(row)).toEqual({
      id: 5,
      eventId: 10,
      authorId: 42,
      authorUsername: 'max.mustermann',
      changes: [{ field: 'title', oldValue: 'Alt', newValue: 'Neu' }],
      createdAt: '2026-01-01T00:00:00Z',
    });
  });
});
