export const SERVICE_NAME = 'dpsg-news-server';

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

type BaseLogFields = {
  timestampUtc: string;
  level: LogLevel;
  service: string;
  env: string;
  message: string;
};

type RequestLogFields = {
  requestId: string;
  method: string;
  path: string;
  statusCode: number;
  durationMs: number;
  ip?: string;
  userAgent?: string;
};

type ErrorLogFields = {
  requestId?: string;
  errorName: string;
  errorMessage: string;
  stack?: string;
};

type HourBucket = {
  hourStartUtc: string;
  count: number;
};

const KNOWN_ENDPOINTS: Array<{ method: string; path: RegExp }> = [
  { method: 'GET', path: /^\/health\/?$/ },
  { method: 'GET', path: /^\/api\/dvs\/?$/ },
  { method: 'GET', path: /^\/api\/events\/?$/ },
  { method: 'POST', path: /^\/api\/events\/?$/ },
  { method: 'PUT', path: /^\/api\/events\/\d+\/?$/ },
  { method: 'DELETE', path: /^\/api\/events\/\d+\/?$/ },
  { method: 'DELETE', path: /^\/api\/events\/?$/ },
  { method: 'GET', path: /^\/api\/events\/\d+\/updates\/?$/ },
  { method: 'POST', path: /^\/api\/events\/\d+\/updates\/?$/ },
  { method: 'POST', path: /^\/api\/auth\/login\/?$/ },
  { method: 'POST', path: /^\/api\/auth\/refresh\/?$/ },
  { method: 'POST', path: /^\/api\/auth\/logout\/?$/ },
  { method: 'GET', path: /^\/api\/auth\/me\/?$/ },
  { method: 'POST', path: /^\/api\/auth\/change-password\/?$/ },
  { method: 'GET', path: /^\/api\/author\/events\/?$/ },
  { method: 'POST', path: /^\/api\/author\/events\/?$/ },
  { method: 'PUT', path: /^\/api\/author\/events\/\d+\/?$/ },
  { method: 'DELETE', path: /^\/api\/author\/events\/\d+\/?$/ },
  { method: 'GET', path: /^\/api\/admin\/users\/?$/ },
  { method: 'POST', path: /^\/api\/admin\/users\/?$/ },
  { method: 'PATCH', path: /^\/api\/admin\/users\/\d+\/?$/ },
  { method: 'DELETE', path: /^\/api\/admin\/users\/\d+\/?$/ },
  { method: 'POST', path: /^\/api\/admin\/users\/\d+\/reset-password\/?$/ },
];

let unknownEndpointBucket: HourBucket = {
  hourStartUtc: currentHourStartUtc(),
  count: 0,
};

function environment(): string {
  return (process.env.NODE_ENV || 'development').trim() || 'development';
}

function formatPrettyLine(fields: BaseLogFields & Record<string, unknown>): string {
  const { timestampUtc, level, service, env, message, ...rest } = fields;
  const details = Object.keys(rest).length > 0 ? ` ${JSON.stringify(rest)}` : '';
  return `[${timestampUtc}] ${level.toUpperCase()} ${service} (${env}) ${message}${details}`;
}

function emit(level: LogLevel, message: string, fields: Record<string, unknown> = {}): void {
  const entry: BaseLogFields & Record<string, unknown> = {
    timestampUtc: new Date().toISOString(),
    level,
    service: SERVICE_NAME,
    env: environment(),
    message,
    ...fields,
  };

  if (environment() === 'production') {
    const serialized = JSON.stringify(entry);
    if (level === 'error') {
      console.error(serialized);
      return;
    }
    console.log(serialized);
    return;
  }

  const line = formatPrettyLine(entry);
  if (level === 'error') {
    console.error(line);
    return;
  }
  console.log(line);
}

function currentHourStartUtc(now: Date = new Date()): string {
  const bucketStart = new Date(now);
  bucketStart.setUTCMinutes(0, 0, 0);
  return bucketStart.toISOString();
}

export function logInfo(message: string, fields: Record<string, unknown> = {}): void {
  emit('info', message, fields);
}

export function logWarn(message: string, fields: Record<string, unknown> = {}): void {
  emit('warn', message, fields);
}

export function logError(message: string, fields: Record<string, unknown> = {}): void {
  emit('error', message, fields);
}

export function logRequest(fields: RequestLogFields): void {
  emit('info', 'HTTP request completed', fields);
}

export function logRequestError(error: unknown, requestId?: string): void {
  const normalized = error instanceof Error
    ? {
        errorName: error.name,
        errorMessage: error.message,
        stack: error.stack,
      }
    : {
        errorName: 'UnknownError',
        errorMessage: String(error),
      };

  const errorFields: ErrorLogFields = {
    requestId,
    errorName: normalized.errorName,
    errorMessage: normalized.errorMessage,
  };

  if (normalized.stack) {
    errorFields.stack = normalized.stack;
  }

  emit('error', 'Unhandled request error', errorFields);
}

export function isKnownEndpoint(method: string, path: string): boolean {
  return KNOWN_ENDPOINTS.some((endpoint) => endpoint.method === method && endpoint.path.test(path));
}

export function incrementUnknownEndpointCounter(): void {
  const hourStartUtc = currentHourStartUtc();
  if (unknownEndpointBucket.hourStartUtc !== hourStartUtc) {
    if (unknownEndpointBucket.count > 0) {
      logWarn('Unknown endpoint requests aggregated', {
        hourStartUtc: unknownEndpointBucket.hourStartUtc,
        count: unknownEndpointBucket.count,
      });
    }
    unknownEndpointBucket = { hourStartUtc, count: 0 };
  }
  unknownEndpointBucket.count += 1;
}
