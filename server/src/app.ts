import express, { Request, Response } from 'express';
import { createEvent, deleteAllEvents, deleteEventById, getEvents, EventInput } from './db';
import { sendEventNotification } from './fcm';

const app = express();
app.use(express.json());

app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok' });
});

app.get('/api/events', async (req: Request, res: Response) => {
  try {
    const dv = typeof req.query.dv === 'string' ? req.query.dv : undefined;
    const events = await getEvents(dv);
    res.json({ events });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Unable to load events' });
  }
});

app.post('/api/events', async (req: Request, res: Response) => {
  try {
    const { title, description, startDate, endDate, location, dv } = req.body as EventInput;
    if (!title || !description || !startDate || !endDate || !location || !dv) {
      return res.status(400).json({ error: 'Missing required event fields' });
    }

    const event = await createEvent({ title, description, startDate, endDate, location, dv });

    try {
      await sendEventNotification({
        title,
        description,
        eventId: event.id,
      });
    } catch (notificationError) {
      console.error('Failed to send event notification', notificationError);
    }

    res.status(201).json({ event });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Unable to create event' });
  }
});

app.delete('/api/events/:id', async (req: Request, res: Response) => {
  try {
    const id = Number(req.params.id);
    if (Number.isNaN(id) || id <= 0) {
      return res.status(400).json({ error: 'Invalid event id' });
    }

    const deleted = await deleteEventById(id);
    if (!deleted) {
      return res.status(404).json({ error: 'Event not found' });
    }

    res.status(204).end();
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Unable to delete event' });
  }
});

app.delete('/api/events', async (_req: Request, res: Response) => {
  try {
    const deletedCount = await deleteAllEvents();
    res.json({ deletedCount });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Unable to delete events' });
  }
});

export default app;
