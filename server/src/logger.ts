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

export function logInfo(message: string, fields: Record<string, unknown> = {}): void {
  emit('info', message, fields);
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