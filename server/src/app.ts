import express, { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'crypto';
import {
  changeAuthorPassword,
  createAuthor,
  createAuthorDraft,
  createAuthorEvent,
  createEventUpdate,
  deleteAllEvents,
  deleteAuthorDraftById,
  deleteAuthorEventById,
  deleteAuthorById,
  deleteEventById,
  getAuthorDrafts,
  getAuthorEvents,
  getAuthorSession,
  getEventUpdates,
  getEvents,
  loginAuthor,
  logoutAuthor,
  listAuthors,
  refreshAuthorSession,
  resetAuthorPassword,
  setAuthorActive,
  updateAuthorDraftById,
  updateAuthorEventById,
  updateEventById,
  clearDrafts,
  clearEvents,
  clearAuthorData,
  createAuthorForTesting,
  DraftInput,
  EventInput,
} from './db';
import { sendEventNotification, sendEventUpdateNotification } from './fcm';
import { getBuildInfo } from './buildInfo';
import { incrementUnknownEndpointCounter, isKnownEndpoint, logInfo, logRequest, logRequestError, logWarn } from './logger';
import { createRateLimitStore } from './rateLimitStore';
import { DV_TREE } from './dvTree';
import { validateEventTextFields, validateMessageField } from './eventValidation';

const app = express();
app.disable('x-powered-by');
const trustProxyHops = process.env.TRUST_PROXY_HOPS?.trim();
if (trustProxyHops) {
  const parsedTrustProxyHops = Number(trustProxyHops);
  if (!Number.isInteger(parsedTrustProxyHops) || parsedTrustProxyHops <= 0) {
    throw new Error('TRUST_PROXY_HOPS must be a positive integer');
  }
  app.set('trust proxy', parsedTrustProxyHops);
} else {
  app.set('trust proxy', 1);
}
app.use(express.json());

// Safety guard: only enable test endpoints when explicitly in test run mode.
if (process.env.ENABLE_TEST_ENDPOINTS === 'true' && process.env.TEST_RUN !== 'true') {
  console.error('Refusing to enable test endpoints: ENABLE_TEST_ENDPOINTS is true but TEST_RUN is not "true"');
  process.exit(1);
}

// If running in test mode, ensure TEST_DATABASE_URL is set and does not conflict with DATABASE_URL
if (process.env.TEST_RUN === 'true') {
  if (!process.env.TEST_DATABASE_URL) {
    console.error('TEST_RUN=true requires TEST_DATABASE_URL to be set');
    process.exit(1);
  }
  if (process.env.DATABASE_URL && process.env.DATABASE_URL !== process.env.TEST_DATABASE_URL) {
    console.error('TEST_RUN=true but DATABASE_URL differs from TEST_DATABASE_URL — aborting to avoid accidental production writes');
    process.exit(1);
  }
}

function positiveIntegerFromEnv(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) {
    return fallback;
  }
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return parsed;
}

type RateLimiterOptions = {
  scope: string;
  windowMs: number;
  maxRequests: number;
  errorMessage: string;
  keyFactory: (req: Request) => string;
};

const rateLimitStore = createRateLimitStore();

function createRateLimiter(options: RateLimiterOptions) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const nowMs = Date.now();
      const key = `${options.scope}:${options.keyFactory(req)}`;
      const current = await rateLimitStore.increment(key, options.windowMs, nowMs);
      if (current.count > options.maxRequests) {
        const retryAfterSeconds = Math.max(1, Math.ceil((current.resetAtMs - nowMs) / 1000));
        res.setHeader('Retry-After', String(retryAfterSeconds));
        res.status(429).json({ error: options.errorMessage });
        return;
      }
      next();
    } catch (error) {
      next(error);
    }
  };
}

