const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium',
    headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage'] });
  const output = path.join(process.cwd(), 'build', 'tips-check');
  fs.mkdirSync(output, { recursive: true });
  try {
    for (const viewport of [{ width: 390, height: 844 }, { width: 1366, height: 900 }]) {
      const page = await browser.newPage({ viewport });
      let calls = 0;
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      await page.route('https://api.open-meteo.com/**', route => {
        calls++;
        const now = new Date();
        const start = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), now.getUTCHours());
        return route.fulfill({ json: {
          current_units: { time: 'unixtime', temperature_2m: '\u00b0C', apparent_temperature: '\u00b0C',
            relative_humidity_2m: '%', pressure_msl: 'hPa', wind_speed_10m: 'm/s', weather_code: 'wmo code' },
          hourly_units: { time: 'unixtime', temperature_2m: '\u00b0C', weather_code: 'wmo code' },
          current: { time: Math.floor(+now / 1000), temperature_2m: 33, apparent_temperature: 36,
            relative_humidity_2m: 80, pressure_msl: 1010, wind_speed_10m: 12, weather_code: 95 },
          hourly: { time: Array.from({ length: 144 }, (_, i) => (start + i * 3600000) / 1000),
            temperature_2m: Array(144).fill(30), weather_code: Array(144).fill(61) },
        } });
      });
      await page.goto(process.env.MUNORA_PREVIEW_URL || 'http://127.0.0.1:8083');
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      await page.getByText('Weather data by Open-Meteo', { exact: true }).waitFor();
      await page.getByText('Tips', { exact: true }).click();
      await page.getByText('Weather Tips', { exact: true }).waitFor();
      try {
        await page.getByText('Plan indoor activities', { exact: false }).waitFor({ timeout: 10000 });
      } catch (error) {
        console.error(await page.locator('body').innerText());
        await page.screenshot({ path: path.join(output, `failure-${viewport.width}.png`) });
        throw error;
      }
      await page.screenshot({ path: path.join(output, `tips-top-${viewport.width}.png`) });
      await page.mouse.move(viewport.width / 2, viewport.height / 2);
      await page.mouse.wheel(0, 650);
      await page.getByText('Prepare for windy conditions', { exact: false }).waitFor();
      await page.screenshot({ path: path.join(output, `tips-bottom-${viewport.width}.png`) });
      assert.equal(calls, 1, 'Tips should reuse the Home weather request');
      assert.deepEqual(errors, []);
      console.log(JSON.stringify({ viewport, providerCalls: calls, errors }));
      await page.close();
    }
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
