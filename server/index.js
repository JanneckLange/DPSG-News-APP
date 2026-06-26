const express = require('express');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/api/events', (req, res) => {
  res.json({ events: [] });
});

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
