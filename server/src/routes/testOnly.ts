import { Router, Request, Response } from 'express';
import { clearAuthorData, clearDrafts, clearEvents, createAuthorForTesting } from '../db';
import { logRequestError } from '../logger';

export const testOnlyRouter = Router();

testOnlyRouter.post('/__test/reset', async (req: Request, res: Response) => {
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
testOnlyRouter.get('/__test/health', (_req: Request, res: Response) => {
  if (process.env.TEST_RUN !== 'true') {
    return res.status(404).json({ error: 'Not found' });
  }
  res.json({ ok: true, mode: 'test' });
});
