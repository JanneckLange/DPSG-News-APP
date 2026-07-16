import { DV_TREE } from './dvTree';

export const MAX_TITLE_LENGTH = 100;
export const MAX_LABEL_LENGTH = 20;
export const MAX_URL_LENGTH = 300;
export const MAX_LOCATION_LENGTH = 50;
export const MAX_LONG_TEXT_LENGTH = 1000; // description, update message

export type FieldValidation = { valid: true } | { valid: false; error: string };

const VALID_RESULT: FieldValidation = { valid: true };

function invalid(error: string): FieldValidation {
  return { valid: false, error };
}

function validateOptionalText(fieldName: string, value: unknown, maxLength: number): FieldValidation {
  if (value === undefined || value === null) {
    return VALID_RESULT;
  }
  if (typeof value !== 'string') {
    return invalid(`Field '${fieldName}' must be a string`);
  }
  if (value.length > maxLength) {
    return invalid(`Field '${fieldName}' must not exceed ${maxLength} characters`);
  }
  return VALID_RESULT;
}

function isHttpOrHttpsUrl(raw: string): boolean {
  try {
    return new URL(raw).protocol === 'http:' || new URL(raw).protocol === 'https:';
  } catch {
    try {
      return new URL(`https://${raw}`).hostname.length > 0;
    } catch {
      return false;
    }
  }
}

function validateOptionalCtaUrl(fieldName: string, value: unknown): FieldValidation {
  if (value === undefined || value === null) {
    return VALID_RESULT;
  }
  if (typeof value !== 'string') {
    return invalid(`Field '${fieldName}' must be a string`);
  }
  if (value.length === 0) {
    return VALID_RESULT;
  }
  if (value.length > MAX_URL_LENGTH) {
    return invalid(`Field '${fieldName}' must not exceed ${MAX_URL_LENGTH} characters`);
  }
  if (!isHttpOrHttpsUrl(value)) {
    return invalid(`Field '${fieldName}' must be a valid http or https URL`);
  }
  return VALID_RESULT;
}

function validateDv(value: unknown): FieldValidation {
  if (value === undefined || value === null) {
    return VALID_RESULT;
  }
  if (typeof value !== 'string') {
    return invalid("Field 'dv' must be a string");
  }
  if (value.length === 0) {
    return VALID_RESULT;
  }
  const known = DV_TREE.dvs.some((entry) => entry.name === value);
  if (!known) {
    return invalid("Field 'dv' must be a known DV");
  }
  return VALID_RESULT;
}

function validateTopic(dv: unknown, value: unknown): FieldValidation {
  if (value === undefined || value === null) {
    return VALID_RESULT;
  }
  if (typeof value !== 'string') {
    return invalid("Field 'topic' must be a string");
  }
  if (value.length === 0) {
    return VALID_RESULT;
  }
  if (typeof dv !== 'string') {
    return invalid("Field 'topic' requires a known 'dv'");
  }
  const entry = DV_TREE.dvs.find((candidate) => candidate.name === dv);
  if (!entry || !entry.groups || !entry.groups.includes(value)) {
    return invalid("Field 'topic' must be a known topic for the selected dv");
  }
  return VALID_RESULT;
}

export function validateEventTextFields(body: Record<string, unknown>): FieldValidation {
  const checks: FieldValidation[] = [
    validateOptionalText('title', body.title, MAX_TITLE_LENGTH),
    validateOptionalText('description', body.description, MAX_LONG_TEXT_LENGTH),
    validateOptionalText('location', body.location, MAX_LOCATION_LENGTH),
    validateDv(body.dv),
    validateTopic(body.dv, body.topic),
    validateOptionalText('cta1Label', body.cta1Label, MAX_LABEL_LENGTH),
    validateOptionalCtaUrl('cta1Url', body.cta1Url),
    validateOptionalText('cta2Label', body.cta2Label, MAX_LABEL_LENGTH),
    validateOptionalCtaUrl('cta2Url', body.cta2Url),
  ];
  for (const check of checks) {
    if (!check.valid) {
      return check;
    }
  }
  return VALID_RESULT;
}

export function validateMessageField(value: unknown): FieldValidation {
  return validateOptionalText('message', value, MAX_LONG_TEXT_LENGTH);
}
