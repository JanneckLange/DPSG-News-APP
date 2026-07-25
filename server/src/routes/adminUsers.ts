import { Router, Request, Response } from 'express';
import {
  addAdminLayer,
  addAuthorLayerGrant,
  addAuthorTopicGrant,
  createAuthor,
  deleteAuthorById,
  getAdminLayerIds,
  getAuthorById,
  getAuthorLayerGrantIds,
  getAuthorTopicGrantIds,
  getTopicById,
  listAuthors,
  removeAdminLayer,
  removeAuthorLayerGrant,
  removeAuthorTopicGrant,
  resetAuthorPassword,
  setAuthorActive,
} from '../db';
import { logRequestError } from '../logger';
import { requireAdminSession, requireAuthorAuth, requirePasswordChangeCompleted } from '../middleware/auth';
import { isKnownLayerId, requireLayerScope, requireLayerScopeForAll } from '../middleware/scope';
import { parseLayerId, respondBadRequest } from '../middleware/validation';

export const adminUsersRouter = Router();

adminUsersRouter.get('/api/admin/users', async (req: Request, res: Response) => {
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

adminUsersRouter.post('/api/admin/users', async (req: Request, res: Response) => {
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

adminUsersRouter.patch('/api/admin/users/:id', async (req: Request, res: Response) => {
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

adminUsersRouter.delete('/api/admin/users/:id', async (req: Request, res: Response) => {
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

adminUsersRouter.post('/api/admin/users/:id/reset-password', async (req: Request, res: Response) => {
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

adminUsersRouter.post('/api/admin/users/:id/admin-layers', async (req: Request, res: Response) => {
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

adminUsersRouter.delete('/api/admin/users/:id/admin-layers/:layerId', async (req: Request, res: Response) => {
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

adminUsersRouter.post('/api/admin/users/:id/layer-grants', async (req: Request, res: Response) => {
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

adminUsersRouter.delete('/api/admin/users/:id/layer-grants/:layerId', async (req: Request, res: Response) => {
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

adminUsersRouter.post('/api/admin/users/:id/topic-grants', async (req: Request, res: Response) => {
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

adminUsersRouter.delete('/api/admin/users/:id/topic-grants/:topicId', async (req: Request, res: Response) => {
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
