import { Router, Request, Response } from 'express';
import { getEvents, getLayers, getTopics, listAuthors } from '../db';
import { getBuildInfo } from '../buildInfo';
import { logRequestError } from '../logger';
import { getViewerSession } from '../middleware/auth';
import { canManageWithinLayerScope } from '../middleware/scope';

export const publicRouter = Router();

publicRouter.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    build: getBuildInfo(),
  });
});

publicRouter.get('/api/layers', async (_req: Request, res: Response) => {
  try {
    const layers = await getLayers();
    const lastChange = layers.reduce((max, layer) => (layer.updatedAt > max ? layer.updatedAt : max), '');
    res.json({ layers, lastChange });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load layers' });
  }
});

publicRouter.get('/api/topics', async (req: Request, res: Response) => {
  try {
    const layerId = typeof req.query.layerId === 'string' ? Number(req.query.layerId) : undefined;
    const topics = await getTopics(Number.isInteger(layerId) && layerId! > 0 ? layerId : undefined);
    res.json({ topics });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load topics' });
  }
});

publicRouter.get('/api/events', async (req: Request, res: Response) => {
  try {
    const layerId = typeof req.query.layerId === 'string' ? Number(req.query.layerId) : undefined;
    const events = await getEvents(Number.isInteger(layerId) && layerId! > 0 ? layerId : undefined);
    const viewer = await getViewerSession(req);
    const authorMap = viewer?.author.isAdmin ? new Map((await listAuthors()).map((author) => [author.id, author.username])) : null;
    const currentAuthorId = viewer?.author.id ?? null;
    const viewerUsable = Boolean(viewer && viewer.requiresPasswordChange === false);

    const enrichedEvents = await Promise.all(events.map(async (event) => {
      const canManage = viewerUsable
        ? await canManageWithinLayerScope(viewer!.author, event.authorId, event.layerId)
        : false;
      return {
        ...event,
        canEdit: canManage,
        canDelete: canManage,
        canCreateUpdate: Boolean(viewerUsable && event.authorId === currentAuthorId),
        createdBy: authorMap && event.authorId != null ? authorMap.get(event.authorId) ?? null : undefined,
      };
    }));

    res.json({ events: enrichedEvents });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load events' });
  }
});
