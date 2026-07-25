import { Router, Request, Response } from 'express';
import { createLayer, deleteLayer, getLayerAdmins, getLayerById, getLayerSubtree, updateLayer } from '../db';
import { logRequestError } from '../logger';
import { MAX_TITLE_LENGTH } from '../eventValidation';
import { requireAdminSession, requireAuthorAuth, requirePasswordChangeCompleted } from '../middleware/auth';
import { isKnownLayerId, requireLayerScope } from '../middleware/scope';
import { isForeignKeyViolation, isUniqueViolation, parseLayerId, respondBadRequest } from '../middleware/validation';

export const adminLayersRouter = Router();

adminLayersRouter.get('/api/admin/layers', async (req: Request, res: Response) => {
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
    const author = res.locals.author as { adminLayerIds?: number[] } | undefined;
    if (!author?.adminLayerIds?.length) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    const layers = await getLayerSubtree(author.adminLayerIds);
    res.json({ layers });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load layers' });
  }
});

adminLayersRouter.get('/api/admin/layers/:id/admins', async (req: Request, res: Response) => {
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
    const id = parseLayerId(req.params.id);
    if (id === undefined) {
      return respondBadRequest(req, res, 'Invalid layer id');
    }
    if (!await isKnownLayerId(id)) {
      return res.status(404).json({ error: 'Layer not found' });
    }
    if (!await requireLayerScope(res, id)) {
      return;
    }
    const admins = await getLayerAdmins(id);
    res.json({ admins });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load layer admins' });
  }
});

adminLayersRouter.post('/api/admin/layers', async (req: Request, res: Response) => {
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
    const parentId = req.body.parentId != null ? parseLayerId(req.body.parentId) : null;
    if (!name || name.length > MAX_TITLE_LENGTH) {
      return respondBadRequest(req, res, `name is required and must not exceed ${MAX_TITLE_LENGTH} characters`);
    }
    if (req.body.parentId != null && (parentId == null || !await isKnownLayerId(parentId))) {
      return respondBadRequest(req, res, 'Invalid parentId');
    }
    if (!await requireLayerScope(res, parentId)) {
      return;
    }
    const layer = await createLayer({ name, parentId });
    res.status(201).json({ layer });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return res.status(409).json({ error: 'A layer with this name already exists at this position' });
    }
    if (isForeignKeyViolation(error)) {
      return respondBadRequest(req, res, 'Invalid parentId');
    }
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create layer' });
  }
});

adminLayersRouter.patch('/api/admin/layers/:id', async (req: Request, res: Response) => {
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
      return respondBadRequest(req, res, 'Invalid layer id');
    }
    const existing = await getLayerById(id);
    if (!existing) {
      return res.status(404).json({ error: 'Layer not found' });
    }
    if (!await requireLayerScope(res, id)) {
      return;
    }
    const name = typeof req.body.name === 'string' ? req.body.name.trim() : existing.name;
    if (!name || name.length > MAX_TITLE_LENGTH) {
      return respondBadRequest(req, res, `name is required and must not exceed ${MAX_TITLE_LENGTH} characters`);
    }
    const updated = await updateLayer(id, { name, parentId: existing.parentId });
    if (updated.status === 'not_found') {
      return res.status(404).json({ error: 'Layer not found' });
    }
    if (updated.status === 'is_root') {
      return res.status(409).json({ error: 'Der Wurzel-Layer (Bundesverband) kann keinem anderen Layer zugeordnet werden' });
    }
    if (updated.status === 'would_create_second_root') {
      return res.status(409).json({ error: 'Layer kann nicht zu einem zweiten Wurzel-Layer werden' });
    }
    res.json({ layer: updated.layer });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return res.status(409).json({ error: 'A layer with this name already exists at this position' });
    }
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to update layer' });
  }
});

adminLayersRouter.delete('/api/admin/layers/:id', async (req: Request, res: Response) => {
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
      return respondBadRequest(req, res, 'Invalid layer id');
    }
    if (!await isKnownLayerId(id)) {
      return res.status(404).json({ error: 'Layer not found' });
    }
    if (!await requireLayerScope(res, id)) {
      return;
    }
    const result = await deleteLayer(id);
    if (result === 'not_found') {
      return res.status(404).json({ error: 'Layer not found' });
    }
    if (result === 'is_root') {
      return res.status(409).json({ error: 'Der Wurzel-Layer (Bundesverband) kann nicht gelöscht werden' });
    }
    if (result === 'has_children') {
      return res.status(409).json({ error: 'Layer has child layers and cannot be deleted' });
    }
    if (result === 'in_use') {
      return res.status(409).json({ error: 'Layer is referenced by events or drafts and cannot be deleted' });
    }
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete layer' });
  }
});
