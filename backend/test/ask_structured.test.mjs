import test from "node:test";
import assert from "node:assert/strict";
import { handleAsk } from "../src/ask_munora.mjs";
const now = Date.parse("2026-11-17T15:30Z");
const hourly = [
  {
    time: Date.parse("2026-11-18T05:00Z") / 1000,
    precipitation_probability: 68,
    temperature_2m: 34,
    apparent_temperature: 39,
  },
  {
    time: Date.parse("2026-11-18T07:00Z") / 1000,
    precipitation_probability: 91,
    temperature_2m: 33,
    apparent_temperature: 38,
  },
  {
    time: Date.parse("2026-11-18T08:00Z") / 1000,
    precipitation_probability: 91,
    temperature_2m: 32,
    apparent_temperature: 37,
  },
];
const context = {
  observedAt: new Date(now).toISOString(),
  forecastUntil: new Date(now + 36 * 3600000).toISOString(),
  hourly,
  facts: [],
};
const selection = { forecastDate: "2026-11-18", topic: "rain", language: "en" };
async function run({
  question = "Will it rain tomorrow?",
  history = [],
  raw = { response: JSON.stringify(selection) },
  clock = () => now,
  weather = context,
  signal,
} = {}) {
  const logs = [];
  let calls = 0,
    prompt;
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
  const response = await handleAsk(
    new Request("https://fixture.invalid/ask", {
      method: "POST",
      headers: { "content-type": "application/json" },
      signal,
      body: JSON.stringify({
        schemaVersion: 2,
        city: "Muntinlupa",
        question,
        history,
      }),
    }),
    {
      DB: db,
      AI: {
        async run(_, input) {
          calls++;
          prompt = input.messages;
          if (raw instanceof Error) throw raw;
          return typeof raw === "function" ? raw() : raw;
        },
      },
    },
    {
      clock,
      getContext: async () => {
        if (weather instanceof Error) throw weather;
        return weather;
      },
      log: (entry) => logs.push(entry),
    },
  );
  return {
    status: response.status,
    body: await response.json(),
    logs,
    calls,
    prompt,
  };
}
test("v2 renders typed date and exact earliest peak from verified facts, never model prose", async () => {
  const r = await run();
  assert.equal(r.status, 200);
  assert.equal(r.body.schemaVersion, 2);
  assert.equal(r.body.responseType, "assistant");
  assert.equal(r.body.forecastDate, "2026-11-18");
  assert.match(r.body.advice, /umbrella/i);
  assert.match(r.body.explanation, /91%.*15:00.*3:00 PM/);
  assert.doesNotMatch(r.body.explanation, /68%/);
  assert.match(r.body.explanation, /earliest/);
  assert.ok(r.body.facts.some((f) => f.id === "tomorrow_rain_peak"));
  assert.equal(r.body.answer, `${r.body.advice}\n\n${r.body.explanation}`);
  assert.deepEqual(r.logs, []);
  assert.equal(r.calls, 1);
});
for (const [raw, category] of [
  [{ response: "not-json" }, "invalid_json"],
  [
    { choices: [{ finish_reason: "length", message: { content: "{}" } }] },
    "incomplete_output",
  ],
  [
    { response: JSON.stringify({ ...selection, forecastDate: "2026-11-19" }) },
    "unsupported_date",
  ],
  [
    { response: JSON.stringify({ ...selection, forecastDate: "2026-11-17" }) },
    "unsupported_date",
  ],
  [
    {
      response: JSON.stringify({
        ...selection,
        explanation: "Peak rain is 68% at 4 PM.",
      }),
    },
    "invalid_structure",
  ],
  [new Error("private prompt credentials raw output"), "ai_unavailable"],
])
  test(`v2 recovers ${category} without logging private data or retrying AI`, async () => {
    const r = await run({ raw });
    assert.equal(r.status, 200);
    assert.equal(r.body.responseType, "weather_summary");
    assert.equal(r.body.fallbackReason, category);
    assert.equal(r.body.forecastDate, "2026-11-18");
    assert.match(r.body.explanation, /91%/);
    assert.deepEqual(r.logs, [{ event: "ask_munora_rejection", category }]);
    assert.equal(r.calls, 1);
  });
