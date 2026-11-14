import { test } from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import { weatherTriggers } from "../src/weather.mjs";
import worker, { monitorCity, scheduledCities } from "../src/worker.mjs";
import { cities } from "../src/cities.mjs";
import { send } from "../src/fcm.mjs";
const now = Date.parse("2026-11-12T06:00:00Z");
function fixture(code = 61) {
  return {
    current_units: {
      time: "unixtime",
      temperature_2m: "°C",
      apparent_temperature: "°C",
      weather_code: "wmo code",
      wind_speed_10m: "m/s",
    },
    hourly_units: { time: "unixtime", weather_code: "wmo code" },
    current: {
      time: now / 1000,
      temperature_2m: 28,
      apparent_temperature: 30,
      wind_speed_10m: 2,
      weather_code: code,
    },
    hourly: {
      time: Array.from({ length: 24 }, (_, i) => now / 1000 + i * 3600),
      weather_code: Array(24).fill(code),
    },
  };
}
function database() {
  const sql = new DatabaseSync(":memory:");
  sql.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  return {
    prepare(query) {
      return {
        bind(...args) {
          const stmt = sql.prepare(query);
          return {
            async first() {
              return stmt.get(...args) ?? null;
            },
            async run() {
              return stmt.run(...args);
            },
          };
        },
      };
    },
    sql,
  };
}
const city = () => cities[0];
function dependencies(overrides = {}) {
  return {
    getWeather: async () => fixture(),
    getToken: async () => "token",
    send: async () => {},
    ...overrides,
  };
}
test("weather thresholds and hourly upcoming samples match app policy", () => {
  assert.deepEqual(weatherTriggers(fixture(), now), ["rain"]);
  const f = fixture(0);
  f.current.temperature_2m = 32;
  f.current.wind_speed_10m = 10;
  f.hourly.weather_code[3] = 95;
  assert.deepEqual(weatherTriggers(f, now), ["storm", "heat", "wind"]);
  f.hourly.weather_code[3] = 0;
  f.hourly.weather_code[1] = 95;
  assert.deepEqual(weatherTriggers(f, now), ["storm", "heat", "wind"]);
});
test("stale, future, malformed and incomplete observations do not generate alerts", () => {
  for (const edit of [
    (f) => (f.current.time -= 10801),
    (f) => (f.current.time += 301),
    (f) => (f.current.temperature_2m = null),
    (f) => (f.current.weather_code = 777),
    (f) => (f.hourly.time[2] += 1),
    (f) => f.hourly.weather_code.pop(),
    (f) => (f.current_units.wind_speed_10m = "km/h"),
    (f) => (f.hourly.time = f.hourly.time.slice(0, 2)),
  ]) {
    const f = fixture();
    edit(f);
    assert.throws(() => weatherTriggers(f, now));
  }
});
test("one-hour reminders and new trigger before reminder", async () => {
  const DB = database();
  let sent = 0;
  const deps = dependencies({ send: async () => sent++ });
  assert.equal(await monitorCity(city(), { DB }, now, deps), "sent");
  assert.equal(
    await monitorCity(city(), { DB }, now + 59 * 60000, deps),
    "quiet",
  );
  assert.equal(sent, 1);
  deps.getWeather = async () => {
    const f = fixture();
    f.current.temperature_2m = 34;
    return f;
  };
  assert.equal(
    await monitorCity(city(), { DB }, now + 59 * 60000, deps),
    "sent",
  );
  assert.equal(sent, 2);
  assert.equal(
    await monitorCity(city(), { DB }, now + 60 * 60000, deps),
    "sent",
  );
  assert.equal(sent, 3);
});
test("concurrent city checks cannot duplicate a send", async () => {
  const DB = database();
  let unlock;
  const gate = new Promise((r) => (unlock = r));
  let started;
  const ready = new Promise((r) => (started = r));
  let sent = 0;
  const deps = dependencies({
    getWeather: async () => {
      started();
      await gate;
      return fixture();
    },
    send: async () => sent++,
  });
  const first = monitorCity(city(), { DB }, now, deps);
  await ready;
  assert.equal(await monitorCity(city(), { DB }, now, deps), "busy");
  unlock();
  await first;
  assert.equal(sent, 1);
});
test("ambiguous FCM failures consume cooldown and never immediately resend", async () => {
  const DB = database();
  let sent = 0;
  const deps = dependencies({
    send: async () => {
      sent++;
      throw Error("timeout");
    },
  });
  await assert.rejects(monitorCity(city(), { DB }, now, deps));
  assert.equal(await monitorCity(city(), { DB }, now + 60000, deps), "quiet");
  assert.equal(sent, 1);
});
test("provider failure does not clear previous trigger state", async () => {
  const DB = database();
  await monitorCity(city(), { DB }, now, dependencies());
  await assert.rejects(
    monitorCity(
      city(),
      { DB },
      now + 60000,
      dependencies({
        getWeather: async () => {
          throw Error("offline");
        },
      }),
    ),
  );
  assert.equal(
    await monitorCity(city(), { DB }, now + 120000, dependencies()),
    "quiet",
  );
});
test("five-minute slots cover exactly 17 allowlisted cities", () => {
  const slots = Array.from({ length: 5 }, (_, i) =>
    scheduledCities(now + i * 60000),
  );
  assert.equal(new Set(slots.flat().map((c) => c.name)).size, 17);
  assert.ok(slots.every((s) => s.length <= 4));
  assert.deepEqual(scheduledCities(now), scheduledCities(now + 300000));
});
test("public routes cannot trigger notifications or expose configuration", async () => {
  assert.equal(
    (await worker.fetch(new Request("https://test/health"))).status,
    200,
  );
  for (const path of ["/send", "/cron", "/", "/secrets"])
    assert.equal(
      (await worker.fetch(new Request("https://test" + path))).status,
      404,
    );
  assert.equal(
    (await worker.fetch(new Request("https://test/health", { method: "POST" })))
      .status,
    405,
  );
});
test("expired lease owner cannot overwrite or send after a newer owner claims", async () => {
  const DB = database();
  let clock = now;
  let unlock;
  const gate = new Promise((r) => (unlock = r));
  let start;
  const ready = new Promise((r) => (start = r));
  let sent = 0;
  const old = monitorCity(
    city(),
    { DB },
    now,
    dependencies({
      clock: () => clock,
      getWeather: async () => {
        start();
        await gate;
        return fixture();
      },
      send: async () => sent++,
    }),
  );
  await ready;
  clock += 121000;
  await monitorCity(
    city(),
    { DB },
    clock,
    dependencies({ clock: () => clock, send: async () => sent++ }),
  );
  unlock();
  await old;
  assert.equal(sent, 1);
});

