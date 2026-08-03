import { Router, Request, Response } from 'express';
import {
  AuthorIdentity,
  EventInput,
  acceptEventTransferRequest,
  createAuthorEvent,
  createEventTransferRequest,
  createEventUpdate,
  deleteAllEvents,
  deleteAuthorEventById,
  deleteEventById,
  deleteEventUpdateById,
  getAuthorById,
  getAuthorEvents,
  getEventHistory,
  getEventTransferRequestById,
  getEventTransferRequestsForEvent,
  getEventUpdateById,
  getEventUpdates,
  getEvents,
  getIncomingEventTransferRequestsWithDetails,
  getLayerById,
  getPendingEventTransferRequestForEvent,
  getTopics,
  listAuthors,
  recordEventHistory,
  resolveEventTransferRequest,
  transferEventAuthorById,
  updateAuthorEventById,
  updateEventById,
  updateEventUpdateById,
} from '../db';
import { sendEventNotification, sendEventTransferRequestNotification, sendEventUpdateNotification } from '../fcm';
import { logInfo, logRequestError } from '../logger';
import { validateEventTextFields, validateMessageField } from '../eventValidation';
import { getViewerSession, requireAdminSession, requireAuthorAuth, requirePasswordChangeCompleted } from '../middleware/auth';
import {
  authorHasEventGrant,
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

    const { title, description, startDate, endDate, locationAddress, locationLat, locationLng, topicId, cta1Url, cta2Url, isPublic, publishAt, registrationDeadline } = req.body as EventInput;
    const layerId = parseLayerId((req.body as EventInput).layerId);
    if (!title || !description || !startDate || !layerId) {
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
    const event = await createAuthorEvent({ title, description, startDate, endDate, locationAddress, locationLat, locationLng, layerId, topicId, cta1Url, cta2Url, isPublic, publishAt, registrationDeadline }, author.id);

    logInfo('Created event, sending push notification', {
      requestId: res.locals.requestId,
      eventId: event.id,
      title,
      locationAddress,
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
    const { title, description, startDate, endDate, locationAddress, locationLat, locationLng, topicId, cta1Url, cta2Url, isPublic, publishAt, registrationDeadline } = req.body as EventInput;
    const layerId = parseLayerId((req.body as EventInput).layerId);
    if (!title || !description || !startDate || !layerId) {
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
    const event = await createAuthorEvent({ title, description, startDate, endDate, locationAddress, locationLat, locationLng, layerId, topicId, cta1Url, cta2Url, isPublic, publishAt, registrationDeadline }, author.id);
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
    const events = await getEvents(undefined, { includeUnpublished: true });
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (!await requireManageableWithinLayerScope(res, current.authorId, current.layerId)) {
      return;
    }
    const { title, description, startDate, endDate, locationAddress, locationLat, locationLng, topicId, cta1Url, cta2Url, isPublic, publishAt, registrationDeadline } = req.body as EventInput;
    const layerId = parseLayerId((req.body as EventInput).layerId);
    if (!title || !description || !startDate || !layerId) {
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
      locationAddress,
      locationLat,
      locationLng,
      layerId,
      topicId,
      cta1Url,
      cta2Url,
      isPublic,
      publishAt,
      registrationDeadline,
    });
    if (!updated) {
      return res.status(404).json({ error: 'Event not found' });
    }
    try {
      await recordEventHistory(id, editor.id, current, updated);
    } catch (historyError) {
      logRequestError(historyError, res.locals.requestId);
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
    const events = await getEvents(undefined, { includeUnpublished: true });
    const current = events.find((event) => event.id === id);
    if (!current || current.authorId !== author.id) {
      return res.status(404).json({ error: 'Event not found' });
    }

    const { title, description, startDate, endDate, locationAddress, locationLat, locationLng, topicId, cta1Url, cta2Url, isPublic, publishAt, registrationDeadline } = req.body as EventInput;
    const layerId = parseLayerId((req.body as EventInput).layerId);
    if (!title || !description || !startDate || !layerId) {
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

    const event = await updateAuthorEventById(id, author.id, { title, description, startDate, endDate, locationAddress, locationLat, locationLng, layerId, topicId, cta1Url, cta2Url, isPublic, publishAt, registrationDeadline });
    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }
    try {
      await recordEventHistory(id, author.id, current, event);
    } catch (historyError) {
      logRequestError(historyError, res.locals.requestId);
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

    const events = await getEvents(undefined, { includeUnpublished: true });
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
    const events = await getEvents(undefined, { includeUnpublished: true });
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

eventsRouter.get('/api/events/:id/history', async (req: Request, res: Response) => {
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
    const events = await getEvents(undefined, { includeUnpublished: true });
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (!await requireManageableWithinLayerScope(res, current.authorId, current.layerId)) {
      return;
    }
    const history = await getEventHistory(id);
    res.json({ history });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load event history' });
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
    const events = await getEvents(undefined, { includeUnpublished: true });
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

    const events = await getEvents(undefined, { includeUnpublished: true });
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

    const events = await getEvents(undefined, { includeUnpublished: true });
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

// Autoren mit passenden Layer/Topic-Rechten fuer die Zielperson-Auswahl beim
// Anbieten eines eigenen Events (#24). Bewusst schlank (nur id/username) statt
// des vollen Admin-Nutzerlistenendpunkts, damit normale Autoren keinen Zugriff
// auf Admin-only-Felder anderer Konten bekommen.
eventsRouter.get('/api/events/:id/eligible-authors', async (req: Request, res: Response) => {
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
    const events = await getEvents(undefined, { includeUnpublished: true });
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (!requireOwnEvent(res, current.authorId)) {
      return;
    }
    if (current.layerId == null) {
      return res.json({ authors: [] });
    }

    const allAuthors = await listAuthors();
    const eligible = allAuthors
      .filter((candidate) => candidate.isActive && candidate.id !== current.authorId && authorHasEventGrant(candidate, current.layerId as number, current.topicId))
      .map((candidate) => ({ id: candidate.id, username: candidate.username }));

    res.json({ authors: eligible });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load eligible authors' });
  }
});

// Autor bietet ein eigenes Event einer Zielperson zur Uebertragung an (#22).
// Wird erst nach Annahme durch die Zielperson wirksam (siehe .../accept unten).
eventsRouter.post('/api/events/:id/transfer-requests', async (req: Request, res: Response) => {
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
    const toAuthorId = Number((req.body as { toAuthorId?: unknown }).toAuthorId);
    if (!Number.isInteger(toAuthorId) || toAuthorId <= 0) {
      return respondBadRequest(req, res, 'Invalid toAuthorId');
    }

    const events = await getEvents(undefined, { includeUnpublished: true });
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (!requireOwnEvent(res, current.authorId)) {
      return;
    }
    if (current.layerId == null) {
      return respondBadRequest(req, res, 'Event has no layer assigned');
    }
    if (toAuthorId === current.authorId) {
      return respondBadRequest(req, res, 'Cannot transfer an event to its current author');
    }

    const targetAuthor = await getAuthorById(toAuthorId);
    if (!targetAuthor || !authorHasEventGrant(targetAuthor, current.layerId, current.topicId)) {
      return respondBadRequest(req, res, 'Target author is not eligible for this event');
    }

    const author = res.locals.author as AuthorIdentity;
    const request = await createEventTransferRequest(id, author.id, toAuthorId);

    try {
      await sendEventTransferRequestNotification({
        toAuthorId,
        eventTitle: current.title,
        fromAuthorUsername: author.username,
      });
    } catch (notificationError) {
      logRequestError(notificationError, res.locals.requestId);
    }

    res.status(201).json({ request });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create transfer request' });
  }
});

// Zielperson nimmt eine eingehende Anfrage an - erst hier wird events.author_id
// tatsaechlich umgeschrieben, mit erneuter Rechtepruefung zum Annahme-Zeitpunkt.
eventsRouter.post('/api/events/transfer-requests/:requestId/accept', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const requestId = Number(req.params.requestId);
    if (Number.isNaN(requestId) || requestId <= 0) {
      return respondBadRequest(req, res, 'Invalid transfer request id');
    }
    const transferRequest = await getEventTransferRequestById(requestId);
    if (!transferRequest) {
      return res.status(404).json({ error: 'Transfer request not found' });
    }
    const author = res.locals.author as AuthorIdentity;
    if (transferRequest.toAuthorId !== author.id) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    if (transferRequest.status !== 'pending') {
      return res.status(409).json({ error: 'Transfer request is no longer pending' });
    }

    const events = await getEvents(undefined, { includeUnpublished: true });
    const current = events.find((event) => event.id === transferRequest.eventId);
    if (!current || current.layerId == null) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (!authorHasEventGrant(author, current.layerId, current.topicId)) {
      await resolveEventTransferRequest(requestId, 'invalid');
      return res.status(409).json({ error: 'You no longer have the required rights for this event' });
    }

    const result = await acceptEventTransferRequest(requestId);
    if (!result) {
      return res.status(409).json({ error: 'Transfer request is no longer pending' });
    }

    try {
      await recordEventHistory(current.id, author.id, current, result.event);
    } catch (historyError) {
      logRequestError(historyError, res.locals.requestId);
    }

    res.json({ event: result.event, request: result.request });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to accept transfer request' });
  }
});

// Zielperson lehnt eine eingehende Anfrage ab - das Event bleibt unveraendert.
eventsRouter.post('/api/events/transfer-requests/:requestId/reject', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const requestId = Number(req.params.requestId);
    if (Number.isNaN(requestId) || requestId <= 0) {
      return respondBadRequest(req, res, 'Invalid transfer request id');
    }
    const transferRequest = await getEventTransferRequestById(requestId);
    if (!transferRequest) {
      return res.status(404).json({ error: 'Transfer request not found' });
    }
    const author = res.locals.author as { id: number };
    if (transferRequest.toAuthorId !== author.id) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    const resolved = await resolveEventTransferRequest(requestId, 'rejected');
    if (!resolved) {
      return res.status(409).json({ error: 'Transfer request is no longer pending' });
    }
    res.json({ request: resolved });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to reject transfer request' });
  }
});

// Eigene eingehende, noch offene Anfragen (#24).
eventsRouter.get('/api/events/transfer-requests/incoming', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const author = res.locals.author as { id: number };
    const requests = await getIncomingEventTransferRequestsWithDetails(author.id);
    res.json({ requests });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load incoming transfer requests' });
  }
});

