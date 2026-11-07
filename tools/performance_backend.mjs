import { performance } from 'node:perf_hooks';
import assert from 'node:assert/strict';
import { createWeatherHandler } from '../functions/weather.js';

const epoch = Date.now();
const current = { dt: epoch / 1000, main: { temp: 30, feels_like: 32, humidity: 80,
  pressure: 1010, temp_min: 29, temp_max: 31 }, wind: { speed: 2 }, weather: [{ description: 'rain' }] };
let cache;
const counters = { provider: 0, reads: 0, writes: 0, rate: 0, budget: 0 };
const store = {
  async rateLimit() { counters.rate++; },
  async get() { counters.reads++; return cache; },
  async put(_city, value) { counters.writes++; cache = value; return value; },
  async reserve() { counters.budget++; },
};
const handler = createWeatherHandler({ store, getKey: () => 'fixture-not-a-credential', now: () => epoch,
  fetchImpl: async url => {
    counters.provider++;
    return new Response(JSON.stringify(url.pathname.endsWith('forecast')
      ? { list: Array.from({ length: 40 }, (_, i) => ({ ...current, dt: epoch / 1000 + i * 10800 })) }
      : current));
  },
});
const req = { method: 'GET', query: { city: 'Muntinlupa' }, ip: '192.0.2.1', get: () => undefined };
async function request() {
  const res = { code: 200, body: null, set() { return this; }, status(code) { this.code = code; return this; }, json(body) { this.body = body; return this; } };
  await handler(req, res);
  assert.equal(res.code, 200);
  return res;
}
const start = performance.now();
const cold = await request();
const coldMs = performance.now() - start;
const samples = [];
for (let i = 0; i < 1000; i++) {
  const begin = performance.now();
  await request();
  samples.push(performance.now() - begin);
}
samples.sort((a, b) => a - b);
const warmCounts = { ...counters };
cache = null;
const burstStart = performance.now();
await Promise.all(Array.from({ length: 100 }, () => request()));
assert.equal(counters.provider - warmCounts.provider, 2);
assert.equal(counters.writes - warmCounts.writes, 1);
console.log(JSON.stringify({
  scope: 'In-process Node handler, 40-point fixture, in-memory I/O; not Firestore/provider latency or deployed load testing',
  node: process.version, coldMs, warm1000: { p50Ms: samples[500], p95Ms: samples[950], counters: warmCounts },
  burst100: { durationMs: performance.now() - burstStart, providerCalls: counters.provider - warmCounts.provider,
    cacheWrites: counters.writes - warmCounts.writes }, responseBytes: Buffer.byteLength(JSON.stringify(cold.body)),
}, null, 2));
