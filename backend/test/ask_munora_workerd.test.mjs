import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";
const ask = readFileSync(
  new URL("../src/ask_munora.mjs", import.meta.url),
  "utf8",
)
  .replace(/^import .*;\n/gm, "")
  .replaceAll("export ", "");
const schema = readFileSync(
  new URL("../ask_munora_schema.sql", import.meta.url),
  "utf8",
);
test("workerd local D1 enforces concurrent minute/day/global quotas and HTTP model contract", async () => {
  const script = `const cities=[{name:'Manila',slug:'manila'}];
 const context={observedAt:'2026-11-17T00:00:00.000Z',forecastUntil:'2026-11-18T12:00:00.000Z',facts:[{id:'temperature',label:'Temperature',value:'30 °C'}]};
 const getAssistantContext=async()=>context;
 ${ask}
 export default {async fetch(r,env){const u=new URL(r.url);if(u.pathname==='/quota'){try{await claimQuota(env.DB,u.searchParams.get('ip'),Number(u.searchParams.get('now')));return new Response('ok');}catch(e){return new Response(e.code||'db',{status:e.status||503,headers:{'Retry-After':String(e.retry||0)}});}}
 if(u.pathname==='/ask'){env.AI={run:async(model,input)=>{if(model!==MODEL||input.max_completion_tokens!==384||input.chat_template_kwargs.enable_thinking!==false||input.response_format.type!=='json_object')throw Error('bad contract');return {choices:[{message:{content:JSON.stringify({answer:'It is 30 °C.',factIds:['temperature']})}}]};}};return handleAsk(r,env,{clock:()=>1794873600000});}return new Response('missing',{status:404});}};`;
  const mf = new Miniflare(
    convertV4MiniflareOptions({
      name: "ask-test",
      modules: true,
      compatibilityDate: "2026-11-12",
      script,
      d1Databases: ["DB"],
    }),
  );
  try {
    const db = await mf.getD1Database("DB");
    await db.exec(schema.replace(/^--.*$/gm, "").replaceAll("\n", " "));
    const quota = (ip, now) =>
      mf.dispatchFetch(`https://x/quota?ip=${ip}&now=${now}`);
    const now = 1794873600000;
    const concurrent = await Promise.all(
      Array.from({ length: 12 }, () => quota("same", now)),
    );
    assert.equal(concurrent.filter((r) => r.status === 200).length, 2);
    assert.ok(
      concurrent
        .filter((r) => r.status === 429)
        .every((r) => Number(r.headers.get("retry-after")) > 0),
    );
    for (let i = 1; i < 5; i++) {
      assert.equal((await quota("same", now + i * 60000)).status, 200);
      assert.equal((await quota("same", now + i * 60000)).status, 200);
    }
    assert.equal((await quota("same", now + 5 * 60000)).status, 429);
    const others = await Promise.all(
      Array.from({ length: 70 }, (_, i) => quota(`other${i}`, now)),
    );
    assert.equal(others.filter((r) => r.status === 200).length, 50);
    const rows = await db
      .prepare(
        "SELECT bucket,attempts FROM ask_munora_usage WHERE bucket LIKE 'global:%'",
      )
      .all();
    assert.equal(rows.results[0].attempts, 60);
    assert.ok(
      !(
        await db.prepare("SELECT bucket FROM ask_munora_usage").all()
      ).results.some((r) => r.bucket.includes("same")),
    );
    await db.prepare("DELETE FROM ask_munora_usage").run();
    const answer = await mf.dispatchFetch("https://x/ask", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        schemaVersion: 1,
        city: "Manila",
        question: "How hot?",
        history: [],
      }),
    });
    assert.equal(answer.status, 200);
    const value = await answer.json();
    assert.equal(value.answer, "It is 30 °C.");
    assert.equal(value.source, "Open-Meteo");
    assert.equal(value.facts.length, 1);
    await db.exec("DROP TABLE ask_munora_usage");
    const unavailable = await mf.dispatchFetch("https://x/ask", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        schemaVersion: 1,
        city: "Manila",
        question: "How hot?",
        history: [],
      }),
    });
    assert.equal(unavailable.status, 503);
  } finally {
    await mf.dispose();
  }
});
test("authoritative context adapter runs in workerd with multi-chunk JSON and caller abort", async () => {
  const weather = readFileSync(
    new URL("../src/weather.mjs", import.meta.url),
    "utf8",
  ).replaceAll("export ", "");
  const context = readFileSync(
    new URL("../src/assistant_context.mjs", import.meta.url),
    "utf8",
  )
    .replace(/^import .*;\n/gm, "")
    .replaceAll("export ", "");
  const artifact = readFileSync(
    new URL("../../assets/models/rain_model.json", import.meta.url),
    "utf8",
  );
  // Wrap weather declarations to avoid its unrelated code/units helpers colliding.
  const script = `const readJson=(()=>{${weather};return readJson;})();const model=${artifact};${context};
 export default {async fetch(){const now=1794873600000;const fields={temperature_2m:['°C',30],apparent_temperature:['°C',33],wind_speed_10m:['m/s',2],relative_humidity_2m:['%',80],pressure_msl:['hPa',1010],weather_code:['wmo code',1]};const hs={temperature_2m:fields.temperature_2m,apparent_temperature:fields.apparent_temperature,wind_speed_10m:fields.wind_speed_10m,weather_code:fields.weather_code,precipitation_probability:['%',20],uv_index:['',2]};const data={current:{time:now/1000,...Object.fromEntries(Object.entries(fields).map(([k,v])=>[k,v[1]]))},current_units:{time:'unixtime',...Object.fromEntries(Object.entries(fields).map(([k,v])=>[k,v[0]]))},hourly:{time:Array.from({length:72},(_,i)=>now/1000+i*3600),...Object.fromEntries(Object.entries(hs).map(([k,v])=>[k,Array(72).fill(v[1])]))},hourly_units:{time:'unixtime',...Object.fromEntries(Object.entries(hs).map(([k,v])=>[k,v[0]]))}};const city={name:'Manila',slug:'manila',latitude:14.6,longitude:121};const controller=new AbortController();const c=await getAssistantContext(city,now,controller.signal,async(u,o)=>{if(!u.search.includes('pressure_msl')||o.redirect!=='manual')throw Error('bad request');const bytes=new TextEncoder().encode(JSON.stringify(data));return new Response(new ReadableStream({start(c){c.enqueue(bytes.slice(0,101));c.enqueue(bytes.slice(101));c.close();}}));});return Response.json({hours:c.hourly.length,facts:c.facts.length,pressure:c.facts.find(f=>f.id==='pressure').value});}};`;
  const mf = new Miniflare(
    convertV4MiniflareOptions({
      name: "context-test",
      modules: true,
      compatibilityDate: "2026-11-12",
      script,
    }),
  );
  try {
    const r = await mf.dispatchFetch("https://x");
    assert.equal(r.status, 200);
    assert.deepEqual(await r.json(), {
      hours: 36,
      facts: 43,
      pressure: "1010 hPa",
    });
  } finally {
    await mf.dispose();
  }
});

