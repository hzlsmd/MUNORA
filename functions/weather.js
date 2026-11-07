import { createHmac } from 'node:crypto';
import { HttpError } from './errors.js';
import { boundedJson, number, validateWeather } from './validation.js';
export { HttpError } from './errors.js';

// Coordinates keep requests inside the supported NCR area and avoid ambiguous names.
export const cities = Object.freeze({
  Muntinlupa: [14.4081, 121.0415], Manila: [14.5995, 120.9842],
  'Quezon City': [14.6760, 121.0437], Makati: [14.5547, 121.0244],
  Taguig: [14.5176, 121.0509], Pasig: [14.5764, 121.0851],
  Pasay: [14.5378, 121.0014], Mandaluyong: [14.5794, 121.0359],
  Marikina: [14.6507, 121.1029], Caloocan: [14.6488, 120.9841],
  Malabon: [14.6681, 120.9658], Navotas: [14.6667, 120.9417],
  Valenzuela: [14.7011, 120.9830], 'Las Pinas': [14.4445, 120.9939],
  Paranaque: [14.4793, 121.0198], 'San Juan': [14.6019, 121.0355],
  Pateros: [14.5445, 121.0680],
});

const numeric = value => {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new HttpError(502, 'Weather data is temporarily unavailable.');
  }
  return value;
};

export async function fetchWeather(city, key, fetchImpl = fetch, now = Date.now) {
  if (!key) throw new HttpError(503, 'Weather service is not configured.');
  const [lat, lon] = cities[city];
  const request = async path => {
    const url = new URL(`https://api.openweathermap.org/data/2.5/${path}`);
    url.search = new URLSearchParams({ lat, lon, appid: key, units: 'metric' });
    let response;
    try {
      response = await fetchImpl(url, { signal: AbortSignal.timeout(8000) });
    } catch {
      throw new HttpError(502, 'Weather provider is temporarily unavailable.');
    }
    if (!response.ok) throw new HttpError(502, 'Weather provider is temporarily unavailable.',
      [401, 403, 429].includes(response.status) ? 300 : 60);
    try {
      const body = await boundedJson(response);
      if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error('Invalid body');
      return body;
    }
    catch { throw new HttpError(502, 'Weather data is temporarily unavailable.'); }
  };
  const [current, forecast] = await Promise.all([request('weather'), request('forecast')]);
  const description = item => {
    const value = item.weather?.[0]?.description;
    if (typeof value !== 'string' || value.length > 120) {
      throw new HttpError(502, 'Weather data is temporarily unavailable.');
    }
    return value;
  };
  if (!Array.isArray(forecast.list) || forecast.list.length === 0 || forecast.list.length > 40) {
    throw new HttpError(502, 'Weather data is temporarily unavailable.');
  }
  try {
    const result = {
      city,
      updatedAt: new Date(now()).toISOString(),
      observedAt: new Date(numeric(current.dt) * 1000).toISOString(),
      current: {
        temperature: numeric(current.main?.temp), feelsLike: numeric(current.main?.feels_like),
        humidity: numeric(current.main?.humidity), pressure: numeric(current.main?.pressure),
        wind: numeric(current.wind?.speed), condition: description(current),
      },
      hourly: forecast.list.map(item => ({
        at: new Date(numeric(item.dt) * 1000).toISOString(),
        temperature: numeric(item.main?.temp), low: numeric(item.main?.temp_min),
        high: numeric(item.main?.temp_max), condition: description(item),
      })),
    };
    return validateWeather(result, city, now());
  } catch {
    throw new HttpError(502, 'Weather data is temporarily unavailable.');
  }
}

export function createWeatherHandler({ store, getKey, allowedOrigins = () => [],
  dailyLimit = () => 1000, enabled = () => true, authorize = async () => {}, fetchImpl = fetch, now = Date.now }) {
  const pending = new Map();
  return async (req, res) => {
    res.set('Cache-Control', 'no-store');
    res.set('Vary', 'Origin');
    const origin = req.get('origin');
    if (origin && !allowedOrigins().includes(origin)) {
      return res.status(403).json({ error: 'This web origin is not enabled.' });
    }
    if (origin) res.set('Access-Control-Allow-Origin', origin);
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'GET');
      res.set('Access-Control-Allow-Headers', 'X-Firebase-AppCheck');
      return res.status(204).send('');
    }
    if (req.method !== 'GET') {
      res.set('Allow', 'GET, OPTIONS');
      return res.status(405).json({ error: 'Use GET.' });
    }
    const city = req.query.city ?? 'Muntinlupa';
    if (typeof city !== 'string' || !Object.hasOwn(cities, city) ||
        Object.keys(req.query).some(key => key !== 'city')) {
      return res.status(400).json({ error: 'Choose a supported NCR city.' });
    }
    try {
      if (!enabled()) throw new HttpError(503, 'Weather service is temporarily unavailable.');
      try { await authorize(req); }
      catch { throw new HttpError(403, 'App verification is required.'); }
      const key = getKey();
      if (!key) throw new HttpError(503, 'Weather service is not configured.');
      // Never store raw IP addresses. The platform supplies req.ip; ignore client headers.
      const identity = createHmac('sha256', key).update(req.ip || 'unknown').digest('hex');
      await store.rateLimit(identity, now());
      const cached = await store.get(city);
      if (cached && now() - Date.parse(cached.updatedAt) < 600000 &&
          Date.parse(cached.updatedAt) <= now()) {
        try { validateWeather(cached, city, now()); return res.status(200).json(cached); }
        catch { /* Refresh invalid privileged/migration cache data. */ }
      }
      if (!pending.has(city)) {
        const work = (async () => {
          const owner = await store.acquire?.(city, now());
          try {
            number(dailyLimit(), 1, 100000);
            await store.reserve(now(), dailyLimit());
            const data = await fetchWeather(city, key, fetchImpl, now);
            const published = await store.put(city, data, owner, now()) || data;
            return validateWeather(published, city, now());
          } catch (error) {
            const delay = await store.release?.(city, owner, now(), error.retryAfter || 60, error.status === 502);
            if (error instanceof HttpError) error.retryAfter = Math.max(error.retryAfter || 0, delay || 0);
            throw error;
          }
        })();
        pending.set(city, work);
        work.finally(() => pending.delete(city)).catch(() => {});
      }
      return res.status(200).json(await pending.get(city));
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 503;
      if ([429, 502, 503].includes(status)) res.set('Retry-After', String(error.retryAfter || 60));
      // Provider errors can include request URLs. Do not return or log the original error.
      return res.status(status).json({ error: error instanceof HttpError
        ? error.message : 'Weather service is temporarily unavailable.' });
    }
  };
}
