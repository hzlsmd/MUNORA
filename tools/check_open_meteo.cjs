const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Opt-in live smoke check: two city requests per viewport, never a load test.
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium',
    headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage'] });
  const output = path.join(process.cwd(), 'build', 'open-meteo-check');
  fs.mkdirSync(output, { recursive: true });
  try {
    for (const viewport of [{ width: 390, height: 844 }, { width: 1366, height: 900 }]) {
      const page = await browser.newPage({ viewport });
      const errors = [];
      const providerStatuses = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('response', r => { if (r.url().startsWith('https://api.open-meteo.com/')) providerStatuses.push(r.status()); });
      if (process.env.MUNORA_WEATHER_FIXTURE) {
        const json = JSON.parse(fs.readFileSync(process.env.MUNORA_WEATHER_FIXTURE, 'utf8'));
        await page.route('https://api.open-meteo.com/**', route => route.fulfill({ json }));
      }
      await page.goto(process.env.MUNORA_PREVIEW_URL || 'http://127.0.0.1:8082');
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      await page.getByText('Weather data by Open-Meteo', { exact: true }).waitFor({ timeout: 40000 });
      await page.screenshot({ path: path.join(output, `home-${viewport.width}.png`) });
      await page.getByText('Forecast', { exact: true }).click();
      await page.getByText('5-Day Forecast', { exact: true }).waitFor();
      await page.screenshot({ path: path.join(output, `forecast-${viewport.width}.png`) });
      await page.getByText('Home', { exact: true }).click();
      await page.getByText('Muntinlupa', { exact: true }).click();
      await page.getByText('Manila NCR, Philippines', { exact: true }).click();
      await page.getByText('Weather data by Open-Meteo', { exact: true }).waitFor();
      await page.getByRole('button', { name: 'Refresh weather' }).waitFor();
      assert.deepEqual(providerStatuses, [200, 200]);
      await page.route('https://api.open-meteo.com/**', route => route.abort());
      await page.getByRole('button', { name: 'Refresh weather' }).click();
      await page.getByText(/Saved weather\./).waitFor();
      await page.screenshot({ path: path.join(output, `saved-${viewport.width}.png`) });
      assert.deepEqual(errors, []);
      console.log(JSON.stringify({ viewport, mode: process.env.MUNORA_WEATHER_FIXTURE ? 'captured-response' : 'live', providerStatuses, errors, savedWeather: true }));
      await page.close();
    }
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
