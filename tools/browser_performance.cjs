// Build with --no-web-resources-cdn, serve locally, then run with Playwright cached.
// Use an OS-isolated network namespace for security/performance audits.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {allowedPreview,providerFixture,classifyRequest} = require('./weather_benchmark_fixture.cjs');
async function main() {
  const preview = process.env.MUNORA_PREVIEW_URL || 'http://127.0.0.1:8083';
  assert.ok(allowedPreview(preview),'Use an isolated loopback preview, never a deployed site');
  const origin = new URL(preview).origin;
  const samples = Number(process.env.MUNORA_PERF_SAMPLES || 3);
  assert.ok(Number.isInteger(samples) && samples>=1 && samples<=5);
  const browser = await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
  const results = [];
  try {
    for (const viewport of [{width:390,height:844},{width:1366,height:900}]) {
      for(let sample=1;sample<=samples;sample++) {
        const context = await browser.newContext({viewport,serviceWorkers:'block'});
        const page = await context.newPage();
        page.setDefaultTimeout(30000);
        const errors=[],unexpected=[],failed=[];let requests=0;
        page.on('pageerror',e=>errors.push(e.message));
        page.on('requestfailed',r=>failed.push({url:r.url(),error:r.failure()?.errorText}));
        page.on('console',m=>{if(m.type()==='error') errors.push(m.text())});
        await context.route('**/*', async route => {
          const u=new URL(route.request().url());
          const decision=classifyRequest(u,origin);
          if(decision==='preview') return route.continue();
          if(decision==='weather') {
            requests++;return route.fulfill({json:providerFixture(u)});
          }
          unexpected.push(u.origin+u.pathname);return route.abort();
        });
        const start=performance.now();
        await page.goto(preview);
        try { await page.locator('flt-semantics-placeholder').evaluate(e=>e.click()); } catch(e) { console.error(JSON.stringify({errors,unexpected,failed})); throw e; }
        await page.getByText('Weather data by Open-Meteo',{exact:true}).waitFor();
        await page.getByText('33°C',{exact:true}).first().waitFor();
        const weatherVisibleMs=performance.now()-start;
        const homeRequests=requests;
        await page.getByText('Forecast',{exact:true}).last().click();
        await page.getByText('5-Day Forecast',{exact:true}).waitFor();
        await page.getByText('Hourly',{exact:true}).click();
        await page.getByText('1-hour intervals',{exact:true}).waitFor();
        await page.getByText('Tips',{exact:true}).click();
        await page.getByText('Daily lifestyle tips',{exact:true}).waitFor();
        await page.waitForLoadState('networkidle');
        assert.equal(homeRequests,1,'One shared main weather request');
        assert.equal(requests,3,'Navigation reuses weather; optional insights fetch two feeds');
        assert.deepEqual(errors,[]);assert.deepEqual(unexpected,[]);
        const frames=await page.evaluate(()=>new Promise(resolve=>{
          const gaps=[];let before;
          function frame(at){if(before!==undefined)gaps.push(at-before);before=at;if(gaps.length===60)resolve(gaps);else requestAnimationFrame(frame)}
          requestAnimationFrame(frame);
        }));
        frames.sort((a,b)=>a-b);
        const metrics=await page.context().newCDPSession(page).then(async s=>{await s.send('Performance.enable');return s.send('Performance.getMetrics')});
        const jsHeapUsedBytes=metrics.metrics.find(m=>m.name==='JSHeapUsedSize')?.value;
        results.push({viewport,sample,weatherVisibleMs,intentionalBrandingDelayMs:5000,homeRequests,totalProviderRequests:requests,frameIntervalMedianMs:frames[30],frameIntervalP95Ms:frames[56],jsHeapUsedBytes,errors,unexpected});
        await context.close();
      }
    }
    const report={scope:'Headless Chromium software rendering, local assets and dummy Open-Meteo responses; not native Android, real network or live AI latency.',samplesPerViewport:samples,results};
    const output=process.env.MUNORA_AUDIT_OUTPUT || path.join(process.cwd(),'build','audit');
    fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,'browser-performance.json'),JSON.stringify(report,null,2)+'\n');
    console.log(JSON.stringify(report,null,2));
  } finally {await browser.close();}
}
if(require.main===module)main().catch(e=>{console.error(e);process.exitCode=1});
module.exports={main};