const globalRateLimitWindowMs = positiveIntegerFromEnv('GLOBAL_RATE_LIMIT_WINDOW_MS', 60_000);
const globalRateLimitMax = positiveIntegerFromEnv('GLOBAL_RATE_LIMIT_MAX_REQUESTS', 300);
const authRateLimitWindowMs = positiveIntegerFromEnv('AUTH_RATE_LIMIT_WINDOW_MS', 60_000);
const authRateLimitMax = positiveIntegerFromEnv('AUTH_RATE_LIMIT_MAX_REQUESTS', 10);

const globalRateLimiter = createRateLimiter({
  scope: 'global',
  windowMs: globalRateLimitWindowMs,
  maxRequests: globalRateLimitMax,
  errorMessage: 'Too many requests',
  keyFactory: (req) => req.ip || 'unknown',
});

const authRateLimiter = createRateLimiter({
  scope: 'auth',
  windowMs: authRateLimitWindowMs,
  maxRequests: authRateLimitMax,
  errorMessage: 'Too many login attempts',
  keyFactory: (req) => {
    const username = typeof req.body?.username === 'string' ? req.body.username.trim().toLowerCase() : '';
    return `${req.ip || 'unknown'}:${username}`;
  },
});

app.use((req: Request, res: Response, next) => {
  const startedAt = Date.now();
  const headerRequestId = req.header('x-request-id');
  const requestId = headerRequestId && headerRequestId.trim() ? headerRequestId.trim() : randomUUID();
  res.locals.requestId = requestId;
  res.setHeader('x-request-id', requestId);

  res.on('finish', () => {
    if (isKnownEndpoint(req.method, req.path)) {
      logRequest({
        requestId,
        method: req.method,
        path: req.originalUrl,
        statusCode: res.statusCode,
        durationMs: Date.now() - startedAt,
        ip: req.ip,
        userAgent: req.get('user-agent'),
      });
      return;
    }

    incrementUnknownEndpointCounter();
  });

  next();
});
app.use(globalRateLimiter);

function getBearerToken(req: Request): string | null {
  const authorization = req.header('authorization');
  if (!authorization) {
    return null;
  }
  const [scheme, value] = authorization.split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !value?.trim()) {
    return null;
  }
  return value.trim();
}

async function requireAuthorAuth(req: Request, res: Response): Promise<boolean> {
  const token = getBearerToken(req);
  if (!token) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }

  const session = await getAuthorSession(token);
  if (!session) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }

  res.locals.author = session.author;
  res.locals.authorSession = session;
  res.locals.authToken = token;
  return true;
}

async function getViewerSession(req: Request) {
  const token = getBearerToken(req);
  if (!token) {
    return null;
  }
  return getAuthorSession(token);
}

function requireAdminSession(res: Response): boolean {
  const author = res.locals.author as { isAdmin?: boolean } | undefined;
  if (!author?.isAdmin) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  return true;
}

function requirePasswordChangeCompleted(res: Response): boolean {
  const session = res.locals.authorSession as { requiresPasswordChange: boolean } | undefined;
  if (session?.requiresPasswordChange) {
    res.status(403).json({ error: 'Password change required' });
    return false;
  }
  return true;
}

function respondBadRequest(req: Request, res: Response, message: string): Response {
  logWarn(message, { requestId: res.locals.requestId, method: req.method, path: req.originalUrl });
  return res.status(400).json({ error: message });
}

app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    treeVersion: DV_TREE.lastTreeChange,
    build: getBuildInfo(),
  });
});

app.get('/api/dvs', (_req: Request, res: Response) => {
  res.json({
    lastTreeChange: DV_TREE.lastTreeChange,
    dvs: DV_TREE.dvs,
  });
});

