import test from 'node:test';
import assert from 'node:assert/strict';
import { createWeatherHandler, fetchWeather } from './weather.js';

const now = Date.parse('2026-11-07T00:00:00Z');
const point = () => ({ dt: now / 1000, main: { temp: 30, temp_min: 29, temp_max: 31,
  feels_like: 32, humidity: 80, pressure: 1010 }, wind: { speed: 2 }, weather: [{ description: 'rain' }] });
const fetcher = change => async url => {
  const data = point();
  change?.(data);
  if (url.pathname.endsWith('forecast')) data.dt += 10800;
  return new Response(JSON.stringify(url.pathname.endsWith('forecast') ? { list: [data] } : data));
};

test('invalid and stale provider measurements never become current weather', async () => {
  for (const change of [p => p.main.humidity = 500, p => p.wind.speed = -1,
    p => p.dt -= 86400 * 30, p => p.dt += 3600, p => p.dt = 1e30,
    p => p.main.temp_min = 40, p => p.weather[0].description = 'x'.repeat(121)]) {
    await assert.rejects(fetchWeather('Muntinlupa', 'secret', fetcher(change), () => now),
      error => error.status === 502);
  }
});

test('oversized streamed provider bodies are cancelled before JSON parsing', async () => {
  let cancelled = 0;
  const fetchImpl = async () => {
    let chunks = 0;
    return new Response(new ReadableStream({
      pull(controller) {
        if (++chunks <= 2) controller.enqueue(new Uint8Array(131073));
        else controller.close();
      },
      cancel() { cancelled++; },
    }));
  };
  await assert.rejects(fetchWeather('Muntinlupa', 'secret', fetchImpl, () => now));
  assert.ok(cancelled > 0);
});

function response() {
  return { statusCode: 200, body: null, set() { return this; },
    status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; return this; } };
}
const req = { method: 'GET', query: { city: 'Muntinlupa' }, ip: '192.0.2.1', get: () => undefined };

test('disabled and unauthorized requests perform no database operations', async () => {
  let accesses = 0;
  const store = new Proxy({}, { get() { accesses++; throw Error('Unexpected database access'); } });
  for (const options of [{ enabled: () => false }, { authorize: async () => { throw Error('No attestation'); } }]) {
    const handler = createWeatherHandler({ store, getKey: () => 'secret', ...options });
    const res = response();
    await handler(req, res);
    assert.ok(res.statusCode === 403 || res.statusCode === 503);
  }
  assert.equal(accesses, 0);
});

test('a fresh but malformed cache entry is not returned to callers', async () => {
  const handler = createWeatherHandler({ getKey: () => 'secret', now: () => now, fetchImpl: fetcher(), store: {
    async rateLimit() {}, async get() { return { city: 'Manila', updatedAt: new Date(now).toISOString() }; },
    async reserve() {}, async put(_city, value) { return value; },
  } });
  const res = response();
  await handler(req, res);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.city, 'Muntinlupa');
  assert.equal(res.body.current.temperature, 30);
});

test('live provider forecasts must cover a future interval', async () => {
  const res = async url => {
    const data = point();
    if (url.pathname.endsWith('forecast')) data.dt -= 7200;
    return new Response(JSON.stringify(url.pathname.endsWith('forecast') ? { list: [data] } : data));
  };
  await assert.rejects(fetchWeather('Muntinlupa', 'secret', res, () => now), e => e.status === 502);
});
