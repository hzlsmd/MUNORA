import model from "../../assets/models/rain_model.json" with { type: "json" };
import { readJson } from "./weather.mjs";
const wet = new Set(model.wetWeatherCodes);
const codes = new Set(model.acceptedWeatherCodes);
export function rainFeatures(input) {
  if (
    model.schemaVersion !== 1 ||
    model.validationPassed !== true ||
    !Number.isFinite(Date.parse(input.observedAt))
  )
    return null;
  const city = input.city.toLowerCase().replaceAll(" ", "_");
  if (!model.cities.includes(city) || !codes.has(input.weatherCode))
    return null;
  const values = [
    "temperatureC",
    "humidityPercent",
    "pressureHpa",
    "windSpeedMs",
  ].map((k) => input[k]);
  if (
    values.some((x, i) => {
      const b = model.bounds[Object.keys(model.units)[i]];
      return !Number.isFinite(x) || x < b.min || x > b.max;
    })
  )
    return null;
  const d = new Date(Date.parse(input.observedAt) + 8 * 3600000),
    hour = d.getUTCHours() + d.getUTCMinutes() / 60 + d.getUTCSeconds() / 3600;
  const day = Math.floor((d - Date.UTC(d.getUTCFullYear(), 0, 1)) / 86400000),
    h = (2 * Math.PI * hour) / 24,
    s = (2 * Math.PI * (day + hour / 24)) / 365.2425;
  return [
    ...values,
    wet.has(input.weatherCode) ? 1 : 0,
    Math.sin(h),
    Math.cos(h),
    Math.sin(s),
    Math.cos(s),
    ...model.cities.map((c) => (c === city ? 1 : 0)),
  ];
}
export function rainProbability(input) {
  const f = rainFeatures(input);
  if (!f) return null;
  const z = f.reduce(
    (s, x, i) =>
      s + ((x - model.means[i]) / model.scales[i]) * model.coefficients[i],
    model.intercept,
  );
  return z >= 0 ? 1 / (1 + Math.exp(-z)) : Math.exp(z) / (1 + Math.exp(z));
}
const display = (value, digits = 1) => Number(value.toFixed(digits));
const fields = {
  temperature_2m: ["°C", -100, 70],
  apparent_temperature: ["°C", -120, 100],
  wind_speed_10m: ["m/s", 0, 150],
  relative_humidity_2m: ["%", 0, 100],
  pressure_msl: ["hPa", 800, 1100],
  weather_code: ["wmo code", 0, 99],
};
const hourlyFields = {
  temperature_2m: fields.temperature_2m,
  apparent_temperature: fields.apparent_temperature,
  wind_speed_10m: fields.wind_speed_10m,
  weather_code: fields.weather_code,
  precipitation_probability: ["%", 0, 100],
  uv_index: ["", 0, 30],
};
function check(x, [, min, max], key) {
  if (
    typeof x !== "number" ||
    !Number.isFinite(x) ||
    x < min ||
    x > max ||
    (key === "weather_code" && !codes.has(x))
  )
    throw Error("invalid_weather");
}
export function buildContext(data, city, now) {
  if (
    data.current_units?.time !== "unixtime" ||
    data.hourly_units?.time !== "unixtime"
  )
    throw Error("invalid_units");
  const c = data.current;
  if (
    !Number.isInteger(c?.time) ||
    now - c.time * 1000 > 1800000 ||
    c.time * 1000 - now > 300000
  )
    throw Error("stale_weather");
  for (const [k, s] of Object.entries(fields)) {
    if (data.current_units[k] !== s[0]) throw Error("invalid_units");
    check(c[k], s, k);
  }
  const h = data.hourly,
    t = h?.time;
  if (!Array.isArray(t) || t.length < 36 || t.length > 72)
    throw Error("invalid_forecast");
  for (const [k, s] of Object.entries(hourlyFields)) {
    if (
      data.hourly_units[k] !== s[0] ||
      !Array.isArray(h[k]) ||
      h[k].length !== t.length
    )
      throw Error("invalid_forecast");
  }
  const future = [];
  for (let i = 0; i < t.length; i++) {
    if (!Number.isInteger(t[i]) || (i && t[i] - t[i - 1] !== 3600))
      throw Error("invalid_forecast");
    for (const [k, s] of Object.entries(hourlyFields)) check(h[k][i], s, k);
    if (t[i] * 1000 > now && future.length < 36)
      future.push(
        Object.fromEntries(
          ["time", ...Object.keys(hourlyFields)].map((k) => [k, h[k][i]]),
        ),
      );
  }
  if (future.length !== 36 || future[0].time * 1000 - now > 3600000)
    throw Error("incomplete_forecast");
  const facts = [
    {
      id: "temperature",
      label: "Current temperature",
      value: `${display(c.temperature_2m, 1)} °C (feels like ${display(c.apparent_temperature, 1)} °C)`,
    },
    {
      id: "humidity",
      label: "Current humidity",
      value: `${display(c.relative_humidity_2m, 0)}%`,
    },
    {
      id: "wind",
      label: "Current wind",
      value: `${display(c.wind_speed_10m, 2)} m/s`,
    },
    {
      id: "forecast",
      label: "Next 36 hours",
      value: `Maximum rain probability ${display(Math.max(...future.map((x) => x.precipitation_probability)), 0)}%; maximum UV ${display(Math.max(...future.map((x) => x.uv_index)))}`,
    },
    {
      id: "pressure",
      label: "Current mean sea-level pressure",
      value: `${display(c.pressure_msl, 1)} hPa`,
    },
  ];
  facts.push({
    id: "conditions",
    label: "Current WMO conditions",
    value: `Code ${c.weather_code}: ${c.weather_code >= 95 ? "thunderstorm" : wet.has(c.weather_code) ? "precipitation" : c.weather_code >= 45 ? "fog" : c.weather_code <= 1 ? "clear or mainly clear" : "partly cloudy or overcast"}`,
  });
  const p = rainProbability({
    city: city.slug,
    observedAt: new Date(c.time * 1000).toISOString(),
    temperatureC: c.temperature_2m,
    humidityPercent: c.relative_humidity_2m,
    pressureHpa: c.pressure_msl,
    windSpeedMs: c.wind_speed_10m,
    weatherCode: c.weather_code,
  });
  if (p !== null)
    facts.push({
      id: "experimental_rain",
      label: "Experimental rain estimate",
      value: `${Math.round(p * 100)}% between ${new Date(c.time * 1000).toISOString()} and ${new Date(c.time * 1000 + 10800000).toISOString()}; experimental`,
    });
  for (let i = 0; i < future.length; i++) {
    const h = future[i],
      local = new Date(h.time * 1000 + 8 * 3600000).toISOString().slice(0, 16);
    const hour = Number(local.slice(11, 13));
    const time12 = `${hour % 12 || 12}:${local.slice(14, 16)} ${hour < 12 ? "AM" : "PM"}`;
    facts.push({
      id: `hour_${i}`,
      label: "Hourly forecast (PHT UTC+8)",
      value: `${local} PHT (${time12}); ${display(h.temperature_2m, 1)} °C; feels ${display(h.apparent_temperature, 1)} °C; rain ${display(h.precipitation_probability, 0)}%; wind ${display(h.wind_speed_10m, 2)} m/s; UV ${display(h.uv_index, 1)}; WMO ${h.weather_code}`,
    });
  }
  return {
    observedAt: new Date(c.time * 1000).toISOString(),
    forecastUntil: new Date(future.at(-1).time * 1000).toISOString(),
    facts,
    hourly: future,
  };
}
export async function getAssistantContext(city, now, signal, fetcher = fetch) {
  const u = new URL("https://api.open-meteo.com/v1/forecast");
  u.search = new URLSearchParams({
    latitude: String(city.latitude),
    longitude: String(city.longitude),
    current: Object.keys(fields).join(","),
    hourly: Object.keys(hourlyFields).join(","),
    wind_speed_unit: "ms",
    temperature_unit: "celsius",
    timeformat: "unixtime",
    timezone: "Asia/Manila",
    forecast_days: "3",
  });
  return buildContext(
    await readJson(u, {}, (url, options) =>
      fetcher(url, {
        ...options,
        signal: AbortSignal.any([options.signal, signal]),
      }),
    ),
    city,
    now,
  );
}