test("Filipino follow-up uses explicit bukas and verified temperatures", async () => {
  const r = await run({
    question: "Bukas naman, gaano kainit?",
    history: [{ role: "user", content: "Uulan ba ngayon?" }],
    raw: {
      response: JSON.stringify({
        ...selection,
        topic: "heat",
        language: "fil",
      }),
    },
  });
  assert.equal(r.status, 200);
  assert.match(r.body.advice, /tubig/i);
  assert.match(r.body.explanation, /34 °C/);
  assert.match(r.body.explanation, /39 °C/);
  assert.equal(r.prompt.at(-2).content, "Uulan ba ngayon?");
});
test("empty today hours never substitutes tomorrow peaks", async () => {
  const r = await run({
    question: "What about today?",
    raw: {
      response: JSON.stringify({ ...selection, forecastDate: "2026-11-17" }),
    },
  });
  assert.equal(r.status, 200);
  assert.equal(r.body.forecastDate, "2026-11-17");
  assert.doesNotMatch(r.body.explanation, /91%/);
  assert.match(r.body.explanation, /No upcoming hourly/);
});
test("Philippine midnight changes explicit tomorrow target", async () => {
  const r = await run({ clock: () => Date.parse("2026-11-17T16:00Z") });
  assert.equal(r.body.responseType, "weather_summary");
  assert.equal(r.body.forecastDate, "2026-11-19");
  assert.equal(r.body.fallbackReason, "unsupported_date");
});
test("stale weather cannot become a fallback summary", async () => {
  const r = await run({
    weather: { ...context, observedAt: new Date(now - 1800001).toISOString() },
    raw: { response: "bad" },
  });
  assert.equal(r.status, 502);
  assert.equal(r.body.error.code, "weather_unavailable");
  assert.equal(r.calls, 0);
});
test("unrelated requests are declined without weather claims", async () => {
  const r = await run({
    question: "Write code for me",
    raw: { response: JSON.stringify({ ...selection, topic: "unsupported" }) },
  });
  assert.equal(r.status, 200);
  assert.equal(r.body.forecastDate, null);
  assert.deepEqual(r.body.facts, []);
  assert.match(r.body.advice, /weather/i);
});
test("aborted requests do not generate recovery summaries", async () => {
  const controller = new AbortController();
  controller.abort();
  const r = await run({ signal: controller.signal });
  assert.notEqual(r.status, 200);
  assert.equal(r.calls, 0);
});

test("expired evidence after inference is rejected without fallback or sensitive logs", async () => {
  let at = now;
  const r = await run({
    clock: () => at,
    raw: () => {
      at += 1800001;
      return { response: JSON.stringify(selection) };
    },
  });
  assert.equal(r.status, 502);
  assert.equal(r.body.error.code, "weather_unavailable");
  assert.deepEqual(r.logs, []);
});
test("missing provider data never produces fabricated recovery", async () => {
  const r = await run({ weather: new Error("provider private details") });
  assert.equal(r.status, 502);
  assert.equal(r.body.error.code, "weather_unavailable");
  assert.equal(r.calls, 0);
  assert.deepEqual(r.logs, []);
});
test("out-of-range explicit date is acknowledged without substituting today", async () => {
  const r = await run({ question: "Rain on 2026-12-01?" });
  assert.equal(r.status, 200);
  assert.equal(r.calls, 0);
  assert.equal(r.body.forecastDate, "2026-12-01");
  assert.equal(r.body.responseType, "weather_summary");
  assert.match(r.body.explanation, /No hourly forecast/);
  assert.deepEqual(r.body.facts, []);
});
test("Filipino malformed output recovery stays labeled and uses explicit day", async () => {
  const r = await run({
    question: "Kailangan ba ng payong bukas?",
    raw: { response: "private nonsense" },
  });
  assert.equal(r.body.responseType, "weather_summary");
  assert.equal(r.body.forecastDate, "2026-11-18");
  assert.match(r.body.advice, /payong/);
  assert.doesNotMatch(JSON.stringify(r.logs), /private nonsense/);
});
test("current question overrides the date in prior follow-up history", async () => {
  const r = await run({
    question: "What about tomorrow instead?",
    history: [
      { role: "user", content: "What about today?" },
      { role: "assistant", content: "There are no upcoming hours today." },
    ],
  });
  assert.equal(r.body.forecastDate, "2026-11-18");
  assert.equal(r.body.responseType, "assistant");
});
for (const invalid of [
  null,
  [],
  { ...selection, topic: "flood_safe" },
  { ...selection, language: "xx" },
])
  test("invalid selection cannot bypass canonical claims", async () => {
    const r = await run({ raw: { response: JSON.stringify(invalid) } });
    assert.equal(r.body.responseType, "weather_summary");
    assert.equal(r.body.fallbackReason, "invalid_structure");
  });
