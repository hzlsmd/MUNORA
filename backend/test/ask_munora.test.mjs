import test from "node:test";
import assert from "node:assert/strict";
import {
  validateRequest,
  validateAnswer,
  handleAsk,
} from "../src/ask_munora.mjs";
import { rainFeatures, rainProbability } from "../src/assistant_context.mjs";
import model from "../../assets/models/rain_model.json" with { type: "json" };
test("request rejects tampering, oversized history and system roles", () => {
  const good = {
    schemaVersion: 1,
    city: "Manila",
    question: "Umbrella?",
    history: [],
  };
  assert.equal(validateRequest(good).city.name, "Manila");
  for (const bad of [
    { ...good, facts: [] },
    { ...good, question: "x".repeat(601) },
    { ...good, history: [{ role: "system", content: "x" }] },
    { ...good, city: "Elsewhere" },
  ])
    assert.throws(() => validateRequest(bad));
});
test("rain artifact golden vectors parity", () => {
  for (const v of model.goldenVectors) {
    rainFeatures(v.input).forEach((x, i) =>
      assert.ok(Math.abs(x - v.features[i]) < 1e-12),
    );
    assert.ok(Math.abs(rainProbability(v.input) - v.probability) < 1e-12);
  }
});
test("answer rejects unsupported facts, numbers and fields", () => {
  const facts = [{ id: "temperature", label: "Temperature", value: "30 °C" }];
  assert.equal(
    validateAnswer({ answer: "It is 30 °C.", factIds: ["temperature"] }, facts)
      .answer,
    "It is 30 °C.",
  );
  for (const answer of [
    { answer: "It is 99 °C.", factIds: ["temperature"] },
    { answer: "Fine", factIds: ["fake"] },
    { answer: "Fine", factIds: [], extra: 1 },
  ])
    assert.throws(() => validateAnswer(answer, facts));
});
test("missing AI/DB fails closed and native requests accepted", async () => {
  const r = await handleAsk(
    new Request("https://x/ask", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        schemaVersion: 1,
        city: "Manila",
        question: "Rain?",
        history: [],
      }),
    }),
    {},
  );
  assert.equal(r.status, 503);
  assert.equal((await r.json()).error.code, "unavailable");
});

