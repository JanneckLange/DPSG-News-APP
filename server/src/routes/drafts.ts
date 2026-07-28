import { Router, Request, Response } from 'express';
import {
  DraftInput,
  Layer,
  createAuthorDraft,
  deleteAuthorDraftById,
  getAuthorDrafts,
  getLayerById,
  getTopics,
  updateAuthorDraftById,
} from '../db';
import { logRequestError } from '../logger';
import { validateEventTextFields } from '../eventValidation';
import { requireAuthorAuth, requirePasswordChangeCompleted } from '../middleware/auth';
import { parseLayerId, respondBadRequest } from '../middleware/validation';

export const draftsRouter = Router();

draftsRouter.get('/api/author/drafts', async (req: Request, res: Response) => {
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

draftsRouter.post('/api/author/drafts', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    if (!requirePasswordChangeCompleted(res)) {
      return;
    }
    const { title, description, startDate, endDate, location, topicId, cta1Label, cta1Url, cta2Label, cta2Url, isPublic, publishAt, registrationDeadline } = req.body as DraftInput;
    const rawLayerId = (req.body as DraftInput).layerId;
    const layerId = rawLayerId != null ? parseLayerId(rawLayerId) : undefined;
    if (!title) {
      return respondBadRequest(req, res, 'Missing required draft fields');
    }
    let layer: Layer | null = null;
    if (rawLayerId != null) {
      layer = layerId ? await getLayerById(layerId) : null;
      if (!layer) {
        return respondBadRequest(req, res, 'Invalid layerId');
      }
    }
    const topicIds = layer ? (await getTopics(layer.id)).map((t) => t.id) : undefined;
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>, topicIds);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }

    const author = res.locals.author as { id: number };
    const draft = await createAuthorDraft({ title, description, startDate, endDate, location, layerId, topicId, cta1Label, cta1Url, cta2Label, cta2Url, isPublic, publishAt, registrationDeadline }, author.id);
    res.status(201).json({ draft });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to create draft' });
  }
});

draftsRouter.put('/api/author/drafts/:id', async (req: Request, res: Response) => {
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
    const { title, description, startDate, endDate, location, topicId, cta1Label, cta1Url, cta2Label, cta2Url, isPublic, publishAt, registrationDeadline } = req.body as DraftInput;
    const rawLayerId = (req.body as DraftInput).layerId;
    const layerId = rawLayerId != null ? parseLayerId(rawLayerId) : undefined;
    if (!title) {
      return respondBadRequest(req, res, 'Missing required draft fields');
    }
    let layer: Layer | null = null;
    if (rawLayerId != null) {
      layer = layerId ? await getLayerById(layerId) : null;
      if (!layer) {
        return respondBadRequest(req, res, 'Invalid layerId');
      }
    }
    const topicIds = layer ? (await getTopics(layer.id)).map((t) => t.id) : undefined;
    const fieldsCheck = validateEventTextFields(req.body as Record<string, unknown>, topicIds);
    if (!fieldsCheck.valid) {
      return respondBadRequest(req, res, fieldsCheck.error);
    }

    const author = res.locals.author as { id: number };
    const draft = await updateAuthorDraftById(id, author.id, { title, description, startDate, endDate, location, layerId, topicId, cta1Label, cta1Url, cta2Label, cta2Url, isPublic, publishAt, registrationDeadline });
    if (!draft) {
      return res.status(404).json({ error: 'Draft not found' });
    }
    res.json({ draft });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to update draft' });
  }
});

draftsRouter.delete('/api/author/drafts/:id', async (req: Request, res: Response) => {
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
