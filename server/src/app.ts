import express, { NextFunction, Request, Response } from 'express';
import { logRequestError } from './logger';
import { requestContextMiddleware } from './middleware/requestContext';
import { globalRateLimiter } from './middleware/rateLimit';
import { publicRouter } from './routes/public';
import { authRouter } from './routes/auth';
import { eventsRouter } from './routes/events';
import { draftsRouter } from './routes/drafts';
import { adminUsersRouter } from './routes/adminUsers';
import { adminLayersRouter } from './routes/adminLayers';
import { adminTopicsRouter } from './routes/adminTopics';
import { testOnlyRouter } from './routes/testOnly';

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
app.use(eventsRouter);
app.use(draftsRouter);
app.use(adminUsersRouter);
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
