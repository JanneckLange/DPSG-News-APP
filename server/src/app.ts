import express, { Request, Response } from 'express';
import { randomUUID } from 'crypto';
import { createEvent, deleteAllEvents, deleteEventById, getEvents, EventInput } from './db';
import { sendEventNotification } from './fcm';
import { getBuildInfo } from './buildInfo';
import { logInfo, logRequest, logRequestError } from './logger';

const DV_TREE = {
  lastTreeChange: '2026-07-01T00:00:00Z',
  dvs: [
    { name: 'Aachen', url: 'http://www.dpsg-ac.de/' },
    { name: 'Augsburg', url: 'http://www.dpsg-augsburg.de/' },
    { name: 'Bamberg', url: 'http://www.dpsg-bamberg.de/' },
    { name: 'Berlin', url: 'http://www.dpsg-dv-berlin.de/' },
    { name: 'Eichstätt', url: 'http://www.dpsg-eichstaett.de/' },
    { name: 'Essen', url: 'http://www.dpsg-essen.de/' },
    { name: 'Erfurt', url: 'https://dpsg-thueringen.de/' },
    { name: 'Freiburg', url: 'http://www.dpsg-freiburg.de/' },
    { name: 'Fulda', url: 'http://www.dpsg-fulda.de/' },
    { name: 'Hamburg', url: 'http://www.dpsg-hamburg.de/', groups: ['Wölflinge', 'Jungpfadfinder', 'Pfadfinder', 'Rover', 'AK Aus-& Weiterbildung'] },
    { name: 'Hildesheim', url: 'http://www.dpsg-hildesheim.de/' },
    { name: 'Köln', url: 'http://www.dpsg-koeln.de/' },
    { name: 'Limburg', url: 'http://www.dpsg-limburg.de/' },
    { name: 'Magdeburg', url: 'http://www.dpsg-dv-magdeburg.de/' },
    { name: 'Mainz', url: 'http://www.dpsg-mainz.de/' },
    { name: 'München-Freising', url: 'http://www.dpsg1300.de/' },
    { name: 'Münster', url: 'https://dpsgmuenster.de/' },
    { name: 'Osnabrück', url: 'https://dpsg-os.de/' },
    { name: 'Paderborn', url: 'http://www.dpsg-paderborn.de/' },
    { name: 'Passau', url: 'http://www.dpsg-passau.de/' },
    { name: 'Regensburg', url: 'http://www.dpsg-regensburg.de/' },
    { name: 'Rottenburg-Stuttgart', url: 'http://www.dpsg-rottenburg.de/' },
    { name: 'Speyer', url: 'http://www.dpsg-speyer.org/' },
    { name: 'Trier', url: 'http://www.dpsg-trier.de/' },
    { name: 'Würzburg', url: 'http://www.dpsg-wuerzburg.de/' },
  ],
};

function normalizeTopicName(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

const app = express();
app.use(express.json());
app.use((req: Request, res: Response, next) => {
  const startedAt = Date.now();
  const headerRequestId = req.header('x-request-id');
  const requestId = headerRequestId && headerRequestId.trim() ? headerRequestId.trim() : randomUUID();
  res.locals.requestId = requestId;
  res.setHeader('x-request-id', requestId);

  res.on('finish', () => {
    logRequest({
      requestId,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs: Date.now() - startedAt,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });
  });

  next();
});

app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    treeVersion: DV_TREE.lastTreeChange,
    build: getBuildInfo(),
  });
});

app.get('/api/dvs', (_req: Request, res: Response) => {
  res.json({
    lastTreeChange: DV_TREE.lastTreeChange,
    dvs: DV_TREE.dvs,
  });
});

app.get('/api/events', async (req: Request, res: Response) => {
  try {
    const dv = typeof req.query.dv === 'string' ? req.query.dv : undefined;
    const events = await getEvents(dv);
    res.json({ events });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load events' });
  }
});

app.post('/api/events', async (req: Request, res: Response) => {
  try {
    const { title, description, startDate, endDate, location, dv, topic } = req.body as EventInput;
    if (!title || !description || !startDate || !endDate || !location || !dv) {
      return res.status(400).json({ error: 'Missing required event fields' });
    }

    const event = await createEvent({ title, description, startDate, endDate, location, dv, topic });

    logInfo('Created event, sending push notification', {
      requestId: res.locals.requestId,
      eventId: event.id,
      title,
      location,
      dv,
      topic,
    });

    try {
      await sendEventNotification({
        title,
        description,
        eventId: event.id,
        dv,
        topic,
      });
      logInfo('Push notification request completed for event', {
        requestId: res.locals.requestId,
        eventId: event.id,
      });
    } catch (notificationError) {
      logRequestError(notificationError, res.locals.requestId);
    }

    res.status(201).json({ event });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
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
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete event' });
  }
});

app.delete('/api/events', async (_req: Request, res: Response) => {
  try {
    const deletedCount = await deleteAllEvents();
    res.json({ deletedCount });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to delete events' });
  }
});

export default app;
