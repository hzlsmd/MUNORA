import test from 'node:test';
import assert from 'node:assert/strict';
import { cities, createWeatherHandler, HttpError } from './weather.js';

const now = Date.parse('2026-11-06T08:00:00Z');
const provider = {
  dt: now / 1000, main: { temp: 30, feels_like: 32, humidity: 80, pressure: 1010, temp_min: 28, temp_max: 31 },
  weather: [{ description: 'light rain' }], wind: { speed: 2 },
};

function setup(options = {}) {
  const state = { calls: 0, reservations: 0, rateCalls: 0, cached: null };
  const store = {
    async rateLimit(identity) { state.rateCalls++; state.identity = identity; },
    async get() { return state.cached; },
    async put(city, value) { state.cached = value; },
    async reserve() { state.reservations++; },
    ...options.store,
  };
  const handler = createWeatherHandler({ store, getKey: () => 'test-secret', now: () => now,
    allowedOrigins: () => ['https://munora.example'],
    fetchImpl: async url => {
      state.calls++;
      assert.equal(url.searchParams.get('appid'), 'test-secret');
      assert.equal(url.searchParams.get('lat'), String(cities.Muntinlupa[0]));
      return new Response(JSON.stringify(url.pathname.endsWith('forecast')
        ? { list: [{ ...provider, dt: provider.dt + 10800 }] } : provider));
    }, ...options.handler });
  async function request(overrides = {}) {
    const req = { method: 'GET', query: { city: 'Muntinlupa' }, ip: '192.0.2.1', get: () => undefined, ...overrides };
    const res = { code: 200, headers: {}, body: null,
      set(k, v) { this.headers[k] = v; return this; },
      status(code) { this.code = code; return this; },
      json(body) { this.body = body; return this; }, send(body) { this.body = body; return this; } };
    await handler(req, res);
    return res;
  }
  return { state, request };
}

test('serves public weather without login and never returns provider credentials', async () => {
  const { request, state } = setup();
  const res = await request();
  assert.equal(res.code, 200);
  assert.equal(res.body.current.temperature, 30);
  assert.equal(res.body.hourly.length, 1);
  assert.equal(state.calls, 2);
  assert.equal(state.reservations, 1);
  assert.equal(JSON.stringify(res.body).includes('test-secret'), false);
  assert.match(state.identity, /^[a-f0-9]{64}$/);
});

test('cache and concurrent requests avoid repeated provider calls', async () => {
  const { request, state } = setup();
  await Promise.all([request(), request(), request()]);
  await request();
  assert.equal(state.calls, 2);
  assert.equal(state.rateCalls, 4);
});

test('expired cache refreshes instead of reporting old weather as current', async () => {
  const { request, state } = setup();
  state.cached = { updatedAt: new Date(now - 600001).toISOString() };
  const res = await request();
  assert.equal(res.code, 200);
  assert.equal(state.calls, 2);
});

test('invalid cities, duplicate city params and arbitrary query params make no upstream calls', async () => {
  const { request, state } = setup();
  for (const query of [{ city: 'London' }, { city: ['Muntinlupa'] }, { city: 'constructor' },
    { city: 'Muntinlupa', url: 'https://example.com' }]) {
    assert.equal((await request({ query })).code, 400);
  }
  assert.equal(state.calls, 0);
});

test('only configured browser origins receive CORS access', async () => {
  const { request, state } = setup();
  assert.equal((await request({ get: () => 'https://other.example' })).code, 403);
  assert.equal(state.calls, 0);
  const res = await request({ get: () => 'https://munora.example' });
  assert.equal(res.headers['Access-Control-Allow-Origin'], 'https://munora.example');
});

test('preflight and unsupported methods do not consume provider budget', async () => {
  const { request, state } = setup();
  assert.equal((await request({ method: 'OPTIONS' })).code, 204);
  assert.equal((await request({ method: 'POST' })).code, 405);
  assert.equal(state.calls, 0);
});

test('rate limit rejects before provider requests', async () => {
  const { request, state } = setup({ store: {
    async rateLimit() { throw new HttpError(429, 'Try again shortly.'); },
  } });
  const res = await request();
  assert.equal(res.code, 429);
  assert.equal(res.headers['Retry-After'], '60');
  assert.equal(state.calls, 0);
});

test('global budget stops new calls but allows fresh cached weather', async () => {
  const { request, state } = setup({ store: {
    async reserve() { throw new HttpError(503, 'Daily limit reached.'); },
  } });
  assert.equal((await request()).code, 503);
  assert.equal(state.calls, 0);
  state.cached = { city: 'Muntinlupa', updatedAt: new Date(now).toISOString() };
  assert.equal((await request()).code, 503);
});

test('upstream exceptions, status failures and malformed data do not leak secrets', async () => {
  for (const fetchImpl of [async () => { throw Error('https://provider?appid=test-secret'); },
    async () => ({ ok: false }), async () => ({ ok: true, json: async () => ({}) })]) {
    const { request } = setup({ handler: { fetchImpl } });
    const res = await request();
    assert.equal(res.code, 502);
    assert.equal(JSON.stringify(res.body).includes('test-secret'), false);
  }
});

test('missing secret fails without upstream traffic', async () => {
  const { request, state } = setup({ handler: { getKey: () => '' } });
  assert.equal((await request()).code, 503);
  assert.equal(state.calls, 0);
});