// Status der eigenen ausgehenden Anfrage(n) fuer ein Event (#24: ausstehend/
// angenommen/abgelehnt sichtbar machen).
eventsRouter.get('/api/events/:id/transfer-requests', async (req: Request, res: Response) => {
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
    const events = await getEvents(undefined, { includeUnpublished: true });
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (!requireOwnEvent(res, current.authorId)) {
      return;
    }
    const requests = await getEventTransferRequestsForEvent(id);
    res.json({ requests });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load transfer requests' });
  }
});

// Admin-Direktuebertragung ohne Zustimmung der Zielperson (#23). Bewusst
// requireLayerScope statt requireManageableWithinLayerScope: Letzteres wuerde
// auch dem Event-Eigentuemer selbst Zugriff geben, was hier explizit NICHT
// gewollt ist - Autoren duerfen ein Event nur ueber den Anfrage/Annahme-Flow
// (#22) abgeben, nur Admins mit Layer-Scope duerfen direkt (force) uebertragen.
eventsRouter.post('/api/events/:id/transfer', async (req: Request, res: Response) => {
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
    const toAuthorId = Number((req.body as { toAuthorId?: unknown }).toAuthorId);
    if (!Number.isInteger(toAuthorId) || toAuthorId <= 0) {
      return respondBadRequest(req, res, 'Invalid toAuthorId');
    }

    const events = await getEvents(undefined, { includeUnpublished: true });
    const current = events.find((event) => event.id === id);
    if (!current) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (current.layerId == null) {
      return respondBadRequest(req, res, 'Event has no layer assigned');
    }
    if (!await requireLayerScope(res, current.layerId)) {
      return;
    }
    if (toAuthorId === current.authorId) {
      return respondBadRequest(req, res, 'Cannot transfer an event to its current author');
    }

    const targetAuthor = await getAuthorById(toAuthorId);
    if (!targetAuthor || !authorHasEventGrant(targetAuthor, current.layerId, current.topicId)) {
      return respondBadRequest(req, res, 'Target author is not eligible for this event');
    }

    // Eine offene Autor-Anfrage fuer dieses Event wird durch die Direktuebertragung
    // obsolet - bewusst VOR dem Autorenwechsel storniert: wuerde die Zielperson der
    // alten Anfrage genau in diesem Moment noch annehmen, greift deren eigene
    // WHERE status = 'pending'-Bedingung (siehe acceptEventTransferRequest) nicht
    // mehr und die Annahme schlaegt sauber mit 409 fehl, statt die Direktuebertragung
    // im Anschluss wieder zu ueberschreiben.
    const pendingRequest = await getPendingEventTransferRequestForEvent(id);
    if (pendingRequest) {
      await resolveEventTransferRequest(pendingRequest.id, 'cancelled');
    }

    const updated = await transferEventAuthorById(id, toAuthorId);
    if (!updated) {
      return res.status(404).json({ error: 'Event not found' });
    }

    const admin = res.locals.author as AuthorIdentity;
    try {
      await recordEventHistory(id, admin.id, current, updated);
    } catch (historyError) {
      logRequestError(historyError, res.locals.requestId);
    }

    res.json({ event: updated });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to transfer event' });
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
