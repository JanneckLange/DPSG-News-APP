import express, { NextFunction, Request, Response } from 'express';
import {
  addAdminLayer,
  addAuthorLayerGrant,
  addAuthorTopicGrant,
  createAuthor,
  createAuthorEvent,
  createEventUpdate,
  deleteAllEvents,
  deleteAuthorEventById,
  deleteAuthorById,
  deleteEventById,
  getAdminLayerIds,
  getAuthorById,
  getAuthorEvents,
  getAuthorLayerGrantIds,
  getAuthorTopicGrantIds,
  getEventUpdateById,
  getEventUpdates,
  getEvents,
  getLayerById,
  getTopicById,
  getTopics,
  listAuthors,
  removeAdminLayer,
  removeAuthorLayerGrant,
  removeAuthorTopicGrant,
  resetAuthorPassword,
  setAuthorActive,
  updateAuthorEventById,
  updateEventById,
  updateEventUpdateById,
  deleteEventUpdateById,
  EventInput,
} from './db';
import { sendEventNotification, sendEventUpdateNotification } from './fcm';
import { logInfo, logRequestError } from './logger';
import { validateEventTextFields, validateMessageField } from './eventValidation';
import { requestContextMiddleware } from './middleware/requestContext';
import { globalRateLimiter } from './middleware/rateLimit';
import { publicRouter } from './routes/public';
import { authRouter } from './routes/auth';
import { draftsRouter } from './routes/drafts';
import { adminLayersRouter } from './routes/adminLayers';
import { adminTopicsRouter } from './routes/adminTopics';
import { testOnlyRouter } from './routes/testOnly';
import {
  getViewerSession,
  requireAdminSession,
  requireAuthorAuth,
  requirePasswordChangeCompleted,
} from './middleware/auth';
import {
  canManageWithinLayerScope,
  isKnownLayerId,
  requireEventGrant,
  requireLayerScope,
  requireLayerScopeForAll,
  requireManageableWithinLayerScope,
  requireOwnEvent,
} from './middleware/scope';
import { parseLayerId, respondBadRequest } from './middleware/validation';

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

app.use(requestContextMiddleware);
app.use(globalRateLimiter);

app.use(publicRouter);
app.use(authRouter);

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

    const { title, description, startDate, endDate, location, topicId, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as EventInput;
    const layerId = parseLayerId((req.body as EventInput).layerId);
    if (!title || !description || !startDate || !location || !layerId) {
      return respondBadRequest(req, res, 'Missing required event fields');
    }
    const layer = await getLayerById(layerId);
    if (!layer) {
      return respondBadRequest(req, res, 'Invalid layerId');
    }
    if (!requireEventGrant(res, layerId, topicId)) {
      return;
    }
    const topicIds = (await getTopics(layer.id)).map((t) => t.id);
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>, topicIds);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }

    const author = res.locals.author as { id: number };
    const event = await createAuthorEvent({ title, description, startDate, endDate, location, layerId, topicId, cta1Label, cta1Url, cta2Label, cta2Url }, author.id);

    logInfo('Created event, sending push notification', {
      requestId: res.locals.requestId,
      eventId: event.id,
      title,
      location,
      layerId,
      topicId,
    });

    try {
      await sendEventNotification({
        title,
        description,
        eventId: event.id,
        layerId,
        topicId,
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
    const { title, description, startDate, endDate, location, topicId, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as EventInput;
    const layerId = parseLayerId((req.body as EventInput).layerId);
    if (!title || !description || !startDate || !location || !layerId) {
      return respondBadRequest(req, res, 'Missing required event fields');
    }
    const layer = await getLayerById(layerId);
    if (!layer) {
      return respondBadRequest(req, res, 'Invalid layerId');
    }
    if (!requireEventGrant(res, layerId, topicId)) {
      return;
    }
    const topicIds = (await getTopics(layer.id)).map((t) => t.id);
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>, topicIds);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }

    const author = res.locals.author as { id: number };
    const event = await createAuthorEvent({ title, description, startDate, endDate, location, layerId, topicId, cta1Label, cta1Url, cta2Label, cta2Url }, author.id);
    res.status(201).json({ event });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create own event' });
  }
});

