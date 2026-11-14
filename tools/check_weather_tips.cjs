// Run after a release build, with build/web served on port 8083.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium',
    headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const output = path.join(process.cwd(), 'build', 'tips-check');
  fs.mkdirSync(output, { recursive: true });
  try {
    for (const viewport of [{ width: 390, height: 844 }, { width: 1366, height: 900 }]) {
      const page = await browser.newPage({ viewport });
      let calls = 0;
      let firstForecastStart;
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      await page.route('https://api.open-meteo.com/**', route => {
        calls++;
        const manila = new URL(route.request().url()).searchParams.get('latitude') === '14.5995';
        const now = new Date();
        const start = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), now.getUTCHours());
        const query = new URL(route.request().url()).searchParams;
        if (!query.has('current')) {
          const hourly = {time: Array.from({length:72}, (_,i)=>(start+i*3600000)/1000)};
          const hourly_units = {time:'unixtime'};
          const fields = query.has('models') ? ['precipitation_ecmwf_ifs025','precipitation_gfs_seamless','precipitation_icon_seamless'] : ['temperature_2m','relative_humidity_2m','precipitation_probability','uv_index','apparent_temperature','wind_speed_10m','weather_code'];
          for (const key of fields) {
            hourly[key] = Array(72).fill(key==='temperature_2m'||key==='apparent_temperature'?27:key==='wind_speed_10m'?2:key==='relative_humidity_2m'?70:key==='precipitation_probability'?10:key==='uv_index'?3:0);
            hourly_units[key] = key==='temperature_2m'||key==='apparent_temperature'?'°C':key==='wind_speed_10m'?'m/s':key==='weather_code'?'wmo code':key==='uv_index'?'':key.startsWith('precipitation_')&&key!=='precipitation_probability'?'mm':'%';
          }
          return route.fulfill({json:{hourly,hourly_units}});
        }
        firstForecastStart ??= start;
        return route.fulfill({ json: {
          current_units: { time: 'unixtime', temperature_2m: '\u00b0C', apparent_temperature: '\u00b0C',
            relative_humidity_2m: '%', pressure_msl: 'hPa', wind_speed_10m: 'm/s', weather_code: 'wmo code' },
          hourly_units: { time: 'unixtime', temperature_2m: '\u00b0C', weather_code: 'wmo code' },
          current: { time: Math.floor(+now / 1000), temperature_2m: manila ? 28 : 33,
            apparent_temperature: manila ? 30 : 36, relative_humidity_2m: 80,
            pressure_msl: 1010, wind_speed_10m: manila ? 2 : 12, weather_code: manila ? 0 : 95 },
          hourly: { time: Array.from({ length: 144 }, (_, i) => (start + i * 3600000) / 1000),
            temperature_2m: Array(144).fill(30), weather_code: Array(144).fill(manila ? 0 : 61) },
        } });
      });
      await page.goto(process.env.MUNORA_PREVIEW_URL || 'http://127.0.0.1:8083');
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      await page.getByText('Weather data by Open-Meteo', { exact: true }).waitFor();
      await page.waitForLoadState('networkidle');
      await page.screenshot({ path: path.join(output, `home-${viewport.width}.png`) });

      await page.getByText('Forecast', { exact: true }).last().click();
      await page.getByText('5-Day Forecast', { exact: true }).waitFor();
      await page.screenshot({ path: path.join(output, `forecast-${viewport.width}.png`) });
      await page.getByText('Hourly', { exact: true }).click();
      await page.getByText('Forecast outlook', { exact: true }).waitFor();
      await page.getByText('1-hour intervals', { exact: true }).waitFor();
      // One forecast hour later, displayed in PHT (UTC + 8 hours).
      const nextHour = new Date(firstForecastStart + 9 * 3600000);
      const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      const h = nextHour.getUTCHours();
      const nextLabel = `${weekdays[nextHour.getUTCDay()]} ${nextHour.getUTCDate()}/${nextHour.getUTCMonth() + 1}\n${h % 12 || 12} ${h < 12 ? 'AM' : 'PM'}`;
      // Flutter exposes each forecast card as a combined accessibility group.
      await page.getByText(nextLabel, { exact: false }).first().waitFor();

      await page.getByText('Alerts', { exact: true }).click();
      await page.getByText('App-generated notices from weather estimates. These are not official warnings.', { exact: true }).waitFor();
      await page.getByText('Plan indoor activities', { exact: false }).waitFor();
      await page.screenshot({ path: path.join(output, `alerts-${viewport.width}.png`) });
      await page.getByRole('checkbox', {name:'Calm Skies',exact:true}).click();
      await page.getByText('Preview only — current notices remain active', {exact:false}).waitFor();
      await page.getByText('Return to Current Hazards', {exact:false}).click();
      await page.getByText('Plan indoor activities', {exact:false}).waitFor();

      await page.getByText('Tips', { exact: true }).click();
      await page.getByText('Daily lifestyle tips', { exact: true }).waitFor();
      await page.getByRole('button', {name:/Plan My Activity/}).click();
      await page.getByRole('checkbox', {name:'Exercise',exact:true}).click();
      await page.getByText('Check this plan', {exact:true}).click();
      await page.getByText('Fewer forecast concerns', {exact:true}).waitFor();
      await page.getByText('Save daily routine', {exact:true}).click();
      await page.getByText('Remove routine', {exact:true}).waitFor();
      await page.getByText('Remove routine', {exact:true}).click();
      await page.getByRole('button', {name:/Plan My Activity/}).click();
      await page.getByRole('checkbox', { name: 'Heat', exact: true }).click();
      await page.getByText('Stay Hydrated', { exact: false }).waitFor();
      await page.getByText('Take breaks from the heat', { exact: false }).waitFor();
      await page.getByRole('button', { name: /Why this suggestion/ }).last().click();
      await page.getByText('Temperature 33.0 C; feels like 36.0 C.', { exact: false }).waitFor();
      await page.screenshot({ path: path.join(output, `tips-${viewport.width}.png`) });
      await page.getByRole('button', {name:'Helpful',exact:true}).click();
      await page.getByText('Feedback stays on this device.', {exact:false}).waitFor();
      await page.mouse.move(viewport.width / 2, 500);
      await page.mouse.wheel(0, 1500);
      await page.waitForTimeout(400);
      await page.screenshot({ path: path.join(output, `tips-feedback-${viewport.width}.png`) });
      assert.equal(calls, 3, 'Screens should share the Home weather request');

      await page.getByText('Home', { exact: true }).last().click();
      await page.getByText('Muntinlupa', { exact: true }).click();
      await Promise.all([
        page.waitForResponse(response => response.url().includes('latitude=14.5995')),
        page.getByText('Manila', { exact: true }).click(),
      ]);
      await page.getByText('Select location', { exact: true }).waitFor({ state: 'hidden' });
      await page.getByText('Check forecast notices', { exact: false }).waitFor();
      await page.getByText('AI rain outlook', {exact:true}).waitFor();
      await page.getByText(/probability of rain/).waitFor();
      await page.getByText('Experimental estimate', {exact:true}).waitFor();
      await page.getByText('Alerts', { exact: true }).click();
      await page.getByRole('checkbox', { name: 'Calm Skies', exact: true }).click();
      await page.getByText('No forecast triggers detected', { exact: false }).waitFor();
      await page.getByText(/This is not an all-clear/).waitFor();
      await page.screenshot({ path: path.join(output, `alerts-calm-${viewport.width}.png`) });
      await page.getByText('Tips', { exact: true }).click();
      await page.getByRole('button', {name:/Plan My Activity/}).click();
      await page.getByText('Check this plan', {exact:true}).click();
      await page.getByText('AI rain context · Experimental', {exact:true}).waitFor();
      await page.getByText(/chance of rain · full 3-hour outlook/).waitFor();
      await page.getByText(/Probability covers the complete three-hour window/).waitFor();
      await page.mouse.move(viewport.width / 2, 500);
      await page.mouse.wheel(0, 1500);
      await page.waitForTimeout(400);
      await page.screenshot({path: path.join(output, `ai-planner-${viewport.width}.png`)});
      await page.mouse.wheel(0, -1500);
      await page.waitForTimeout(400);
      await page.getByRole('button', {name:/Plan My Activity/}).click();
      await page.getByRole('checkbox', { name: 'Heat', exact: true }).click();
      await page.getByText('Stay Hydrated', { exact: false }).waitFor();
      assert.equal(calls, 6, 'Changing cities should request only that city');
      assert.deepEqual(errors, []);
      console.log(JSON.stringify({ viewport, providerCalls: calls, errors }));
      await page.close();
    }
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
