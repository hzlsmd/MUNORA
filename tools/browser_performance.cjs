const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const output = process.env.MUNORA_AUDIT_OUTPUT || path.join(process.cwd(), 'build', 'audit');
fs.mkdirSync(output, { recursive: true });

(async () => {
  const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage'] });
  const results = [];
  try {
    for (const [name, url] of [['baseline', process.env.MUNORA_BASELINE_URL || 'http://127.0.0.1:8080'],
      ['hardened', process.env.MUNORA_HARDENED_URL || 'http://127.0.0.1:8081']]) {
      for (const viewport of [{ width: 390, height: 844 }, { width: 1366, height: 900 }]) {
        const page = await browser.newPage({ viewport });
        const errors = [];
        let requests = 0;
        let offline = false;
        page.on('pageerror', e => errors.push(e.message));
        await page.route('https://weather.example.invalid/weather**', async route => {
          requests++;
          if (offline) return route.abort();
          const city = new URL(route.request().url()).searchParams.get('city');
          const now = new Date();
          await route.fulfill({ json: { city, updatedAt: now.toISOString(), observedAt: now.toISOString(),
            current: { temperature: 30, feelsLike: 33, humidity: 80, pressure: 1010, wind: 2.5, condition: 'light rain' },
            hourly: Array.from({ length: 40 }, (_, i) => ({ at: new Date(+now + i * 10800000).toISOString(),
              temperature: 30, low: 29, high: 31, condition: 'light rain' })),
          } });
        });
        const start = performance.now();
        await page.goto(url);
        await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
        await page.getByText('30°C', { exact: true }).first().waitFor();
        const readyMs = performance.now() - start;
        const homeRequests = requests;
        await page.getByText('Forecast', { exact: true }).click();
        await page.getByText('5-Day Forecast', { exact: true }).waitFor();
        await page.getByText('Home', { exact: true }).click();
        await page.getByText('Muntinlupa', { exact: true }).click();
        await page.getByText('Manila NCR, Philippines', { exact: true }).click();
        await page.getByText('Manila', { exact: true }).first().waitFor();
        await page.getByText('30°C', { exact: true }).first().waitFor();
        const afterNavigationRequests = requests;
        offline = true;
        await page.getByRole('button', { name: 'Refresh weather' }).click();
        await page.getByText(/Saved weather\./).waitFor();
        const screenshot = path.join(output, 'audit-' + name + '-' + viewport.width + '.png');
        await page.screenshot({ path: screenshot });
        assert.deepEqual(errors, []);
        results.push({ name, viewport, readyMs, homeRequests, afterNavigationRequests,
          finalRequests: requests, errors, screenshot });
        await page.close();
      }
    }
    fs.writeFileSync(path.join(output, 'browser-performance.json'), JSON.stringify(results, null, 2));
    console.log(JSON.stringify(results, null, 2));
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