app.get('/api/events', async (req: Request, res: Response) => {
  try {
    const dv = typeof req.query.dv === 'string' ? req.query.dv : undefined;
    const events = await getEvents(dv);
    const viewer = await getViewerSession(req);
    const authorMap = viewer?.author.isAdmin ? new Map((await listAuthors()).map((author) => [author.id, author.username])) : null;
    const currentAuthorId = viewer?.author.id ?? null;

    res.json({
      events: events.map((event) => ({
        ...event,
        canEdit: Boolean(viewer && viewer.requiresPasswordChange === false && (viewer.author.isAdmin || event.authorId === currentAuthorId)),
        canDelete: Boolean(viewer && viewer.requiresPasswordChange === false && (viewer.author.isAdmin || event.authorId === currentAuthorId)),
        createdBy: authorMap && event.authorId != null ? authorMap.get(event.authorId) ?? null : undefined,
      })),
    });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load events' });
  }
});

app.post('/api/auth/login', authRateLimiter, async (req: Request, res: Response) => {
  try {
    const username = typeof req.body.username === 'string' ? req.body.username.trim() : '';
    const password = typeof req.body.password === 'string' ? req.body.password : '';
    if (!username || !password) {
      return respondBadRequest(req, res, 'Username and password are required');
    }

    const session = await loginAuthor(username, password);
    if (!session) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    res.json({
      token: session.token,
      accessToken: session.token,
      refreshToken: session.refreshToken,
      author: session.author,
      requiresPasswordChange: session.requiresPasswordChange,
      expiresAt: session.expiresAt,
      refreshExpiresAt: session.refreshExpiresAt,
    });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to login' });
  }
});

app.post('/api/auth/refresh', authRateLimiter, async (req: Request, res: Response) => {
  try {
    const refreshToken = typeof req.body.refreshToken === 'string' ? req.body.refreshToken.trim() : '';
    if (!refreshToken) {
      return respondBadRequest(req, res, 'Refresh token is required');
    }

    const session = await refreshAuthorSession(refreshToken);
    if (!session) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    res.json({
      token: session.token,
      accessToken: session.token,
      refreshToken: session.refreshToken,
      author: session.author,
      requiresPasswordChange: session.requiresPasswordChange,
      expiresAt: session.expiresAt,
      refreshExpiresAt: session.refreshExpiresAt,
    });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to refresh session' });
  }
});

app.post('/api/auth/logout', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    await logoutAuthor(res.locals.authToken as string);
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to logout' });
  }
});

app.get('/api/auth/me', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    const session = res.locals.authorSession as {
      author: { id: number; username: string };
      requiresPasswordChange: boolean;
      expiresAt: string;
    };
    res.json({
      author: session.author,
      requiresPasswordChange: session.requiresPasswordChange,
      expiresAt: session.expiresAt,
    });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load author session' });
  }
});

app.post('/api/auth/change-password', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }

    const newPassword = typeof req.body.newPassword === 'string' ? req.body.newPassword : '';
    const oldPassword = typeof req.body.oldPassword === 'string' ? req.body.oldPassword : undefined;
    if (newPassword.trim().length < 8) {
      return respondBadRequest(req, res, 'New password must be at least 8 characters long');
    }

    const author = res.locals.author as { id: number; username: string };
    const changed = await changeAuthorPassword(author.id, newPassword, oldPassword);
    if (changed === 'invalid_old_password') {
      return respondBadRequest(req, res, 'Invalid old password');
    }
    if (changed === 'author_not_found') {
      return res.status(404).json({ error: 'Author not found' });
    }

    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to change password' });
  }
});

app.get('/api/author/events', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const author = res.locals.author as { id: number };
    const events = await getAuthorEvents(author.id);
    res.json({ events });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load own events' });
  }
});

app.post('/api/events', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }

    const { title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as EventInput;
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }
    if (!title || !description || !startDate || !location || !dv) {
      return respondBadRequest(req, res, 'Missing required event fields');
    }

    const author = res.locals.author as { id: number };
    const event = await createAuthorEvent({ title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url }, author.id);

    logInfo('Created event, sending push notification', {
      requestId: res.locals.requestId,
      eventId: event.id,
      title,
      location,
      dv,
      topic,
    });

    try {
      await sendEventNotification({
        title,
        description,
        eventId: event.id,
        dv,
        topic,
      });
      logInfo('Push notification request completed for event', {
        requestId: res.locals.requestId,
        eventId: event.id,
      });
    } catch (notificationError) {
      logRequestError(notificationError, res.locals.requestId);
    }

    res.status(201).json({ event });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create event' });
  }
});