function rejectedSend(status, headers = {}) {
  return async (token, message) => send(token, message, async () =>
    new Response("private upstream details", {status, headers}));
}

test("explicit FCM 503 retries after five minutes without consuming the hourly reminder", async () => {
  const DB = database();
  const deps = dependencies({send: rejectedSend(503)});
  await assert.rejects(monitorCity(city(), {DB}, now, deps));
  assert.equal(await monitorCity(city(), {DB}, now + 60000, deps), "busy");
  const state = DB.sql.prepare("SELECT active,last_sent FROM city_alert_state").get();
  assert.deepEqual(JSON.parse(state.active), []);
  assert.deepEqual(JSON.parse(state.last_sent), {});
  deps.send = async () => {};
  assert.equal(await monitorCity(city(), {DB}, now + 300000, deps), "sent");
  assert.equal(await monitorCity(city(), {DB}, now + 600000, deps), "quiet");
});

test("FCM 429 respects Retry-After across a new monitor invocation", async () => {
  const DB = database();
  const deps = dependencies({send: rejectedSend(429, {"retry-after": "900"})});
  await assert.rejects(monitorCity(city(), {DB}, now, deps));
  deps.send = async () => {};
  assert.equal(await monitorCity(city(), {DB}, now + 300000, deps), "busy");
  assert.equal(await monitorCity(city(), {DB}, now + 900000, deps), "sent");
});

