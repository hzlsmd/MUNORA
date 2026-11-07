import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAppCheck } from 'firebase-admin/app-check';
import { defineBoolean, defineInt, defineSecret, defineString } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';
import { createWeatherHandler } from './weather.js';
import { createFirestoreStore } from './store.js';

initializeApp();
const db = getFirestore();
const weatherKey = defineSecret('OPENWEATHER_API_KEY');
const webOrigins = defineString('ALLOWED_WEB_ORIGINS', { default: '' });
// Each cache miss reserves one pair of provider calls, including failed requests.
const dailyLimit = defineInt('WEATHER_DAILY_FETCH_LIMIT', { default: 1000 });
const enabled = defineBoolean('WEATHER_BACKEND_ENABLED', { default: false });
const store = createFirestoreStore(db);

export const weather = onRequest({
  region: 'asia-southeast1', invoker: 'public', secrets: [weatherKey],
  maxInstances: 3, timeoutSeconds: 30, memory: '256MiB',
}, createWeatherHandler({ store, getKey: () => weatherKey.value(),
  enabled: () => enabled.value(),
  authorize: async req => {
    const token = req.get('X-Firebase-AppCheck');
    if (!token) throw new Error('Missing attestation');
    await getAppCheck().verifyToken(token);
  },
  allowedOrigins: () => webOrigins.value().split(',').map(s => s.trim()).filter(Boolean),
  dailyLimit: () => dailyLimit.value(),
}));