app.use(draftsRouter);

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
    if (!await requireManageableWithinLayerScope(res, current.authorId, current.layerId)) {
      return;
    }
    const { title, description, startDate, endDate, location, topicId, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as EventInput;
    const layerId = parseLayerId((req.body as EventInput).layerId);
    if (!title || !description || !startDate || !location || !layerId) {
      return respondBadRequest(req, res, 'Missing required event fields');
    }
    const layer = await getLayerById(layerId);
    if (!layer) {
      return respondBadRequest(req, res, 'Invalid layerId');
    }
    const topicIds = (await getTopics(layer.id)).map((t) => t.id);
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>, topicIds);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }
    const updated = await updateEventById(id, {
      title,
      description,
      startDate,
      endDate,
      location,
      layerId,
      topicId,
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

    const { title, description, startDate, endDate, location, topicId, cta1Label, cta1Url, cta2Label, cta2Url } = req.body as EventInput;
    const layerId = parseLayerId((req.body as EventInput).layerId);
    if (!title || !description || !startDate || !location || !layerId) {
      return respondBadRequest(req, res, 'Missing required event fields');
    }
    const layer = await getLayerById(layerId);
    if (!layer) {
      return respondBadRequest(req, res, 'Invalid layerId');
    }
    const topicIds = (await getTopics(layer.id)).map((t) => t.id);
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>, topicIds);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }

    const author = res.locals.author as { id: number };
    const event = await updateAuthorEventById(id, author.id, { title, description, startDate, endDate, location, layerId, topicId, cta1Label, cta1Url, cta2Label, cta2Url });
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

    if (!await requireManageableWithinLayerScope(res, current.authorId, current.layerId)) {
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
    const viewer = await getViewerSession(req);
    const viewerUsable = Boolean(viewer && viewer.requiresPasswordChange === false);
    const enrichedUpdates = await Promise.all(updates.map(async (update) => {
      const canManage = viewerUsable
        ? await canManageWithinLayerScope(viewer!.author, update.authorId, current.layerId)
        : false;
      return { ...update, canEdit: canManage, canDelete: canManage };
    }));
    res.json({ updates: enrichedUpdates });
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
    if (!requireOwnEvent(res, current.authorId)) {
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

    res.status(201).json({ update: { ...update, canEdit: true, canDelete: true } });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create event update' });
  }
});

app.put('/api/events/:id/updates/:updateId', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const eventId = Number(req.params.id);
    const updateId = Number(req.params.updateId);
    if (Number.isNaN(eventId) || eventId <= 0 || Number.isNaN(updateId) || updateId <= 0) {
      return respondBadRequest(req, res, 'Invalid id');
    }

    const events = await getEvents();
    const event = events.find((e) => e.id === eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    const update = await getEventUpdateById(updateId);
    if (!update || update.eventId !== eventId) {
      return res.status(404).json({ error: 'Update not found' });
    }

    if (!await requireManageableWithinLayerScope(res, update.authorId, event.layerId)) {
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

    const updated = await updateEventUpdateById(updateId, message);
    if (!updated) {
      return res.status(404).json({ error: 'Update not found' });
    }
    res.json({ update: { ...updated, canEdit: true, canDelete: true } });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to update event update' });
  }
});