app.post('/api/author/events', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const { title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as EventInput;
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }
    if (!title || !description || !startDate || !location || !dv) {
      return respondBadRequest(req, res, 'Missing required event fields');
    }

    const author = res.locals.author as { id: number };
    const event = await createAuthorEvent({ title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url }, author.id);
    res.status(201).json({ event });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create own event' });
  }
});

app.get('/api/author/drafts', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const author = res.locals.author as { id: number };
    const drafts = await getAuthorDrafts(author.id);
    res.json({ drafts });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load drafts' });
  }
});

app.post('/api/author/drafts', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const { title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as DraftInput;
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }
    if (!title) {
      return respondBadRequest(req, res, 'Missing required draft fields');
    }

    const author = res.locals.author as { id: number };
    const draft = await createAuthorDraft({ title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url }, author.id);
    res.status(201).json({ draft });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create draft' });
  }
});

app.put('/api/author/drafts/:id', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid draft id');
    }
    const { title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as DraftInput;
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }
    if (!title) {
      return respondBadRequest(req, res, 'Missing required draft fields');
    }

    const author = res.locals.author as { id: number };
    const draft = await updateAuthorDraftById(id, author.id, { title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url });
    if (!draft) {
      return res.status(404).json({ error: 'Draft not found' });
    }
    res.json({ draft });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to update draft' });
  }
});

app.delete('/api/author/drafts/:id', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid draft id');
    }

    const author = res.locals.author as { id: number };
    const deleted = await deleteAuthorDraftById(id, author.id);
    if (!deleted) {
      return res.status(404).json({ error: 'Draft not found' });
    }
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete draft' });
  }
});

async function requireEditableEvent(req: Request, res: Response, eventAuthorId: number | null): Promise<boolean> {
  const author = res.locals.author as { id: number; isAdmin?: boolean } | undefined;
  if (!author) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  if (!author.isAdmin && eventAuthorId !== author.id) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  return true;
}

app.put('/api/events/:id', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid event id');
    }
    const events = await getEvents();
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (!await requireEditableEvent(req, res, current.authorId)) {
      return;
    }
    const { title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as EventInput;
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }
    if (!title || !description || !startDate || !location || !dv) {
      return respondBadRequest(req, res, 'Missing required event fields');
    }
    const updated = await updateEventById(id, {
      title,
      description,
      startDate,
      endDate,
      location,
      dv,
      topic,
      cta1Label,
      cta1Url,
      cta2Label,
      cta2Url,
    });
    if (!updated) {
      return res.status(404).json({ error: 'Event not found' });
    }
    res.json({ event: updated });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to update event' });
  }
});

app.put('/api/author/events/:id', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid event id');
    }

    const { title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as EventInput;
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }
    if (!title || !description || !startDate || !location || !dv) {
      return respondBadRequest(req, res, 'Missing required event fields');
    }

    const author = res.locals.author as { id: number };
    const event = await updateAuthorEventById(id, author.id, { title, description, startDate, endDate, location, dv, topic, cta1Label, cta1Url, cta2Label, cta2Url });
    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }
    res.json({ event });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to update own event' });
  }
});

app.delete('/api/events/:id', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }

    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid event id');
    }

    const events = await getEvents();
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }

    if (!await requireEditableEvent(req, res, current.authorId)) {
      return;
    }

    const deleted = await deleteEventById(id);
    if (!deleted) {
      return res.status(404).json({ error: 'Event not found' });
    }

    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete event' });
  }
});

app.delete('/api/author/events/:id', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid event id');
    }

    const author = res.locals.author as { id: number };
    const deleted = await deleteAuthorEventById(id, author.id);
    if (!deleted) {
      return res.status(404).json({ error: 'Event not found' });
    }

    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete own event' });
  }
});

