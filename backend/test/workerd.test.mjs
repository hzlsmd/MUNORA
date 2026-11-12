import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";

// Run the actual adapter inside workerd. Node accepts redirect:error;
// Cloudflare rejects it before any weather/OAuth/FCM request is sent.
const source = readFileSync(
  new URL("../src/weather.mjs", import.meta.url),
  "utf8",
);
async function run(path) {
  const mf = new Miniflare(
    convertV4MiniflareOptions({
      name: "weather-adapter-test",
      modules: true,
      compatibilityDate: "2026-11-12",
      script:
        source +
        `
      export default {async fetch(request) {
        try {
          const redirectTest = new URL(request.url).pathname === '/redirect';
          const value = await readJson('https://upstream.example/weather', {}, async (url, options) => {
            const outgoing = new Request(url, options);
            if (outgoing.redirect !== 'manual') throw Error('redirect_following_enabled');
            return redirectTest ? new Response(null, {status:302,headers:{location:'https://other.example/'}}) : Response.json({weather:'available'});
          });
          return Response.json(value);
        } catch (error) {
          return Response.json({error:error.message}, {status:502});
        }
      }};
    `,
    }),
  );
  try {
    const response = await mf.dispatchFetch("http://localhost" + path);
    return { status: response.status, data: await response.json() };
  } finally {
    await mf.dispose();
  }
}

test("weather HTTP adapter runs with Cloudflare Request semantics", async () => {
  const result = await run("/weather");
  assert.deepEqual(result, { status: 200, data: { weather: "available" } });
});
test("weather HTTP adapter rejects redirects without following them in workerd", async () => {
  const result = await run("/redirect");
  assert.deepEqual(result, {
    status: 502,
    data: { error: "upstream_rejected" },
  });
});