app.delete('/api/events/:id/updates/:updateId', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const eventId = Number(req.params.id);
    const updateId = Number(req.params.updateId);
    if (Number.isNaN(eventId) || eventId <= 0 || Number.isNaN(updateId) || updateId <= 0) {
      return respondBadRequest(req, res, 'Invalid id');
    }

    const events = await getEvents();
    const event = events.find((e) => e.id === eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    const update = await getEventUpdateById(updateId);
    if (!update || update.eventId !== eventId) {
      return res.status(404).json({ error: 'Update not found' });
    }

    if (!await requireManageableWithinLayerScope(res, update.authorId, event.layerId)) {
      return;
    }

    const deleted = await deleteEventUpdateById(updateId);
    if (!deleted) {
      return res.status(404).json({ error: 'Update not found' });
    }
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete event update' });
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
    let adminLayerIds: number[] = [];
    if (isAdmin) {
      const rawLayerIds = Array.isArray(req.body.layerIds) ? req.body.layerIds : [];
      adminLayerIds = rawLayerIds.map(parseLayerId).filter((id: number | undefined): id is number => id !== undefined);
      if (adminLayerIds.length === 0 || adminLayerIds.length !== rawLayerIds.length) {
        return respondBadRequest(req, res, 'Invalid layerIds');
      }
      for (const layerId of adminLayerIds) {
        if (!await isKnownLayerId(layerId)) {
          return respondBadRequest(req, res, 'Invalid layerIds');
        }
      }
      if (!await requireLayerScopeForAll(res, adminLayerIds)) {
        return;
      }
    }
    const result = await createAuthor({ username, isAdmin, adminLayerIds });
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
    const target = await getAuthorById(id);
    if (target?.isAdmin && !await requireLayerScopeForAll(res, target.adminLayerIds)) {
      return;
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
    const target = await getAuthorById(id);
    if (target?.isAdmin && !await requireLayerScopeForAll(res, target.adminLayerIds)) {
      return;
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

app.post('/api/admin/users/:id/admin-layers', async (req: Request, res: Response) => {
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
    const target = await getAuthorById(id);
    if (!target) {
      return res.status(404).json({ error: 'User not found' });
    }
    const layerId = parseLayerId(req.body.layerId);
    if (!layerId || !await isKnownLayerId(layerId)) {
      return respondBadRequest(req, res, 'Invalid layerId');
    }
    if (!await requireLayerScopeForAll(res, target.adminLayerIds)) {
      return;
    }
    if (!await requireLayerScope(res, layerId)) {
      return;
    }
    await addAdminLayer(target.id, layerId);
    res.status(201).json({ adminLayerIds: await getAdminLayerIds(target.id) });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to add admin layer' });
  }
});

app.delete('/api/admin/users/:id/admin-layers/:layerId', async (req: Request, res: Response) => {
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
    const layerId = Number(req.params.layerId);
    if (Number.isNaN(id) || id <= 0 || Number.isNaN(layerId) || layerId <= 0) {
      return respondBadRequest(req, res, 'Invalid user or layer id');
    }
    const target = await getAuthorById(id);
    if (!target) {
      return res.status(404).json({ error: 'User not found' });
    }
    if (!target.isAdmin) {
      return respondBadRequest(req, res, 'User is not an admin');
    }
    if (!await requireLayerScopeForAll(res, target.adminLayerIds)) {
      return;
    }
    if (!await requireLayerScope(res, layerId)) {
      return;
    }
    const result = await removeAdminLayer(target.id, layerId);
    if (result === 'not_found') {
      return res.status(404).json({ error: 'Layer not assigned to this admin' });
    }
    if (result === 'last_layer') {
      return res.status(409).json({ error: 'Admin muss mindestens einem Layer zugeordnet bleiben' });
    }
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to remove admin layer' });
  }
});

app.post('/api/admin/users/:id/layer-grants', async (req: Request, res: Response) => {
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
    const target = await getAuthorById(id);
    if (!target) {
      return res.status(404).json({ error: 'User not found' });
    }
    const layerId = parseLayerId(req.body.layerId);
    if (!layerId || !await isKnownLayerId(layerId)) {
      return respondBadRequest(req, res, 'Invalid layerId');
    }
    if (!await requireLayerScope(res, layerId)) {
      return;
    }
    await addAuthorLayerGrant(target.id, layerId);
    res.status(201).json({ layerGrantIds: await getAuthorLayerGrantIds(target.id) });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to add layer grant' });
  }
});

app.delete('/api/admin/users/:id/layer-grants/:layerId', async (req: Request, res: Response) => {
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
    const layerId = Number(req.params.layerId);
    if (Number.isNaN(id) || id <= 0 || Number.isNaN(layerId) || layerId <= 0) {
      return respondBadRequest(req, res, 'Invalid user or layer id');
    }
    const target = await getAuthorById(id);
    if (!target) {
      return res.status(404).json({ error: 'User not found' });
    }
    if (!await requireLayerScope(res, layerId)) {
      return;
    }
    await removeAuthorLayerGrant(target.id, layerId);
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to remove layer grant' });
  }
});

app.post('/api/admin/users/:id/topic-grants', async (req: Request, res: Response) => {
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
    const target = await getAuthorById(id);
    if (!target) {
      return res.status(404).json({ error: 'User not found' });
    }
    const topicId = parseLayerId(req.body.topicId);
    if (!topicId) {
      return respondBadRequest(req, res, 'Invalid topicId');
    }
    const topic = await getTopicById(topicId);
    if (!topic) {
      return respondBadRequest(req, res, 'Invalid topicId');
    }
    if (!await requireLayerScope(res, topic.layerId)) {
      return;
    }
    await addAuthorTopicGrant(target.id, topicId);
    res.status(201).json({ topicGrantIds: await getAuthorTopicGrantIds(target.id) });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to add topic grant' });
  }
});

app.delete('/api/admin/users/:id/topic-grants/:topicId', async (req: Request, res: Response) => {
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
    const topicId = Number(req.params.topicId);
    if (Number.isNaN(id) || id <= 0 || Number.isNaN(topicId) || topicId <= 0) {
      return respondBadRequest(req, res, 'Invalid user or topic id');
    }
    const target = await getAuthorById(id);
    if (!target) {
      return res.status(404).json({ error: 'User not found' });
    }
    const topic = await getTopicById(topicId);
    if (topic && !await requireLayerScope(res, topic.layerId)) {
      return;
    }
    await removeAuthorTopicGrant(target.id, topicId);
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to remove topic grant' });
  }
});

app.use(adminLayersRouter);
app.use(adminTopicsRouter);

// Test-only reset endpoint to clear DB and optionally seed a test author.
app.use(testOnlyRouter);

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
