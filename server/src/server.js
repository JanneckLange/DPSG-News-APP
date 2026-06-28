const dotenv = require('dotenv');
const app = require('./app');
const { connect } = require('./db');

dotenv.config();

const port = process.env.PORT || 3000;

async function start() {
  await connect();
  app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
  });
}

start().catch((error) => {
  console.error('Failed to start server', error);
  process.exit(1);
});