import {
  buildContext,
  getAssistantContext,
} from "../src/assistant_context.mjs";
const now = Date.UTC(2026, 10, 17, 0, 15);
function weather() {
  const keys = {
    temperature_2m: ["°C", 30],
    apparent_temperature: ["°C", 33],
    wind_speed_10m: ["m/s", 2],
    relative_humidity_2m: ["%", 80],
    pressure_msl: ["hPa", 1010],
    weather_code: ["wmo code", 1],
  };
  const hs = {
    temperature_2m: keys.temperature_2m,
    apparent_temperature: keys.apparent_temperature,
    wind_speed_10m: keys.wind_speed_10m,
    weather_code: keys.weather_code,
    precipitation_probability: ["%", 20],
    uv_index: ["", 2],
  };
  return {
    current: {
      time: now / 1000,
      ...Object.fromEntries(Object.entries(keys).map(([k, v]) => [k, v[1]])),
    },
    current_units: {
      time: "unixtime",
      ...Object.fromEntries(Object.entries(keys).map(([k, v]) => [k, v[0]])),
    },
    hourly: {
      time: Array.from(
        { length: 72 },
        (_, i) => Math.floor(now / 3600000) * 3600 + i * 3600,
      ),
      ...Object.fromEntries(
        Object.entries(hs).map(([k, v]) => [k, Array(72).fill(v[1])]),
      ),
    },
    hourly_units: {
      time: "unixtime",
      ...Object.fromEntries(Object.entries(hs).map(([k, v]) => [k, v[0]])),
    },
  };
}
const city = { name: "Manila", slug: "manila", latitude: 14.6, longitude: 121 };
test("context validates units/freshness/alignment/codes/numbers and limits to 36 future hours", () => {
  const c = buildContext(weather(), city, now);
  assert.equal(c.hourly.length, 36);
  assert.ok(c.hourly.every((x) => x.time * 1000 > now));
  assert.match(
    c.facts.find((f) => f.id === "experimental_rain").value,
    /2026-11-17T00:15:00.000Z/,
  );
  assert.match(
    c.facts.find((f) => f.id === "experimental_rain").value,
    /2026-11-17T03:15:00.000Z/,
  );
  for (const mutate of [
    (d) => (d.current_units.pressure_msl = "Pa"),
    (d) => (d.current.time -= 1801),
    (d) => (d.current.time += 301),
    (d) => d.hourly.time[4]++,
    (d) => (d.current.weather_code = 4),
    (d) => (d.current.temperature_2m = NaN),
    (d) => (d.hourly.uv_index[0] = null),
    (d) => (d.hourly.time = d.hourly.time.slice(0, 20)),
  ]) {
    const d = weather();
    mutate(d);
    assert.throws(() => buildContext(d, city, now));
  }
});
test("authoritative HTTP requests mean sea-level pressure, rejects redirects and uses bounded reader", async () => {
  let requested;
  const signal = new AbortController().signal;
  const c = await getAssistantContext(city, now, signal, async (u, o) => {
    requested = new URL(u);
    assert.equal(o.redirect, "manual");
    const encoded = new TextEncoder().encode(JSON.stringify(weather()));
    return new Response(
      new ReadableStream({
        start(controller) {
          controller.enqueue(encoded.slice(0, 100));
          controller.enqueue(encoded.slice(100));
          controller.close();
        },
      }),
    );
  });
  assert.match(requested.searchParams.get("current"), /pressure_msl/);
  assert.ok(!requested.search.includes("surface_pressure"));
  assert.equal(c.hourly.length, 36);
  await assert.rejects(() =>
    getAssistantContext(
      city,
      now,
      signal,
      async () => new Response(null, { status: 302 }),
    ),
  );
  await assert.rejects(() =>
    getAssistantContext(
      city,
      now,
      signal,
      async () => new Response("x".repeat(131073)),
    ),
  );
});
test("HTTP rejects bytes, disallowed origins, methods and invalid JSON before AI", async () => {
  for (const [request, status] of [
    [
      new Request("https://x/ask", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: " ".repeat(12289),
      }),
      413,
    ],
    [
      new Request("https://x/ask", { headers: { origin: "https://evil" } }),
      403,
    ],
    [new Request("https://x/ask"), 405],
    [
      new Request("https://x/ask", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: "{",
      }),
      400,
    ],
  ])
    assert.equal((await handleAsk(request, {})).status, status);
  const r = await handleAsk(
    new Request("https://x/ask", {
      method: "OPTIONS",
      headers: { origin: "https://app" },
    }),
    { ASK_ALLOWED_ORIGINS: "https://app" },
  );
  assert.equal(r.status, 204);
  assert.equal(r.headers.get("access-control-allow-origin"), "https://app");
});
import { abortable } from "../src/ask_munora.mjs";
test("caller cancellation bounds a single unresolved operation without retry", async () => {
  const controller = new AbortController();
  let calls = 0;
  const pending = abortable(() => {
    calls++;
    return new Promise(() => {});
  }, controller.signal);
  await Promise.resolve();
  controller.abort();
  await assert.rejects(pending);
  assert.equal(calls, 1);
});
test("history totals and strict output shapes are bounded", () => {
  const b = {
    schemaVersion: 1,
    city: "Manila",
    question: "Rain?",
    history: Array.from({ length: 5 }, () => ({
      role: "user",
      content: "x".repeat(600),
    })),
  };
  assert.throws(() => validateRequest(b));
  b.history = Array.from({ length: 7 }, () => ({ role: "user", content: "x" }));
  assert.throws(() => validateRequest(b));
  const facts = [
    { id: "hour_0", label: "Hour", value: "2026-11-17T16:00 PHT; 28 °C" },
  ];
  assert.equal(
    validateAnswer({ answer: "At 16:00, 28 °C.", factIds: ["hour_0"] }, facts)
      .facts.length,
    1,
  );
  for (const r of [
    { answer: "x".repeat(1801), factIds: [] },
    { answer: "Fine", factIds: ["hour_0", "hour_0"] },
    { answer: "<b>Fine</b>", factIds: [] },
    { answer: "Fine", factIds: "hour_0" },
    { answer: "At 16:00, 28 °C.", factIds: [] },
  ])
    assert.throws(() => validateAnswer(r, facts));
});
test("body byte bound rejects multibyte payload even if character count is smaller", async () => {
  const r = await handleAsk(
    new Request("https://x/ask", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        schemaVersion: 1,
        city: "Manila",
        question: "雨".repeat(4200),
        history: [],
      }),
    }),
    {},
  );
  assert.equal(r.status, 413);
});
test("model malformed/truncated/failure responses fail closed and never retry", async () => {
  const db = {
    prepare() {
      return {
        bind() {
          return this;
        },
        async run() {
          return {};
        },
        async first() {
          return { attempts: 1 };
        },
      };
    },
  };
  const context = {
    observedAt: new Date(now).toISOString(),
    forecastUntil: new Date(now + 36 * 3600000).toISOString(),
    facts: [{ id: "temperature", label: "Temperature", value: "30 °C" }],
  };
  for (const [raw, status, code] of [
    [
      { choices: [{ finish_reason: "length", message: { content: "{}" } }] },
      502,
      "invalid_ai_response",
    ],
    [
      {
        choices: [
          {
            message: {
              content: '{"answer":"99 °C","factIds":["temperature"]}',
            },
          },
        ],
      },
      502,
      "invalid_ai_response",
    ],
    [{ response: "bad json" }, 502, "invalid_ai_response"],
    [null, 503, "ai_unavailable"],
  ]) {
    let calls = 0;
    const env = {
      DB: db,
      AI: {
        async run() {
          calls++;
          if (raw === null) throw Error("private error");
          return raw;
        },
      },
    };
    const r = await handleAsk(
      new Request("https://x/ask", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          schemaVersion: 1,
          city: "Manila",
          question: "Hot?",
          history: [],
        }),
      }),
      env,
      { clock: () => now, getContext: async () => context },
    );
    assert.equal(r.status, status);
    assert.equal((await r.json()).error.code, code);
    assert.equal(calls, 1);
  }
});

test("numeric claims preserve signs but normalize decimal formatting", () => {
  const facts = [{ id: "temperature", label: "Temperature", value: "30 °C" }];
  assert.throws(() =>
    validateAnswer(
      { answer: "It is -30 °C.", factIds: ["temperature"] },
      facts,
    ),
  );
  assert.equal(
    validateAnswer(
      { answer: "It is 30.0 °C.", factIds: ["temperature"] },
      facts,
    ).facts.length,
    1,
  );
});
test("high precision provider numbers produce bounded display facts", () => {
  const d = weather();
  for (const k of [
    "temperature_2m",
    "apparent_temperature",
    "wind_speed_10m",
    "precipitation_probability",
    "uv_index",
  ])
    d.hourly[k].fill(12.123456789012345);
  assert.ok(
    buildContext(d, city, now).facts.every((f) => f.value.length <= 180),
  );
});
test("JSON lookalike media types are rejected", async () => {
  const r = await handleAsk(
    new Request("https://x/ask", {
      method: "POST",
      headers: { "content-type": "application/jsonp" },
      body: JSON.stringify({
        schemaVersion: 1,
        city: "Manila",
        question: "Rain?",
        history: [],
      }),
    }),
    {},
  );
  assert.equal(r.status, 400);
});
