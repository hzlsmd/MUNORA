import { test } from "node:test";
import assert from "node:assert/strict";
import { getToken, notificationMessage, send } from "../src/fcm.mjs";
import { readJson } from "../src/weather.mjs";
import { cities } from "../src/cities.mjs";
test("OAuth signs with expected audience and scope and caches token", async () => {
  const keys = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", keys.privateKey);
  const secret = JSON.stringify({
    type: "service_account",
    project_id: "munora-5adfa",
    client_email:
      "munora-weather-sender-483@munora-5adfa.iam.gserviceaccount.com",
    private_key:
      "-----BEGIN PRIVATE KEY-----\n" +
      Buffer.from(pkcs8).toString("base64") +
      "\n-----END PRIVATE KEY-----",
  });
  let calls = 0;
  const fetcher = async (url, options) => {
    calls++;
    assert.equal(url, "https://oauth2.googleapis.com/token");
    const jwt = options.body.get("assertion"),
      parts = jwt.split(".");
    const payload = JSON.parse(Buffer.from(parts[1], "base64url"));
    assert.equal(payload.aud, url);
    assert.equal(
      payload.scope,
      "https://www.googleapis.com/auth/firebase.messaging",
    );
    assert.ok(
      await crypto.subtle.verify(
        "RSASSA-PKCS1-v1_5",
        keys.publicKey,
        Buffer.from(parts[2], "base64url"),
        new TextEncoder().encode(parts.slice(0, 2).join(".")),
      ),
    );
    return Response.json({ access_token: "test-only-token", expires_in: 3600 });
  };
  const env = { FCM_SERVICE_ACCOUNT_JSON: secret };
  assert.equal(await getToken(env, 1000000, fetcher), "test-only-token");
  assert.equal(await getToken(env, 1001000, fetcher), "test-only-token");
  assert.equal(calls, 1);
  await assert.rejects(
    getToken({ FCM_SERVICE_ACCOUNT_JSON: "{}" }, 1001000, fetcher),
    /invalid_fcm_configuration/,
  );
});
test("FCM topic payload has bounded lifetime, city and tap contract", async () => {
  const message = notificationMessage(
    cities[0],
    ["rain"],
    Date.now(),
    Date.now() / 1000,
  );
  assert.equal(message.message.topic, "munora_weather_muntinlupa");
  assert.equal(message.message.android.ttl, "3600s");
  assert.equal(message.message.data.route, "alerts");
  assert.equal(message.message.data.city, "Muntinlupa");
  await send("test-token", message, async (url, options) => {
    assert.equal(options.headers.authorization, "Bearer test-token");
    assert.ok(url.endsWith("/munora-5adfa/messages:send"));
    return Response.json({ name: "projects/test/messages/example" });
  });
});
test("HTTP adapter rejects non-success, oversized streaming and invalid JSON responses", async () => {
  await assert.rejects(
    readJson(
      "https://test",
      {},
      async () => new Response("denied", { status: 429 }),
    ),
    /upstream_rejected/,
  );
  await assert.rejects(
    readJson("https://test", {}, async () => new Response("123456"), 5),
    /response_too_large/,
  );
  await assert.rejects(
    readJson("https://test", {}, async () => new Response("no-json")),
  );
});

test("HTTP rejections preserve safe status and Retry-After without response content", async () => {
  for (const [header, delay] of [["900", 900000], ["invalid", 0], ["-1", 0]]) {
    await assert.rejects(
      readJson("https://test", {}, async () => new Response("private upstream details", {
        status: 429, headers: {"retry-after": header},
      })),
      (error) => {
        assert.equal(error.status, 429);
        assert.equal(error.retryAfterMs, delay);
        assert.equal(error.message, "upstream_rejected");
        assert.ok(!JSON.stringify(error).includes("private upstream details"));
        return true;
      },
    );
  }
  const future = new Date(Date.now() + 900000).toUTCString();
  await assert.rejects(
    readJson("https://test", {}, async () => new Response(null, {
      status: 503, headers: {"retry-after": future},
    })),
    (error) => error.status === 503 && error.retryAfterMs >= 898000 && error.retryAfterMs <= 900000,
  );
});
