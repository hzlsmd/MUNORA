import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { defineInt, defineSecret, defineString } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';
import { createWeatherHandler, HttpError } from './weather.js';

initializeApp();
const db = getFirestore();
const weatherKey = defineSecret('OPENWEATHER_API_KEY');
const webOrigins = defineString('ALLOWED_WEB_ORIGINS', { default: '' });
// Each cache miss reserves one pair of provider calls, including failed requests.
const dailyLimit = defineInt('WEATHER_DAILY_FETCH_LIMIT', { default: 1000 });
const collection = db.collection('weatherInternal');

const store = {
  async get(city) { return (await collection.doc(`cache-${city}`).get()).data()?.payload; },
  async put(city, payload) { await collection.doc(`cache-${city}`).set({ payload }); },
  async rateLimit(identity, now) {
    const ref = collection.doc(`rate-${identity}`);
    await db.runTransaction(async tx => {
      const data = (await tx.get(ref)).data();
      const window = Math.floor(now / 60000);
      const count = data?.window === window ? data.count : 0;
      if (count >= 30) throw new HttpError(429, 'Too many requests. Try again shortly.');
      tx.set(ref, { window, count: count + 1, expiresAt: Timestamp.fromMillis(now + 86400000) });
    });
  },
  async reserve(now, limit) {
    const ref = collection.doc(`budget-${new Date(now).toISOString().slice(0, 10)}`);
    await db.runTransaction(async tx => {
      const count = (await tx.get(ref)).data()?.count ?? 0;
      if (count >= limit) throw new HttpError(503, 'Weather updates are temporarily paused. Try again later.');
      tx.set(ref, { count: count + 1, expiresAt: Timestamp.fromMillis(now + 172800000) });
    });
  },
};

export const weather = onRequest({
  region: 'asia-southeast1', invoker: 'public', secrets: [weatherKey],
  maxInstances: 3, timeoutSeconds: 30, memory: '256MiB',
}, createWeatherHandler({ store, getKey: () => weatherKey.value(),
  allowedOrigins: () => webOrigins.value().split(',').map(s => s.trim()).filter(Boolean),
  dailyLimit: () => dailyLimit.value(),
}));
