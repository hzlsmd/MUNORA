import { randomUUID } from 'node:crypto';
import { HttpError } from './errors.js';
import { validateWeather } from './validation.js';

export function createFirestoreStore(db) {
  const collection = db.collection('weatherInternal');
  const expiry = now => new Date(now + 172800000);
  return {
    async get(city) { return (await collection.doc(`cache-${city}`).get()).data()?.payload; },
    async acquire(city, now) {
      const ref = collection.doc(`refresh-${city}`);
      const circuit = collection.doc('provider-circuit');
      const owner = randomUUID();
      return db.runTransaction(async tx => {
        const lease = (await tx.get(ref)).data();
        const paused = (await tx.get(circuit)).data();
        const until = Math.max(lease?.until || 0, paused?.until || 0);
        if (until > now) throw new HttpError(503, 'Weather updates are temporarily paused. Try again shortly.', Math.ceil((until - now) / 1000));
        tx.set(ref, { owner, until: now + 30000, expiresAt: expiry(now) });
        if (paused?.failures > 0) tx.set(circuit, { ...paused, until: now + 30000, probeOwner: owner });
        return owner;
      });
    },
    async put(city, payload, owner, now) {
      const ref = collection.doc(`cache-${city}`);
      const leaseRef = collection.doc(`refresh-${city}`);
      return db.runTransaction(async tx => {
        const lease = (await tx.get(leaseRef)).data();
        let previous = (await tx.get(ref)).data()?.payload;
        const circuitRef = collection.doc('provider-circuit');
        const circuit = (await tx.get(circuitRef)).data();
        if (lease?.owner !== owner || lease.until < now) throw new HttpError(503, 'Weather refresh ownership expired.');
        validateWeather(payload, city, now);
        try { validateWeather(previous, city, now); }
        catch { previous = undefined; }
        const newer = previous && (Date.parse(previous.observedAt) > Date.parse(payload.observedAt) ||
          (previous.observedAt === payload.observedAt && Date.parse(previous.updatedAt) > Date.parse(payload.updatedAt)));
        const result = newer ? previous : payload;
        if (!newer) tx.set(ref, { payload });
        tx.set(leaseRef, { owner, until: now, expiresAt: expiry(now) });
        if (circuit?.probeOwner === owner) tx.set(circuitRef, { until: now, failures: 0, expiresAt: expiry(now) });
        return result;
      });
    },
    async release(city, owner, now, seconds, providerFailure = false) {
      const ref = collection.doc(`refresh-${city}`);
      return db.runTransaction(async tx => {
        const lease = (await tx.get(ref)).data();
        const circuitRef = collection.doc('provider-circuit');
        const circuit = (await tx.get(circuitRef)).data();
        if (lease?.owner !== owner) return;
        const failures = (circuit?.failures || 0) + 1;
        const delay = providerFailure || seconds >= 300
          ? Math.max(seconds, Math.min(900, 60 * 2 ** Math.min(failures - 1, 4))) : seconds;
        tx.set(ref, { owner, until: now + delay * 1000, expiresAt: expiry(now) });
        if (providerFailure || seconds >= 300 || circuit?.probeOwner === owner) {
          tx.set(circuitRef, { until: Math.max(circuit?.until || 0, now + delay * 1000), failures, expiresAt: expiry(now) });
        }
        return delay;
      });
    },
    async rateLimit(identity, now) {
      const ref = collection.doc(`rate-${identity}`);
      await db.runTransaction(async tx => {
        const data = (await tx.get(ref)).data();
        const window = Math.floor(now / 60000);
        const count = data?.window === window ? data.count : 0;
        if (count >= 30) throw new HttpError(429, 'Too many requests. Try again shortly.');
        tx.set(ref, { window, count: count + 1, expiresAt: expiry(now) });
      });
    },
    async reserve(now, limit) {
      const ref = collection.doc(`budget-${new Date(now).toISOString().slice(0, 10)}`);
      await db.runTransaction(async tx => {
        const count = (await tx.get(ref)).data()?.count ?? 0;
        if (count >= limit) throw new HttpError(503, 'Weather updates are temporarily paused. Try again later.');
        tx.set(ref, { count: count + 1, expiresAt: expiry(now) });
      });
    },
  };
}
