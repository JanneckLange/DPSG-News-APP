export const MAX_TITLE_LENGTH = 100;
export const MAX_LABEL_LENGTH = 20;
export const MAX_URL_LENGTH = 300;
export const MAX_LOCATION_ADDRESS_LENGTH = 255;
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

function validateOptionalBoolean(fieldName: string, value: unknown): FieldValidation {
  if (value === undefined || value === null) {
    return VALID_RESULT;
  }
  if (typeof value !== 'boolean') {
    return invalid(`Field '${fieldName}' must be a boolean`);
  }
  return VALID_RESULT;
}

function validateOptionalDate(fieldName: string, value: unknown): FieldValidation {
  if (value === undefined || value === null) {
    return VALID_RESULT;
  }
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
    return invalid(`Field '${fieldName}' must be a valid date`);
  }
  return VALID_RESULT;
}

function validateOptionalLatLng(lat: unknown, lng: unknown): FieldValidation {
  const latMissing = lat === undefined || lat === null;
  const lngMissing = lng === undefined || lng === null;
  if (latMissing !== lngMissing) {
    return invalid("Fields 'locationLat' and 'locationLng' must be provided together");
  }
  if (latMissing) {
    return VALID_RESULT;
  }
  if (typeof lat !== 'number' || Number.isNaN(lat) || lat < -90 || lat > 90) {
    return invalid("Field 'locationLat' must be a number between -90 and 90");
  }
  if (typeof lng !== 'number' || Number.isNaN(lng) || lng < -180 || lng > 180) {
    return invalid("Field 'locationLng' must be a number between -180 and 180");
  }
  return VALID_RESULT;
}

function validateTopic(validTopicIds: number[] | null | undefined, value: unknown): FieldValidation {
  if (value === undefined || value === null) {
    return VALID_RESULT;
  }
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    return invalid("Field 'topicId' must be a number");
  }
  if (!validTopicIds || !validTopicIds.includes(value)) {
    return invalid("Field 'topicId' must be a known topic for the selected layer");
  }
  return VALID_RESULT;
}

export function validateEventTextFields(body: Record<string, unknown>, validTopicIds?: number[] | null): FieldValidation {
  const checks: FieldValidation[] = [
    validateOptionalText('title', body.title, MAX_TITLE_LENGTH),
    validateOptionalText('description', body.description, MAX_LONG_TEXT_LENGTH),
    validateOptionalText('locationAddress', body.locationAddress, MAX_LOCATION_ADDRESS_LENGTH),
    validateOptionalLatLng(body.locationLat, body.locationLng),
    validateTopic(validTopicIds, body.topicId),
    validateOptionalText('cta1Label', body.cta1Label, MAX_LABEL_LENGTH),
    validateOptionalCtaUrl('cta1Url', body.cta1Url),
    validateOptionalText('cta2Label', body.cta2Label, MAX_LABEL_LENGTH),
    validateOptionalCtaUrl('cta2Url', body.cta2Url),
    validateOptionalBoolean('isPublic', body.isPublic),
    validateOptionalDate('publishAt', body.publishAt),
    validateOptionalDate('registrationDeadline', body.registrationDeadline),
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
