import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";

// Exercise the installed Wrangler, including packaging and multipart upload.
// Only the remote API is replaced; no real account or credentials are used.
test(
  "preview packages without production resources or inherited Base settings",
  { timeout: 45000 },
  async () => {
    const temp = await mkdtemp(join(tmpdir(), "munora-preview-"));
    const requests = [];
    const preview = {
      id: "test-preview",
      name: "config-regression",
      slug: "config-regression",
      urls: ["https://preview.example.test"],
    };
    const server = createServer(async (req, res) => {
      try {
        const parts = [];
        for await (const part of req) parts.push(part);
        const body = Buffer.concat(parts);
        const url = new URL(req.url, "http://localhost");
        const record = {
          method: req.method,
          path: url.pathname,
          query: url.search,
        };
        requests.push(record);
        res.setHeader("Content-Type", "application/json");
        const ok = (result) =>
          res.end(
            JSON.stringify({ success: true, errors: [], messages: [], result }),
          );
        if (
          req.method === "GET" &&
          url.pathname.endsWith("/previews/config-regression")
        ) {
          res.statusCode = 404;
          return res.end(
            JSON.stringify({
              success: false,
              errors: [{ code: 10025, message: "Preview does not exist" }],
            }),
          );
        }
        if (req.method === "POST" && url.pathname.endsWith("/previews")) {
          record.body = JSON.parse(body);
          return ok(preview);
        }
        if (
          req.method === "POST" &&
          url.pathname.endsWith(`/previews/${preview.id}/deployments`)
        ) {
          const form = await new Response(body, {
            headers: { "Content-Type": req.headers["content-type"] },
          }).formData();
          record.metadata = JSON.parse(form.get("metadata"));
          record.modules = await Promise.all(
            form.getAll("files").map(async (file) => ({
              name: file.name,
              source: await file.text(),
            })),
          );
          return ok({ id: "test-deployment", urls: preview.urls, env: {} });
        }
        res.statusCode = 500;
        res.end(
          JSON.stringify({
            success: false,
            errors: [{ code: 99999, message: "Unexpected API request" }],
          }),
        );
      } catch (error) {
        res.statusCode = 500;
        res.end(
          JSON.stringify({
            success: false,
            errors: [{ code: 99999, message: error.message }],
          }),
        );
      }
    });
    try {
      await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
      const backend = fileURLToPath(new URL("../", import.meta.url));
      const child = spawn(
        "npm",
        [
          "--prefix",
          backend,
          "run",
          "preview",
          "--",
          "--name",
          preview.name,
          "--json",
        ],
        {
          cwd: backend,
          env: {
            ...process.env,
            CI: "true",
            CLOUDFLARE_API_TOKEN: "local-test-only",
            CLOUDFLARE_API_BASE_URL: `http://127.0.0.1:${server.address().port}/client/v4`,
            WRANGLER_SEND_METRICS: "false",
            WRANGLER_LOG_PATH: temp,
            XDG_CONFIG_HOME: temp,
            NO_PROXY: "127.0.0.1,localhost",
            no_proxy: "127.0.0.1,localhost",
          },
          timeout: 35000,
        },
      );
      let output = "";
      child.stdout.on("data", (data) => {
        output += data;
      });
      child.stderr.on("data", (data) => {
        output += data;
      });
      const exit = await new Promise((resolve, reject) => {
        child.on("error", reject);
        child.on("close", resolve);
      });
      assert.equal(exit, 0, output);
      const creation = requests.find(
        (r) => r.method === "POST" && r.path.endsWith("/previews"),
      );
      assert.ok(creation, "Wrangler must create a Preview");
      assert.equal(
        new URLSearchParams(creation.query).get("ignore_base_config"),
        "true",
      );
      const upload = requests.find((r) => r.metadata);
      assert.ok(upload, "Wrangler must upload the packaged Worker");
      assert.deepEqual(
        upload.metadata.env ?? {},
        {},
        "Preview must not bind production D1 or FCM",
      );
      assert.equal(upload.metadata.main_module, "worker.js");
      assert.ok(
        upload.modules.some((m) => m.source.includes("munora-weather")),
        "Upload must contain the real backend",
      );
      assert.ok(
        requests.every((r) => r.path.includes("/previews")),
        "No production API mutations",
      );
      const mf = new Miniflare(
        convertV4MiniflareOptions({
          modules: true,
          compatibilityDate: upload.metadata.compatibility_date,
          script: upload.modules.find(
            (m) => m.name === upload.metadata.main_module,
          ).source,
        }),
      );
      try {
        const health = await mf.dispatchFetch(
          "https://preview.example.test/health",
        );
        assert.equal(health.status, 200);
        assert.equal((await health.json()).service, "munora-weather");
        assert.equal(
          (await mf.dispatchFetch("https://preview.example.test/send")).status,
          404,
        );
        assert.equal(
          (
            await mf.dispatchFetch("https://preview.example.test/health", {
              method: "POST",
            })
          ).status,
          405,
        );
      } finally {
        await mf.dispose();
      }
    } finally {
      await new Promise((resolve) => server.close(resolve));
      await rm(temp, { recursive: true, force: true });
    }
  },
);
