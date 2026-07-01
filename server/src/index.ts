import dotenv from 'dotenv';
import app from './app';
import { connect } from './db';

dotenv.config();

const port = Number(process.env.PORT || 3000);

async function start(): Promise<void> {
  await connect();
  app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
  });
}

start().catch((error) => {
  console.error('Failed to start server', error);
  process.exit(1);
});