app.get('/api/events/:id/updates', async (req: Request, res: Response) => {
  try {
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid event id');
    }
    const events = await getEvents();
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }
    const updates = await getEventUpdates(id);
    res.json({ updates });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load event updates' });
  }
});

app.post('/api/events/:id/updates', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid event id');
    }
    const events = await getEvents();
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (!await requireEditableEvent(req, res, current.authorId)) {
      return;
    }

    const { message } = req.body as { message?: string };
    const messageCheck = validateMessageField(message);
    if (!messageCheck.valid) {
      return respondBadRequest(req, res, messageCheck.error);
    }
    if (!message || !message.trim()) {
      return respondBadRequest(req, res, 'Missing update message');
    }

    const author = res.locals.author as { id: number };
    const update = await createEventUpdate(id, author.id, message);

    try {
      await sendEventUpdateNotification({
        eventId: id,
        eventTitle: current.title,
        message,
      });
    } catch (notificationError) {
      logRequestError(notificationError, res.locals.requestId);
    }

    res.status(201).json({ update });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create event update' });
  }
});

app.delete('/api/events', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    if (!requireAdminSession(res)) {
      return;
    }
    const deletedCount = await deleteAllEvents();
    res.json({ deletedCount });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete events' });
  }
});

app.get('/api/admin/users', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requireAdminSession(res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    res.json({ users: await listAuthors() });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load users' });
  }
});

app.post('/api/admin/users', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requireAdminSession(res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const username = typeof req.body.username === 'string' ? req.body.username.trim() : '';
    const isAdmin = req.body.isAdmin === true;
    if (!username) {
      return respondBadRequest(req, res, 'Username is required');
    }
    const result = await createAuthor({ username, isAdmin });
    res.status(201).json(result);
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create user' });
  }
});

app.patch('/api/admin/users/:id', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requireAdminSession(res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid user id');
    }
    if (typeof req.body.isActive !== 'boolean') {
      return respondBadRequest(req, res, 'isActive is required');
    }
    const updated = await setAuthorActive(id, req.body.isActive);
    if (!updated) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to update user' });
  }
});

app.delete('/api/admin/users/:id', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requireAdminSession(res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid user id');
    }
    const deleted = await deleteAuthorById(id);
    if (!deleted) {
      return res.status(409).json({ error: 'User must be deactivated before deletion' });
    }
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete user' });
  }
});

app.post('/api/admin/users/:id/reset-password', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requireAdminSession(res)) {
      return;
    }
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return respondBadRequest(req, res, 'Invalid user id');
    }
    const oneTimePassword = await resetAuthorPassword(id);
    if (!oneTimePassword) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ oneTimePassword });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to reset password' });
  }
});

// Test-only reset endpoint to clear DB and optionally seed a test author.
app.post('/__test/reset', async (req: Request, res: Response) => {
  try {
    if (process.env.ENABLE_TEST_ENDPOINTS !== 'true') {
      return res.status(404).json({ error: 'Not found' });
    }
    await clearEvents();
    await clearDrafts();
    await clearAuthorData();
    const seed = req.body?.seedAuthor;
    if (seed && seed.username && seed.password) {
      await createAuthorForTesting({ username: seed.username, password: seed.password, oneTimePassword: seed.oneTimePassword ?? seed.password, isAdmin: seed.isAdmin ?? false });
    }
    res.json({ ok: true });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to reset test data' });
  }
});

// Simple health endpoint for test orchestration
app.get('/__test/health', (_req: Request, res: Response) => {
  if (process.env.TEST_RUN !== 'true') {
    return res.status(404).json({ error: 'Not found' });
  }
  res.json({ ok: true, mode: 'test' });
});

app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'Not found' });
});

app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
  logRequestError(error, res.locals.requestId as string | undefined);
  if (res.headersSent) {
    return;
  }
  res.status(500).json({ error: 'Internal server error' });
});

export default app;
