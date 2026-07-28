import { Router, Request, Response } from 'express';
import {
  AuthorIdentity,
  EventInput,
  createAuthorEvent,
  createEventUpdate,
  deleteAllEvents,
  deleteAuthorEventById,
  deleteEventById,
  deleteEventUpdateById,
  getAuthorEvents,
  getEventUpdateById,
  getEventUpdates,
  getEvents,
  getLayerById,
  getTopics,
  updateAuthorEventById,
  updateEventById,
  updateEventUpdateById,
} from '../db';
import { sendEventNotification, sendEventUpdateNotification } from '../fcm';
import { logInfo, logRequestError } from '../logger';
import { validateEventTextFields, validateMessageField } from '../eventValidation';
import { getViewerSession, requireAdminSession, requireAuthorAuth, requirePasswordChangeCompleted } from '../middleware/auth';
import {
  canManageWithinLayerScope,
  requireEventGrant,
  requireLayerScope,
  requireManageableWithinLayerScope,
  requireOwnEvent,
} from '../middleware/scope';
import { parseLayerId, respondBadRequest } from '../middleware/validation';

export const eventsRouter = Router();

eventsRouter.get('/api/author/events', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const author = res.locals.author as AuthorIdentity;
    const events = await getAuthorEvents(author.id);
    const enrichedEvents = await Promise.all(events.map(async (event) => {
      const canManage = await canManageWithinLayerScope(author, event.authorId, event.layerId);
      return {
        ...event,
        canEdit: canManage,
        canDelete: canManage,
        canCreateUpdate: event.authorId === author.id,
      };
    }));
    res.json({ events: enrichedEvents });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load own events' });
  }
});

eventsRouter.post('/api/events', async (req: Request, res: Response) => {
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

eventsRouter.post('/api/author/events', async (req: Request, res: Response) => {
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

eventsRouter.put('/api/events/:id', async (req: Request, res: Response) => {
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
    // Rechtematrix aus #1: das ZIEL-Layer/Topic muss erneut geprueft werden, nicht nur
    // das bisherige - sonst liesse sich die Grant-Pflicht aus "create post" per Edit
    // umgehen (#111). Eigentuemer bleiben an ihren Autoren-Grant gebunden, ein fremder
    // Admin an seinen Layer-Scope.
    const editor = res.locals.author as AuthorIdentity;
    if (current.authorId === editor.id) {
      if (!requireEventGrant(res, layerId, topicId)) {
        return;
      }
    } else if (!await requireLayerScope(res, layerId)) {
      return;
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

eventsRouter.put('/api/author/events/:id', async (req: Request, res: Response) => {
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
    const events = await getEvents();
    const current = events.find((event) => event.id === id);
    if (!current || current.authorId !== author.id) {
      return res.status(404).json({ error: 'Event not found' });
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
    // Rechtematrix aus #1: das ZIEL-Layer/Topic muss gegen den Autoren-Grant geprueft
    // werden, sonst liesse sich die Grant-Pflicht aus "create post" per Edit umgehen (#111).
    // Erst NACH der Ownership-Pruefung, damit fremde Events weiterhin als 404 erscheinen.
    if (!requireEventGrant(res, layerId, topicId)) {
      return;
    }
    const topicIds = (await getTopics(layer.id)).map((t) => t.id);
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>, topicIds);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }

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

eventsRouter.delete('/api/events/:id', async (req: Request, res: Response) => {
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

eventsRouter.delete('/api/author/events/:id', async (req: Request, res: Response) => {
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

eventsRouter.get('/api/events/:id/updates', async (req: Request, res: Response) => {
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

eventsRouter.post('/api/events/:id/updates', async (req: Request, res: Response) => {
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

eventsRouter.put('/api/events/:id/updates/:updateId', async (req: Request, res: Response) => {
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

eventsRouter.delete('/api/events/:id/updates/:updateId', async (req: Request, res: Response) => {
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

eventsRouter.delete('/api/events', async (req: Request, res: Response) => {
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