test("rejected reminder restores previously successful history and repeated failures keep backing off", async () => {
  const DB = database();
  await monitorCity(city(), {DB}, now, dependencies());
  const deps = dependencies({send: rejectedSend(503)});
  await assert.rejects(monitorCity(city(), {DB}, now + 3600000, deps));
  assert.deepEqual(JSON.parse(DB.sql.prepare("SELECT last_sent FROM city_alert_state").get().last_sent), {rain: now});
  await assert.rejects(monitorCity(city(), {DB}, now + 3900000, deps));
  assert.equal(await monitorCity(city(), {DB}, now + 3960000, deps), "busy");
  deps.send = async () => {};
  assert.equal(await monitorCity(city(), {DB}, now + 4200000, deps), "sent");
});

test("late rejected sender cannot restore history over a newer lease owner", async () => {
  const DB = database();
  let clock = now;
  let release, started;
  const gate = new Promise(r => release = r);
  const ready = new Promise(r => started = r);
  const old = monitorCity(city(), {DB}, now, dependencies({clock: () => clock, send: async (...args) => {
    started(); await gate; await rejectedSend(503)(...args);
  }}));
  const failure = assert.rejects(old);
  await ready;
  clock = now + 121000;
  const newer = dependencies({getWeather: async () => {
    const f = fixture(); f.current.temperature_2m = 34; return f;
  }});
  assert.equal(await monitorCity(city(), {DB}, clock, newer), "sent");
  release(); await failure;
  const state = DB.sql.prepare("SELECT active,last_sent FROM city_alert_state").get();
  assert.deepEqual(JSON.parse(state.active), ["rain", "heat"]);
  assert.equal(JSON.parse(state.last_sent).heat, clock);
  assert.equal(await monitorCity(city(), {DB}, now + 300000, newer), "quiet");
});

test("permanent FCM rejection retains the reservation rather than retrying rapidly", async () => {
  const DB = database();
  await assert.rejects(monitorCity(city(), {DB}, now, dependencies({send: rejectedSend(400)})));
  assert.equal(await monitorCity(city(), {DB}, now + 300000, dependencies()), "quiet");
});

test("monitor failures identify weather, OAuth and FCM boundaries", async () => {
  for (const [stage, overrides] of [
    ["weather", {getWeather: async () => {throw Error("offline")}}],
    ["oauth", {getToken: async () => {throw Error("invalid_fcm_configuration")}}],
    ["fcm", {send: rejectedSend(503)}],
  ]) {
    await assert.rejects(monitorCity(city(), {DB: database()}, now, dependencies(overrides)),
      (error) => {assert.equal(error.stage, stage); return true;});
  }
});

test("scheduled database failures log stage and category without leaking raw errors", async (t) => {
  const logs = [];
  t.mock.method(console, "error", (...args) => logs.push(args));
  const DB = {prepare() {throw Error("credential=private-token https://secret.example/body")}};
  let work;
  await worker.scheduled({scheduledTime: now}, {DB}, {waitUntil(p) {work = p}});
  await work;
  assert.equal(logs.length, scheduledCities(now).length);
  assert.deepEqual(logs[0], ["weather_monitor_failed", {
    city: scheduledCities(now)[0].slug, stage: "database", category: "unexpected_error",
  }]);
  assert.ok(!JSON.stringify(logs).includes("private-token"));
});

test("scheduled upstream rejections log HTTP status without upstream response bodies", async (t) => {
  const logs = [];
  t.mock.method(console, "error", (...args) => logs.push(args));
  t.mock.method(globalThis, "fetch", async () => new Response("private upstream body", {status: 503}));
  let work;
  await worker.scheduled({scheduledTime: now}, {DB: database()}, {waitUntil(p) {work = p}});
  await work;
  assert.deepEqual(logs[0], ["weather_monitor_failed", {
    city: scheduledCities(now)[0].slug, stage: "weather", category: "upstream_rejected", status: 503,
  }]);
  assert.ok(!JSON.stringify(logs).includes("private upstream body"));
});
