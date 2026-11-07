const invalid = () => { throw new Error('Invalid weather data'); };
export function number(value, min, max) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) invalid();
  return value;
}
export function condition(value) {
  if (typeof value !== 'string' || !value.trim() || value.length > 120 || /[\u0000-\u001f\u007f]/.test(value)) invalid();
  return value;
}
export function timestamp(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(Date.parse(value))) invalid();
  return Date.parse(value);
}
export function validateWeather(data, city, now) {
  if (!data || data.city !== city) invalid();
  const updated = timestamp(data.updatedAt);
  const observed = timestamp(data.observedAt);
  if (updated > now + 300000 || now - updated > 86400000 || observed > now + 300000 || now - observed > 10800000) invalid();
  const c = data.current;
  number(c?.temperature, -100, 70); number(c?.feelsLike, -120, 100);
  number(c?.humidity, 0, 100); number(c?.pressure, 500, 1200); number(c?.wind, 0, 150); condition(c?.condition);
  if (!Array.isArray(data.hourly) || data.hourly.length < 1 || data.hourly.length > 40) invalid();
  const times = new Set();
  for (const item of data.hourly) {
    const at = timestamp(item.at);
    if (at < updated - 43200000 || at > updated + 518400000 || times.has(at)) invalid();
    times.add(at);
    number(item.temperature, -100, 70); number(item.low, -100, 70); number(item.high, -100, 70);
    if (item.low > item.temperature || item.temperature > item.high) invalid();
    condition(item.condition);
  }
  if (Math.max(...times) <= now) invalid();
  data.hourly.sort((a, b) => Date.parse(a.at) - Date.parse(b.at));
  return data;
}

export async function boundedJson(response) {
  const maxBytes = 131072;
  if (Number(response.headers?.get('content-length')) > maxBytes) {
    await response.body?.cancel();
    invalid();
  }
  const reader = response.body?.getReader();
  if (!reader) invalid();
  const chunks = [];
  let size = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) invalid();
      chunks.push(value);
    }
    return JSON.parse(Buffer.concat(chunks, size).toString('utf8'));
  } finally {
    await reader.cancel().catch(() => {});
  }
}
