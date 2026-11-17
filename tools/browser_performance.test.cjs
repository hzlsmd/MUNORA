const test = require('node:test');
const assert = require('node:assert/strict');
const { providerFixture, allowedPreview } = require('./weather_benchmark_fixture.cjs');
const now = new Date('2026-11-17T00:15:00Z');
test('current provider fixture uses supported schema, units and consecutive forecast', () => {
  const data = providerFixture(new URL('https://api.open-meteo.com/v1/forecast?latitude=14.5995&current=temperature_2m'),now);
  assert.equal(data.current_units.time,'unixtime');
  assert.equal(data.current_units.pressure_msl,'hPa');
  assert.equal(data.current.temperature_2m,28);
  assert.equal(data.hourly.time.length,144);
  assert.equal(data.hourly.time[1]-data.hourly.time[0],3600);
  assert.equal(data.hourly_units.temperature_2m,'°C');
});
test('optional hourly fixture returns requested units and bounded model arrays', () => {
  const data = providerFixture(new URL('https://api.open-meteo.com/v1/forecast?latitude=14.4081&hourly=uv_index,precipitation_probability,precipitation_ecmwf_ifs025,wind_speed_10m'),now);
  assert.equal(data.hourly.time.length,72);
  assert.equal(data.hourly_units.uv_index,'');
  assert.equal(data.hourly_units.precipitation_probability,'%');
  assert.equal(data.hourly_units.precipitation_ecmwf_ifs025,'mm');
  assert.equal(data.hourly_units.wind_speed_10m,'m/s');
  assert.equal(data.hourly.uv_index.length,72);
});
test('benchmark accepts only explicit isolated-loopback preview URLs', () => {
  for(const url of ['http://127.0.0.1:8083','http://localhost:8083']) assert.equal(allowedPreview(url),true);
  for(const url of ['https://weather.example','http://127.0.0.1.evil.test','http://user:pass@127.0.0.1:8083','file:///tmp/app']) assert.equal(allowedPreview(url),false);
});
test('multi-model precipitation uses provider-expanded field names', () => {
  const data = providerFixture(new URL('https://api.open-meteo.com/v1/forecast?hourly=precipitation&models=ecmwf_ifs025,gfs_seamless,icon_seamless'),now);
  for(const model of ['ecmwf_ifs025','gfs_seamless','icon_seamless']) {
    assert.equal(data.hourly_units[`precipitation_${model}`],'mm');
    assert.equal(data.hourly[`precipitation_${model}`].length,72);
  }
});
test('fixture routing rejects unexpected hosts and provider paths', () => {
  const {classifyRequest} = require('./weather_benchmark_fixture.cjs');
  const origin='http://127.0.0.1:8083';
  assert.equal(classifyRequest(new URL(origin+'/main.dart.js'),origin),'preview');
  assert.equal(classifyRequest(new URL('https://api.open-meteo.com/v1/forecast?city=ignored'),origin),'weather');
  for(const value of ['https://evil.example/v1/forecast','https://api.open-meteo.com@evil.example/v1/forecast','https://api.open-meteo.com/v1/admin','http://api.open-meteo.com/v1/forecast']) {
    assert.equal(classifyRequest(new URL(value),origin),'blocked');
  }
});
