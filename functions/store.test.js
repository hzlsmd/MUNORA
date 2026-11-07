import test from 'node:test';
import assert from 'node:assert/strict';

// Serialize transaction callbacks as Firestore does at successful commit; this
// exercises our adapter, not the SDK's contention/retry implementation.
function database() {
  const values = new Map();
  let queue = Promise.resolve();
  return {
    values,
    collection() { return { doc(id) { return { id, async get() { return { data: () => values.get(id) }; } }; } }; },
    runTransaction(fn) {
      const work = queue.then(() => fn({
        async get(ref) { return { data: () => values.get(ref.id) }; },
        set(ref, value) { values.set(ref.id, value); },
      }));
      queue = work.catch(() => {});
      return work;
    },
  };
}
const now = Date.parse('2026-11-07T00:00:00Z');
const weather = (time = now) => ({ city: 'Muntinlupa', updatedAt: new Date(time).toISOString(),
  observedAt: new Date(time).toISOString(), current: { temperature: 30, feelsLike: 32,
    humidity: 80, pressure: 1010, wind: 2, condition: 'rain' },
  hourly: [{ at: new Date(time + 10800000).toISOString(), temperature: 30, low: 29, high: 31, condition: 'rain' }] });

test('invalid privileged cache cannot defeat a valid refresh', async () => {
  const { createFirestoreStore } = await import('./store.js');
  const db = database();
  const store = createFirestoreStore(db);
  const corrupt = weather(now + 86400000);
  corrupt.current.humidity = 500;
  db.values.set('cache-Muntinlupa', { payload: corrupt });
  const owner = await store.acquire('Muntinlupa', now);
  assert.deepEqual(await store.put('Muntinlupa', weather(), owner, now), weather());
});

test('transport outages use a shared escalating circuit with one recovery probe', async () => {
  const { createFirestoreStore } = await import('./store.js');
  const store = createFirestoreStore(database());
  const owner = await store.acquire('Muntinlupa', now);
  await store.release('Muntinlupa', owner, now, 60, true);
  await assert.rejects(store.acquire('Manila', now + 30000), e => e.status === 503);
  const probe = await store.acquire('Muntinlupa', now + 60001);
  await assert.rejects(store.acquire('Manila', now + 60001), e => e.status === 503);
  assert.equal(await store.release('Muntinlupa', probe, now + 60001, 60, true), 120);
  await assert.rejects(store.acquire('Manila', now + 120002), e => e.status === 503);
  const recovered = await store.acquire('Muntinlupa', now + 180002);
  await store.put('Muntinlupa', weather(now + 180002), recovered, now + 180002);
  assert.ok(await store.acquire('Manila', now + 180003));
});

test('only one instance owns a refresh; an expired owner cannot publish', async () => {
  const { createFirestoreStore } = await import('./store.js');
  const db = database();
  const a = createFirestoreStore(db);
  const b = createFirestoreStore(db);
  const owner = await a.acquire('Muntinlupa', now);
  await assert.rejects(b.acquire('Muntinlupa', now), e => e.status === 503);
  const successor = await b.acquire('Muntinlupa', now + 31000);
  const payload = weather(now + 31000);
  await b.put('Muntinlupa', payload, successor, now + 31000);
  await assert.rejects(a.put('Muntinlupa', payload, owner, now + 32000), e => e.status === 503);
  assert.deepEqual(await a.get('Muntinlupa'), payload);
});

test('outage cooldown persists across instances and then permits recovery', async () => {
  const { createFirestoreStore } = await import('./store.js');
  const db = database();
  const a = createFirestoreStore(db);
  const owner = await a.acquire('Muntinlupa', now);
  await a.release('Muntinlupa', owner, now, 60);
  const b = createFirestoreStore(db);
  await assert.rejects(b.acquire('Muntinlupa', now + 59000), e => e.status === 503);
  assert.ok(await b.acquire('Muntinlupa', now + 60001));
});

test('provider auth/quota failures pause all cities, not only one city', async () => {
  const { createFirestoreStore } = await import('./store.js');
  const store = createFirestoreStore(database());
  const owner = await store.acquire('Muntinlupa', now);
  await store.release('Muntinlupa', owner, now, 300);
  await assert.rejects(store.acquire('Manila', now + 60001), e => e.status === 503);
  assert.ok(await store.acquire('Manila', now + 300001));
});

test('rate windows and daily budgets enforce actual transaction state', async () => {
  const { createFirestoreStore } = await import('./store.js');
  const store = createFirestoreStore(database());
  for (let i = 0; i < 30; i++) await store.rateLimit('identity', now);
  await assert.rejects(store.rateLimit('identity', now), e => e.status === 429);
  await store.rateLimit('identity', now + 60000);
  await store.reserve(now, 2);
  await store.reserve(now, 2);
  await assert.rejects(store.reserve(now, 2), e => e.status === 503);
  await store.reserve(now + 86400000, 2);
});

test('a newer observation is never replaced by an older observation', async () => {
  const { createFirestoreStore } = await import('./store.js');
  const db = database();
  const store = createFirestoreStore(db);
  const existing = weather();
  db.values.set('cache-Muntinlupa', { payload: existing });
  const owner = await store.acquire('Muntinlupa', now);
  const old = weather(now - 1000);
  old.updatedAt = new Date(now + 1000).toISOString();
  assert.deepEqual(await store.put('Muntinlupa', old, owner, now + 1000), existing);
  assert.deepEqual(await store.get('Muntinlupa'), existing);
});
