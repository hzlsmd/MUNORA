import { readJson } from "./weather.mjs";
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
const titles = {
  rain: "Rain protection recommended",
  storm: "Thunderstorm conditions forecast",
  heat: "Take precautions in the heat",
  wind: "Prepare for windy conditions",
};
export function notificationMessage(city, triggers, now, observed) {
  return {
    message: {
      topic: `munora_weather_${city.slug}`,
      notification: {
        title: `${city.name} weather update`,
        body:
          triggers.map((t) => titles[t]).join(". ") +
          ". Forecast-based guidance; check PAGASA advisories.",
      },
      data: {
        city: city.name,
        eventId: `${city.slug}:${now}`,
        issuedAt: new Date(now).toISOString(),
        estimateAt: new Date(observed * 1000).toISOString(),
        route: "alerts",
      },
      android: {
        priority: "normal",
        ttl: "3600s",
        collapse_key: `weather_${city.slug}`,
        notification: {
          channel_id: "weather_tips",
          icon: "ic_weather_notification",
          tag: `weather_${city.slug}`,
        },
      },
    },
  };
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
