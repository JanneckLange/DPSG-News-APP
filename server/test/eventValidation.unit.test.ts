import {
  MAX_LABEL_LENGTH,
  MAX_LOCATION_LENGTH,
  MAX_LONG_TEXT_LENGTH,
  MAX_TITLE_LENGTH,
  MAX_URL_LENGTH,
  validateEventTextFields,
  validateMessageField,
} from '../src/eventValidation';

describe('validateEventTextFields', () => {
  it('accepts a fully valid event body', () => {
    const result = validateEventTextFields({
      title: 'Sommerlager',
      description: 'Ein tolles Lager',
      location: 'Zeltplatz',
      topicId: undefined,
      cta1Label: 'Anmelden',
      cta1Url: 'https://example.org/anmeldung',
    });
    expect(result.valid).toBe(true);
  });

  it('accepts a body with no optional fields set', () => {
    expect(validateEventTextFields({ title: 'Test' }).valid).toBe(true);
  });

  it('rejects a title that exceeds the max length', () => {
    const result = validateEventTextFields({ title: 'x'.repeat(MAX_TITLE_LENGTH + 1) });
    expect(result).toEqual({ valid: false, error: expect.stringContaining('title') });
  });

  it('rejects a non-string field instead of crashing', () => {
    const result = validateEventTextFields({ title: 'Test', location: 12345 as unknown as string });
    expect(result).toEqual({ valid: false, error: expect.stringContaining('location') });
  });

  it('rejects an oversized location', () => {
    const result = validateEventTextFields({ title: 'Test', location: 'x'.repeat(MAX_LOCATION_LENGTH + 1) });
    expect(result.valid).toBe(false);
  });

  it('rejects an oversized CTA label', () => {
    const result = validateEventTextFields({ title: 'Test', cta1Label: 'x'.repeat(MAX_LABEL_LENGTH + 1) });
    expect(result.valid).toBe(false);
  });

  it('rejects a CTA URL that exceeds the max length', () => {
    const longUrl = `https://example.org/${'a'.repeat(MAX_URL_LENGTH)}`;
    const result = validateEventTextFields({ title: 'Test', cta1Url: longUrl });
    expect(result.valid).toBe(false);
  });

  it('rejects a javascript: scheme CTA URL', () => {
    const result = validateEventTextFields({ title: 'Test', cta1Url: 'javascript:alert(1)' });
    expect(result).toEqual({ valid: false, error: expect.stringContaining('cta1Url') });
  });

  it('rejects a file: scheme CTA URL', () => {
    const result = validateEventTextFields({ title: 'Test', cta2Url: 'file:///etc/passwd' });
    expect(result.valid).toBe(false);
  });

  it('accepts a CTA URL without an explicit scheme (treated as https)', () => {
    const result = validateEventTextFields({ title: 'Test', cta1Url: 'www.google.com' });
    expect(result.valid).toBe(true);
  });

  it('rejects a topicId that does not belong to the selected layer', () => {
    const result = validateEventTextFields(
      { title: 'Test', topicId: 999 },
      [1, 2],
    );
    expect(result).toEqual({ valid: false, error: expect.stringContaining('topicId') });
  });

  it('accepts a topicId that belongs to the selected layer', () => {
    const result = validateEventTextFields(
      { title: 'Test', topicId: 2 },
      [1, 2],
    );
    expect(result.valid).toBe(true);
  });

  it('rejects a topicId when the selected layer has no known topics', () => {
    const result = validateEventTextFields({ title: 'Test', topicId: 2 });
    expect(result.valid).toBe(false);
  });

  it('rejects a non-numeric topicId instead of crashing', () => {
    const result = validateEventTextFields({ title: 'Test', topicId: 'Rover' as unknown as number }, [1, 2]);
    expect(result).toEqual({ valid: false, error: expect.stringContaining('topicId') });
  });

  it('rejects a description that exceeds the max length', () => {
    const result = validateEventTextFields({ title: 'Test', description: 'x'.repeat(MAX_LONG_TEXT_LENGTH + 1) });
    expect(result.valid).toBe(false);
  });
});

describe('validateMessageField', () => {
  it('accepts a normal message', () => {
    expect(validateMessageField('Kurzes Update').valid).toBe(true);
  });

  it('accepts an absent message (required-check happens separately)', () => {
    expect(validateMessageField(undefined).valid).toBe(true);
  });

  it('rejects a non-string message instead of crashing on .trim()', () => {
    const result = validateMessageField(12345 as unknown as string);
    expect(result.valid).toBe(false);
  });

  it('rejects an oversized message', () => {
    const result = validateMessageField('x'.repeat(MAX_LONG_TEXT_LENGTH + 1));
    expect(result.valid).toBe(false);
  });
});
