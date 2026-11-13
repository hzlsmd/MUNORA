const codes = new Set([
  0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77,
  80, 81, 82, 85, 86, 95, 96, 99,
]);
const rainCodes = new Set([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82]);
function number(n, min, max) {
  if (typeof n !== "number" || !Number.isFinite(n) || n < min || n > max)
    throw Error("invalid_measurement");
  return n;
}
function code(c) {
  if (!Number.isInteger(c) || !codes.has(c)) throw Error("invalid_code");
  return c;
}
function units(got, want) {
  for (const [key, value] of Object.entries(want))
    if (got?.[key] !== value) throw Error("invalid_units");
}
export function weatherTriggers(data, now) {
  units(data.current_units, {
    time: "unixtime",
    temperature_2m: "°C",
    apparent_temperature: "°C",
    weather_code: "wmo code",
    wind_speed_10m: "m/s",
  });
  units(data.hourly_units, { time: "unixtime", weather_code: "wmo code" });
  const c = data.current;
  const observed = number(c.time, 0, 4102444800) * 1000;
  if (now - observed > 10800000 || observed - now > 300000)
    throw Error("stale_weather");
  number(c.temperature_2m, -100, 70);
  number(c.apparent_temperature, -100, 100);
  number(c.wind_speed_10m, 0, 150);
  code(c.weather_code);
  const times = data.hourly.time,
    values = data.hourly.weather_code;
  if (
    !Array.isArray(times) ||
    !Array.isArray(values) ||
    times.length !== values.length ||
    times.length > 72 ||
    times.length < 7
  )
    throw Error("invalid_forecast");
  const hour = Math.floor(now / 3600000) * 3600;
  const considered = [c.weather_code];
  for (let i = 0; i < times.length; i++) {
    number(times[i], 0, 4102444800);
    code(values[i]);
    if (
      !Number.isInteger(times[i]) ||
      (i > 0 && times[i] - times[i - 1] !== 3600)
    )
      throw Error("invalid_forecast");
    if (times[i] < hour) continue;
    if (
      times[i] * 1000 >= now &&
      times[i] * 1000 <= now + 21600000
    )
      considered.push(values[i]);
  }
  if (times[0] > hour || times.at(-1) * 1000 < now + 21600000)
    throw Error("incomplete_forecast");
  const result = [];
  if (considered.some((c) => c >= 95)) result.push("storm");
  if (considered.some((c) => rainCodes.has(c))) result.push("rain");
  if (c.temperature_2m >= 32 || c.apparent_temperature >= 35)
    result.push("heat");
  if (c.wind_speed_10m >= 10) result.push("wind");
  return result;
}
export async function readJson(
  url,
  options = {},
  fetcher = fetch,
  limit = 131072,
) {
  const response = await fetcher(url, {
    ...options,
    // Workers supports manual/follow, not error. Non-2xx (including redirects)
    // are rejected below, so credentials cannot follow a redirect.
    redirect: "manual",
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw Error("upstream_rejected");
  }
  if (Number(response.headers.get("content-length")) > limit) {
    await response.body?.cancel();
    throw Error("response_too_large");
  }
  const reader = response.body.getReader();
  let total = 0;
  const chunks = [];
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.length;
      if (total > limit) throw Error("response_too_large");
      chunks.push(value);
    }
  } finally {
    await reader.cancel();
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return JSON.parse(new TextDecoder().decode(bytes));
}
export function getWeather(city) {
  const url = new URL("https://api.open-meteo.com/v1/forecast");
  url.search = new URLSearchParams({
    latitude: String(city.latitude),
    longitude: String(city.longitude),
    current: "temperature_2m,apparent_temperature,weather_code,wind_speed_10m",
    hourly: "weather_code",
    wind_speed_unit: "ms",
    temperature_unit: "celsius",
    timeformat: "unixtime",
    timezone: "Asia/Manila",
    forecast_days: "2",
  });
  return readJson(url);
}
