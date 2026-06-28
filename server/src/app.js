const express = require('express');
const { getEvents, createEvent } = require('./db');

const app = express();
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/api/events', async (req, res) => {
  try {
    const { dv } = req.query;
    const events = await getEvents(dv);
    res.json({ events });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Unable to load events' });
  }
});

app.post('/api/events', async (req, res) => {
  try {
    const { title, description, startDate, endDate, location, dv } = req.body;
    if (!title || !description || !startDate || !endDate || !location || !dv) {
      return res.status(400).json({ error: 'Missing required event fields' });
    }

    const event = await createEvent({ title, description, startDate, endDate, location, dv });
    res.status(201).json({ event });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Unable to create event' });
  }
});

module.exports = app;
