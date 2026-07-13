import dotenv from 'dotenv';
import app from './app';
import { cleanupExpiredDrafts, connect } from './db';
import { getBuildInfo } from './buildInfo';
import { logError, logInfo } from './logger';

dotenv.config();

const port = Number(process.env.PORT || 3000);

async function start(): Promise<void> {
  await connect();
  app.listen(port, () => {
    const buildInfo = getBuildInfo();
    logInfo('Server started', {
      port,
      url: `http://localhost:${port}`,
      ...buildInfo,
    });
  });

  setInterval(() => {
    cleanupExpiredDrafts().catch((error) => {
      logError('Draft cleanup failed', { errorName: error instanceof Error ? error.name : 'UnknownError', errorMessage: error instanceof Error ? error.message : String(error) });
    });
  }, 10 * 60 * 1000);
}

start().catch((error) => {
  logError('Failed to start server', {
    errorName: error instanceof Error ? error.name : 'UnknownError',
    errorMessage: error instanceof Error ? error.message : String(error),
    stack: error instanceof Error ? error.stack : undefined,
  });
  process.exit(1);
});
