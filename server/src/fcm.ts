import { initializeApp, cert, getApps, ServiceAccount } from 'firebase-admin/app';
import { getMessaging, Message } from 'firebase-admin/messaging';
import fs from 'fs';

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
let firebaseMessagingEnabled = false;

if (!serviceAccountPath) {
  console.warn(
    [
      '============================================================',
      'WARNING: Firebase is disabled because GOOGLE_APPLICATION_CREDENTIALS is not set.',
      'The server will start without push notifications.',
      '============================================================',
    ].join('\n'),
  );
} else if (!fs.existsSync(serviceAccountPath)) {
  console.warn(
    [
      '============================================================',
      `WARNING: Firebase is disabled because the service account file was not found: ${serviceAccountPath}`,
      'The server will start without push notifications.',
      '============================================================',
    ].join('\n'),
  );
} else {
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8')) as ServiceAccount;

  if (!getApps().length) {
    initializeApp({
      credential: cert(serviceAccount),
    });
  }

  firebaseMessagingEnabled = true;
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
  if (!firebaseMessagingEnabled) {
    console.warn('Skipping FCM event notification because Firebase is disabled.');
    return 'firebase-disabled';
  }

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

export type EventUpdateNotificationPayload = {
  eventId: number;
  eventTitle: string;
  message: string;
};

export async function sendEventUpdateNotification({ eventId, eventTitle, message }: EventUpdateNotificationPayload): Promise<string> {
  if (!firebaseMessagingEnabled) {
    console.warn('Skipping FCM event update notification because Firebase is disabled.');
    return 'firebase-disabled';
  }

  const shortBody = message.length > 120 ? `${message.substring(0, 117)}...` : message;
  const topicName = `event_${normalizeTopicName(String(eventId))}`;
  const fcmMessage: Message = {
    topic: topicName,
    notification: {
      title: `Update zu ${eventTitle}`,
      body: shortBody,
    },
    data: {
      eventId: String(eventId),
      type: 'event_update',
    },
  };

  console.log('Sending FCM event update notification', {
    topic: fcmMessage.topic,
    title: fcmMessage.notification?.title,
    body: fcmMessage.notification?.body,
    eventId,
  });

  const result = await getMessaging().send(fcmMessage);
  console.log('FCM event update notification sent successfully', { messageId: result });
  return result;
}
