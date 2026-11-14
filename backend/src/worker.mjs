import { cities } from "./cities.mjs";
import { getWeather, weatherTriggers, UpstreamRejection } from "./weather.mjs";
import { getToken, send, notificationMessage } from "./fcm.mjs";
import { atStage, logMonitorFailure } from "./diagnostics.mjs";
export const scheduledCities = (time) =>
  cities.filter((_, i) => i % 5 === Math.floor(time / 60000) % 5);
export async function monitorCity(
  city,
  env,
  now,
  deps = { getWeather, getToken, send, clock: Date.now },
) {
  const owner = crypto.randomUUID();
  const clock = deps.clock ?? (() => now);
  const claim = await atStage("database", () => env.DB.prepare(
    `INSERT INTO city_alert_state(city,lease_until,lease_token) VALUES(?,?,?)
 ON CONFLICT(city) DO UPDATE SET lease_until=excluded.lease_until,lease_token=excluded.lease_token
 WHERE city_alert_state.lease_until<=? RETURNING active,last_sent`,
  )
    .bind(city.name, now + 120000, owner, now)
    .first());
  if (!claim) return "busy";
  try {
    const weather = await atStage("weather", () => deps.getWeather(city));
    const triggers = await atStage("weather", () => weatherTriggers(weather, now));
    const [active, history] = await atStage("state", () => [
      JSON.parse(claim.active), JSON.parse(claim.last_sent),
    ]);
    const due = triggers.filter(
      (t) =>
        !active.includes(t) ||
        history[t] === undefined ||
        now - history[t] >= 3600000,
    );
    if (due.length) {
      const token = await atStage("oauth", () => deps.getToken(env, now));
      for (const t of due) history[t] = now;
      // Reserve before sending: a timeout can mean accepted delivery. Do not retry it immediately.
      const reserved = await atStage("database", () => env.DB.prepare(
        "UPDATE city_alert_state SET active=?,last_sent=?,updated_at=? WHERE city=? AND lease_token=? AND lease_until>? RETURNING city",
      )
        .bind(
          JSON.stringify(triggers),
          JSON.stringify(history),
          now,
          city.name,
          owner,
          clock(),
        )
        .first());
      if (!reserved) return "busy";
      try {
        await deps.send(
          token,
          notificationMessage(city, due, now, weather.current.time),
        );
      } catch (error) {
        if (error instanceof UpstreamRejection &&
            (error.status === 429 || error.status >= 500)) {
          const failedAt = clock();
          // An explicit rejection was not accepted by FCM. Restore history and
          // persist backoff in the lease, including across Worker restarts.
          // Detach this lease from our finally block. Expired owners cannot
          // roll back newer sends. Uncertain timeouts keep the hour reservation.
          await atStage("database", () => env.DB.prepare(
            "UPDATE city_alert_state SET active=?,last_sent=?,lease_until=?,lease_token='' WHERE city=? AND lease_token=? AND lease_until>?",
          ).bind(
            claim.active, claim.last_sent,
            failedAt + Math.max(300000, error.retryAfterMs),
            city.name, owner, failedAt,
          ).run());
        }
        await atStage("fcm", () => { throw error; });
      }
    } else {
      await atStage("database", () => env.DB.prepare(
        "UPDATE city_alert_state SET active=?,updated_at=? WHERE city=? AND lease_token=? AND lease_until>?",
      )
        .bind(JSON.stringify(triggers), now, city.name, owner, clock())
        .run());
    }
    return due.length ? "sent" : "quiet";
  } finally {
    await atStage("database", () => env.DB.prepare(
      "UPDATE city_alert_state SET lease_until=0 WHERE city=? AND lease_token=?",
    )
      .bind(city.name, owner)
      .run());
  }
}
export default {
  async fetch(request) {
    if (request.method !== "GET")
      return new Response("Method not allowed", {
        status: 405,
        headers: { Allow: "GET" },
      });
    if (new URL(request.url).pathname !== "/health")
      return new Response("Not found", { status: 404 });
    return Response.json({
      service: "munora-weather",
      delivery: "forecast-based push",
      cadenceMinutes: 5,
      reminderMinutes: 60,
    });
  },
  async scheduled(event, env, ctx) {
    // Keep individual runs bounded: 3–4 cities each minute, every city once per five minutes.
    ctx.waitUntil(
      (async () => {
        for (const city of scheduledCities(event.scheduledTime)) {
          try {
            await monitorCity(city, env, Date.now());
          } catch (error) {
            logMonitorFailure(city.slug, error);
          }
        }
      })(),
    );
  },
};