test("explicit Filipino request keeps recovery prose and labels in Filipino", async () => {
  const r = await run({
    question: "Please answer in Filipino: weather tomorrow?",
    raw: { response: "bad" },
  });
  assert.match(r.body.advice, /payong/);
  assert.match(r.body.explanation, /Pinakamataas na posibilidad ng ulan/);
  assert.match(r.body.explanation, /unang oras/);
});
test("explicit right-now question overrides tomorrow in history", async () => {
  const r = await run({
    question: "What is the weather right now?",
    history: [{ role: "user", content: "What about tomorrow?" }],
    raw: {
      response: JSON.stringify({
        ...selection,
        forecastDate: "2026-11-17",
        topic: "current",
      }),
    },
  });
  assert.equal(r.body.forecastDate, "2026-11-17");
  assert.equal(r.body.responseType, "assistant");
});
test("current conditions remain available even when today has no future hours", async () => {
  const r = await run({
    question: "What is the weather right now?",
    weather: {
      ...context,
      facts: [
        {
          id: "temperature",
          label: "Current temperature",
          value: "30 °C (feels like 34 °C)",
        },
        { id: "wind", label: "Current wind", value: "2 m/s" },
      ],
    },
    raw: {
      response: JSON.stringify({
        ...selection,
        forecastDate: "2026-11-17",
        topic: "current",
      }),
    },
  });
  assert.equal(r.body.responseType, "assistant");
  assert.match(r.body.explanation, /30 °C/);
  assert.match(r.body.explanation, /2 m\/s/);
  assert.doesNotMatch(r.body.explanation, /No upcoming/);
});
for (const topic of ["wind", "uv"])
  test(`${topic} questions retain verified daily peak facts`, async () => {
    const r = await run({
      question: `What about ${topic} tomorrow?`,
      weather: {
        ...context,
        hourly: hourly.map((h, i) => ({
          ...h,
          wind_speed_10m: 2 + i,
          uv_index: 7 - i,
        })),
      },
      raw: { response: JSON.stringify({ ...selection, topic }) },
    });
    assert.equal(r.body.responseType, "assistant");
    assert.ok(r.body.facts.some((f) => f.id === `tomorrow_${topic}_peak`));
    assert.doesNotMatch(r.body.advice, /umbrella/i);
  });
test("humidity requested for tomorrow does not substitute current readings", async () => {
  const r = await run({
    question: "Humidity tomorrow?",
    weather: {
      ...context,
      facts: [{ id: "humidity", label: "Current humidity", value: "60%" }],
    },
    raw: { response: JSON.stringify({ ...selection, topic: "humidity" }) },
  });
  assert.equal(r.body.responseType, "assistant");
  assert.doesNotMatch(r.body.explanation, /60%/);
  assert.match(r.body.explanation, /not available/i);
});
test("obvious wind intent cannot silently become unrelated overview advice", async () => {
  const r = await run({
    question: "How windy is it tomorrow?",
    weather: {
      ...context,
      hourly: hourly.map((h) => ({ ...h, wind_speed_10m: 4, uv_index: 2 })),
    },
    raw: { response: JSON.stringify({ ...selection, topic: "overview" }) },
  });
  assert.equal(r.body.responseType, "weather_summary");
  assert.equal(r.body.fallbackReason, "invalid_structure");
  assert.ok(r.body.facts.some((f) => f.id === "tomorrow_wind_peak"));
  assert.doesNotMatch(r.body.advice, /umbrella/i);
});