for (const race of [false, true]) {
  test(`global exhaustion ${race ? 'between read and write' : 'before request'} cannot allocate per-IP state`, async () => {
    const now = 1794873600000;
    const day = Math.floor(now / 86400000);
    const script = `const cities=[];const getAssistantContext=()=>{};${ask}
      export default {async fetch(r,env){
        let injected=false; const real=env.DB;
        const db={prepare(sql){return {bind(...args){const bound=real.prepare(sql).bind(...args);return {
          run:()=>bound.run(),first:async()=>{
            if(${race} && !injected && sql.startsWith('INSERT')){
              injected=true;await real.prepare('INSERT OR REPLACE INTO ask_munora_usage VALUES(?,60,?)').bind('global:${day}',${(day + 1) * 86400000}).run();
            }
            return bound.first();
          }
        }}}}};
        try{await claimQuota(db,r.headers.get('cf-connecting-ip'),${now});return new Response('unexpected');}
        catch(e){return Response.json({code:e.code},{status:e.status||503,headers:{'Retry-After':String(e.retry||0)}});}
      }};`;
    const mf = new Miniflare(convertV4MiniflareOptions({
      name: 'quota-allocation-guard', modules: true,
      compatibilityDate: '2026-11-12', script, d1Databases: ['DB'],
    }));
    try {
      const db = await mf.getD1Database('DB');
      await db.exec(schema.replace(/^--.*$/gm, '').replaceAll('\n', ' '));
      if (!race) await db.prepare('INSERT INTO ask_munora_usage VALUES(?,60,?)')
        .bind(`global:${day}`, (day + 1) * 86400000).run();
      for (let i = 1; i <= 3; i++) {
        const r = await mf.dispatchFetch('https://fixture.invalid/quota', {
          headers: {'cf-connecting-ip': `192.0.2.${i}`},
        });
        assert.equal(r.status, 429);
        assert.equal(Number(r.headers.get('retry-after')), 86400);
      }
      const rows = await db.prepare('SELECT bucket,attempts FROM ask_munora_usage').all();
      assert.deepEqual(rows.results, [{bucket: `global:${day}`, attempts: 60}]);
    } finally { await mf.dispose(); }
  });
}
