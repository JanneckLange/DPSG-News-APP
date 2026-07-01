import { initializeApp, cert, getApps, ServiceAccount } from 'firebase-admin/app';
import { getMessaging, Message } from 'firebase-admin/messaging';
import path from 'path';
import fs from 'fs';

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, '..', 'firebase', 'dpsg-news-dev-firebase-adminsdk-fbsvc-6523e23f5c.json');

if (!fs.existsSync(serviceAccountPath)) {
  throw new Error(`Firebase service account file not found: ${serviceAccountPath}`);
}

const serviceAccount = JSON.parse(
  fs.readFileSync(serviceAccountPath, 'utf8')
) as ServiceAccount;

if (!getApps().length) {
  initializeApp({
    credential: cert(serviceAccount),
  });
}

export type EventNotificationPayload = {
  title: string;
  description: string;
  eventId?: number | string;
  dv?: string;
  topic?: string;
};

function normalizeTopicName(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

export async function sendEventNotification({ title, description, eventId, dv, topic }: EventNotificationPayload): Promise<string> {
  const body = typeof description === 'string'
    ? description
    : description != null
      ? String(description)
      : '';
  const shortBody = body.length > 120 ? `${body.substring(0, 117)}...` : body;

  const topicName = topic != null && topic.trim().length > 0
    ? `events_${normalizeTopicName(dv ?? '')}_${normalizeTopicName(topic)}`
    : dv != null && dv.trim().length > 0
      ? `events_${normalizeTopicName(dv)}`
      : 'events';
  const message: Message = {
    topic: topicName,
    notification: {
      title: `Neues Event: ${title}`,
      body: shortBody,
    },
    data: {
      eventId: eventId?.toString() ?? '',
      type: 'event_created',
      dv: dv ?? '',
    },
  };

  console.log('Sending FCM event notification', {
    topic: message.topic,
    title: message.notification?.title,
    body: message.notification?.body,
    eventId,
  });

  const result = await getMessaging().send(message);
  console.log('FCM event notification sent successfully', { messageId: result });
  return result;
}
