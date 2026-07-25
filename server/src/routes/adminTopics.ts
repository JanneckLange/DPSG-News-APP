import { Router, Request, Response } from 'express';
import { createTopic, deleteTopic, getTopicById, updateTopic } from '../db';
import { logRequestError } from '../logger';
import { MAX_TITLE_LENGTH } from '../eventValidation';
import { requireAdminSession, requireAuthorAuth, requirePasswordChangeCompleted } from '../middleware/auth';
import { isKnownLayerId, requireLayerScope } from '../middleware/scope';
import { isForeignKeyViolation, isUniqueViolation, parseLayerId, respondBadRequest } from '../middleware/validation';

export const adminTopicsRouter = Router();

adminTopicsRouter.post('/api/admin/topics', async (req: Request, res: Response) => {
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
    const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
    const layerId = parseLayerId(req.body.layerId);
    if (!name || name.length > MAX_TITLE_LENGTH) {
      return respondBadRequest(req, res, `name is required and must not exceed ${MAX_TITLE_LENGTH} characters`);
    }
    if (!layerId || !await isKnownLayerId(layerId)) {
      return respondBadRequest(req, res, 'Invalid layerId');
    }
    if (!await requireLayerScope(res, layerId)) {
      return;
    }
    const topic = await createTopic({ name, layerId });
    res.status(201).json({ topic });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return res.status(409).json({ error: 'A topic with this name already exists for this layer' });
    }
    if (isForeignKeyViolation(error)) {
      return respondBadRequest(req, res, 'Invalid layerId');
    }
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create topic' });
  }
});

adminTopicsRouter.patch('/api/admin/topics/:id', async (req: Request, res: Response) => {
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
      return respondBadRequest(req, res, 'Invalid topic id');
    }
    const existing = await getTopicById(id);
    if (!existing) {
      return res.status(404).json({ error: 'Topic not found' });
    }
    if (!await requireLayerScope(res, existing.layerId)) {
      return;
    }
    const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
    if (!name || name.length > MAX_TITLE_LENGTH) {
      return respondBadRequest(req, res, `name is required and must not exceed ${MAX_TITLE_LENGTH} characters`);
    }
    const updated = await updateTopic(id, name);
    if (!updated) {
      return res.status(404).json({ error: 'Topic not found' });
    }
    res.json({ topic: updated });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return res.status(409).json({ error: 'A topic with this name already exists for this layer' });
    }
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to update topic' });
  }
});

adminTopicsRouter.delete('/api/admin/topics/:id', async (req: Request, res: Response) => {
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
      return respondBadRequest(req, res, 'Invalid topic id');
    }
    const existing = await getTopicById(id);
    if (!existing) {
      return res.status(404).json({ error: 'Topic not found' });
    }
    if (!await requireLayerScope(res, existing.layerId)) {
      return;
    }
    const result = await deleteTopic(id);
    if (result === 'not_found') {
      return res.status(404).json({ error: 'Topic not found' });
    }
    if (result === 'in_use') {
      return res.status(409).json({ error: 'Topic is referenced by events or drafts and cannot be deleted' });
    }
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete topic' });
  }
});
