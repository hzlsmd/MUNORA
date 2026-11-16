import { readJson } from "./weather.mjs";
import { topicFor } from "./cities.mjs";
const project = "munora-5adfa";
const identity =
  "munora-weather-sender-483@munora-5adfa.iam.gserviceaccount.com";
let cached = null;
const encode = (bytes) =>
  btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
const json64 = (value) =>
  encode(new TextEncoder().encode(JSON.stringify(value)));
export async function getToken(env, now = Date.now(), fetcher = fetch) {
  if (
    cached &&
    cached.secret === env.FCM_SERVICE_ACCOUNT_JSON &&
    cached.expires > now + 60000
  )
    return cached.token;
  let service;
  try {
    service = JSON.parse(env.FCM_SERVICE_ACCOUNT_JSON);
  } catch {
    throw Error("invalid_fcm_configuration");
  }
  if (
    service.project_id !== project ||
    service.client_email !== identity ||
    service.type !== "service_account" ||
    typeof service.private_key !== "string"
  )
    throw Error("invalid_fcm_configuration");
  const pem = service.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const seconds = Math.floor(now / 1000);
  const unsigned =
    json64({ alg: "RS256", typ: "JWT" }) +
    "." +
    json64({
      iss: identity,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: seconds,
      exp: seconds + 3600,
    });
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const result = await readJson(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: unsigned + "." + encode(new Uint8Array(signature)),
      }),
    },
    fetcher,
    16384,
  );
  if (
    typeof result.access_token !== "string" ||
    result.access_token.length < 1 ||
    !Number.isFinite(result.expires_in) ||
    result.expires_in < 120 ||
    result.expires_in > 3600
  )
    throw Error("invalid_oauth_response");
  cached = {
    secret: env.FCM_SERVICE_ACCOUNT_JSON,
    token: result.access_token,
    expires: now + result.expires_in * 1000,
  };
  return cached.token;
}
const recommendations = {
  rain: "Rain is expected in your area. Bring an umbrella or raincoat and allow extra travel time on wet roads.",
  storm: "Thunderstorms are forecast in your area. Limit exposed outdoor activities and seek indoor shelter.",
  heat: "High temperatures or feels-like heat are expected. Stay hydrated, seek shade and avoid prolonged sun exposure.",
  wind: "Strong winds are expected. Secure loose belongings and take care around trees and umbrellas.",
  uv: "High UV is forecast. Seek shade, wear sun protection and limit prolonged midday sun exposure.",
  clear: "The current estimate looks clear. Consider outdoor activities after checking the hourly forecast.",
};
export function notificationMessage(city, triggers, now, observed, weather) {
  const selected = [...new Set(triggers)].filter(t => recommendations[t]);
  const upcoming = (field) => (weather?.hourly?.[field] ?? []).filter((v,i) =>
    weather.hourly.time[i]*1000 >= now && weather.hourly.time[i]*1000 <= now+21600000 && typeof v === "number");
  const fingerprints = Object.fromEntries(selected.map(t => [t,
    t === "heat" ? `heat:${Math.floor(Math.max(weather?.current?.temperature_2m ?? 0,...upcoming("temperature_2m"))/3)}:${Math.floor(Math.max(weather?.current?.apparent_temperature ?? 0,...upcoming("apparent_temperature"))/3)}` :
    t === "uv" ? `uv:${Math.floor(Math.max(0,...upcoming("uv_index"))/3)}` :
    t === "rain" ? `rain:${weather?.current?.weather_code ?? ""}:${[...new Set(upcoming("weather_code"))].sort().join(",")}:${Math.floor(Math.max(0,...upcoming("precipitation_probability"))/20)}` :
    t === "wind" ? `wind:${Math.floor(Math.max(weather?.current?.wind_speed_10m ?? 0,...upcoming("wind_speed_10m"))/3)}` :
    `${t}:${weather?.current?.weather_code ?? ""}:${[...new Set(upcoming("weather_code"))].sort().join(",")}`
  ]));
  return {
    message: {
      topic: `${topicFor(city)}_v2`,
      // Data-only messages are posted by the Android background handler after
      // checking on-device consent, selected city, categories and quiet hours.
      data: {
        schema: "2",
        city: city.name,
        eventId: `${city.slug}:${now}`,
        issuedAt: new Date(now).toISOString(),
        estimateAt: new Date(observed * 1000).toISOString(),
        route: "alerts",
        triggers: JSON.stringify(selected),
        recommendations: JSON.stringify(Object.fromEntries(selected.map(t => [t,recommendations[t]]))),
        fingerprints: JSON.stringify(fingerprints),
      },
      android: {
        priority: selected.some(t => t !== "clear") ? "high" : "normal",
        ttl: "3600s",
        collapse_key: `weather_${city.slug}`,
      },
    },
  };
}
// Keep older installed clients on the original OS-rendered topic. Updated
// clients unsubscribe that topic before joining v2, preventing double delivery.
export function legacyNotificationMessage(city, triggers, now, observed) {
  const message = notificationMessage(city,triggers,now,observed).message;
  return {message: {
    topic: topicFor(city),
    notification: {title: `${city.name} weather update`,body: triggers.map(t=>recommendations[t]).filter(Boolean).join(" ")+" Check PAGASA advisories."},
    data: {city:city.name,eventId:`${city.slug}:${now}`,issuedAt:new Date(now).toISOString(),estimateAt:new Date(observed*1000).toISOString(),route:"alerts"},
    android: {...message.android,priority:"normal",notification:{channel_id:"weather_tips",icon:"ic_weather_notification",tag:`weather_${city.slug}`}},
  }};
}
export async function send(token, message, fetcher = fetch) {
  const result = await readJson(
    `https://fcm.googleapis.com/v1/projects/${project}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(message),
    },
    fetcher,
    16384,
  );
  if (typeof result.name !== "string") throw Error("invalid_fcm_response");
}
