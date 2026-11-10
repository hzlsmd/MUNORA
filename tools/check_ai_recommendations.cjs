// Build with --dart-define=AI_RECOMMENDATION_URL=https://munora-ai.test/recommendations
// Serve build/web on 8083. This uses controlled weather and model fixtures, never live AI.
const { chromium } = require("playwright");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

(async () => {
  const { createHandler } = await import(
    pathToFileURL(path.resolve("backend/src/worker.js")).href
  );
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || "/usr/bin/chromium",
    headless: true,
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
  });
  const output = path.resolve("build/ai-check");
  fs.mkdirSync(output, { recursive: true });
  try {
    for (const viewport of [
      { width: 390, height: 844 },
      { width: 1366, height: 900 },
    ]) {
      const page = await browser.newPage({ viewport });
      const errors = [];
      let aiCalls = 0,
        modelCalls = 0,
        quota = false;
      page.on("pageerror", (e) => errors.push(e.message));
      const handler = createHandler({
        reserve: async () => !quota,
        fetch: async () => {
          modelCalls++;
          return Response.json({
            candidates: [
              {
                finishReason: "STOP",
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        summary:
                          "Consider postponing exposed activity or choosing an indoor alternative.",
                        reason:
                          "A thunderstorm is forecast during your selected activity window.",
                        preparations: [
                          "Choose an indoor alternative.",
                          "Check official advisories before leaving.",
                        ],
                      }),
                    },
                  ],
                },
              },
            ],
          });
        },
      });
      await page.route("https://munora-ai.test/**", async (route) => {
        aiCalls++;
        const request = route.request();
        const response = await handler(
          new Request(request.url(), {
            method: request.method(),
            headers: {
              "Content-Type": "application/json",
              Origin: "http://127.0.0.1:8083",
            },
            body: request.postData(),
          }),
          {
            GEMINI_MODEL: "fixture-free-model",
            GEMINI_API_KEY: "fixture-key",
            ALLOWED_ORIGINS: "http://127.0.0.1:8083",
          },
        );
        await route.fulfill({
          status: response.status,
          headers: Object.fromEntries(response.headers),
          body: await response.text(),
        });
      });
      await page.route("https://api.open-meteo.com/**", (route) => {
        const q = new URL(route.request().url()).searchParams,
          now = new Date();
        const start = Date.UTC(
          now.getUTCFullYear(),
          now.getUTCMonth(),
          now.getUTCDate(),
          now.getUTCHours(),
        );
        if (q.has("current"))
          return route.fulfill({
            json: {
              current_units: {
                time: "unixtime",
                temperature_2m: "°C",
                apparent_temperature: "°C",
                relative_humidity_2m: "%",
                pressure_msl: "hPa",
                wind_speed_10m: "m/s",
                weather_code: "wmo code",
              },
              hourly_units: {
                time: "unixtime",
                temperature_2m: "°C",
                weather_code: "wmo code",
              },
              current: {
                time: Math.floor(+now / 1000),
                temperature_2m: 28,
                apparent_temperature: 30,
                relative_humidity_2m: 80,
                pressure_msl: 1010,
                wind_speed_10m: 2,
                weather_code: 0,
              },
              hourly: {
                time: Array.from(
                  { length: 144 },
                  (_, i) => (start + i * 3600000) / 1000,
                ),
                temperature_2m: Array(144).fill(28),
                weather_code: Array.from({ length: 144 }, (_, i) =>
                  i === 1 ? 95 : 0,
                ),
              },
            },
          });
        const hourly = {
            time: Array.from(
              { length: 72 },
              (_, i) => (start + i * 3600000) / 1000,
            ),
          },
          hourly_units = { time: "unixtime" };
        const fields = q.has("models")
          ? [
              "precipitation_ecmwf_ifs025",
              "precipitation_gfs_seamless",
              "precipitation_icon_seamless",
            ]
          : [
              "temperature_2m",
              "relative_humidity_2m",
              "precipitation_probability",
              "uv_index",
              "apparent_temperature",
              "wind_speed_10m",
              "weather_code",
            ];
        for (const key of fields) {
          hourly[key] = Array.from({ length: 72 }, (_, i) =>
            key === "weather_code"
              ? i === 1
                ? 95
                : 0
              : key === "temperature_2m"
                ? 28
                : key === "apparent_temperature"
                  ? 30
                  : key === "relative_humidity_2m"
                    ? 80
                    : key === "precipitation_probability"
                      ? 10
                      : key === "uv_index"
                        ? 2
                        : key === "wind_speed_10m"
                          ? 2
                          : 0,
          );
          hourly_units[key] =
            key === "weather_code"
              ? "wmo code"
              : key === "temperature_2m" || key === "apparent_temperature"
                ? "°C"
                : key === "uv_index"
                  ? ""
                  : key === "wind_speed_10m"
                    ? "m/s"
                    : key === "relative_humidity_2m" ||
                        key === "precipitation_probability"
                      ? "%"
                      : "mm";
        }
        return route.fulfill({ json: { hourly, hourly_units } });
      });
      await page.goto(
        process.env.MUNORA_PREVIEW_URL || "http://127.0.0.1:8083",
      );
      await page
        .locator("flt-semantics-placeholder")
        .evaluate((e) => e.click());
      await page
        .getByText("Weather data by Open-Meteo", { exact: true })
        .waitFor({ timeout: 45000 });
      await page.getByText("Tips", { exact: true }).click();
      await page.getByRole("button", { name: /Plan My Activity/ }).click();
      await page.getByText("Check this plan", { exact: true }).click();
      await page.getByText("Consider postponing", { exact: true }).waitFor();
      assert.equal(aiCalls, 0, "AI requires an explicit request");
      await page
        .getByText("Generate AI recommendation", { exact: true })
        .click();
      await page
        .getByText("AI-generated recommendation", { exact: true })
        .waitFor();
      await page
        .getByText(
          "Consider postponing exposed activity or choosing an indoor alternative.",
          { exact: true },
        )
        .waitFor();
      await page
        .getByText("Rule-based hazards: storm.", { exact: true })
        .waitFor();
      assert.equal(aiCalls, 1);
      assert.equal(modelCalls, 1);
      await page
        .getByText("AI-generated recommendation", { exact: true })
        .scrollIntoViewIfNeeded();
      await page.screenshot({
        path: path.join(output, `recommendation-${viewport.width}.png`),
      });
      quota = true;
      await page
        .getByRole("checkbox", { name: "Exercise", exact: true })
        .click();
      await page.getByText("Check this plan", { exact: true }).click();
      await page
        .getByText("Generate AI recommendation", { exact: true })
        .click();
      await page
        .getByText("The free AI limit has been reached.", { exact: false })
        .waitFor();
      assert.equal(
        await page
          .getByText("AI-generated recommendation", { exact: true })
          .count(),
        0,
      );
      assert.equal(aiCalls, 2);
      assert.equal(modelCalls, 1);
      assert.deepEqual(errors, []);
      console.log(
        JSON.stringify({
          viewport,
          aiCalls,
          modelCalls,
          mode: "controlled fixtures",
          quotaFallback: true,
          errors,
        }),
      );
      await page.close();
    }
  } finally {
    await browser.close();
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
