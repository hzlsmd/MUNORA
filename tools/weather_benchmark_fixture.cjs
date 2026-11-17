// Development-only deterministic fixtures. Never imported by the app/backend.
function allowedPreview(value) {
  try {
    const u = new URL(value);
    return u.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(u.hostname) && !u.username && !u.password;
  } catch { return false; }
}
function providerFixture(url, now = new Date()) {
  const q = url.searchParams;
  const manila = q.get('latitude') === '14.5995';
  const start = Math.floor(+now / 3600000) * 3600;
  const count = q.has('current') ? 144 : 72;
  const hourly = {time: Array.from({length: count}, (_,i) => start+i*3600)};
  const hourly_units = {time: 'unixtime'};
  const values = {
    temperature_2m: ['°C',manila ? 28 : 33], apparent_temperature: ['°C',manila ? 30 : 36],
    relative_humidity_2m: ['%',80], pressure_msl: ['hPa',1010],
    wind_speed_10m: ['m/s',manila ? 2 : 12], weather_code: ['wmo code',manila ? 0 : 95],
    precipitation_probability: ['%',manila ? 10 : 80], uv_index: ['',3],
  };
  const fields = q.has('current') ? ['temperature_2m','weather_code'] : q.has('models') ? q.get('models').split(',').map(model => `precipitation_${model}`) : (q.get('hourly') || '').split(',');
  for (const key of fields.filter(Boolean)) {
    const [unit,value] = values[key] || (key.startsWith('precipitation_') ? ['mm',.1] : []);
    if (unit === undefined) throw new Error(`Unrecognized fixture field: ${key}`);
    hourly[key] = Array(count).fill(value); hourly_units[key] = unit;
  }
  const data = {hourly,hourly_units};
  if (q.has('current')) {
    data.current = {time: Math.floor(+now/1000)}; data.current_units = {time:'unixtime'};
    for (const key of ['temperature_2m','apparent_temperature','relative_humidity_2m','pressure_msl','wind_speed_10m','weather_code']) {
      data.current[key]=values[key][1];data.current_units[key]=values[key][0];
    }
  }
  return data;
}
function classifyRequest(url, previewOrigin) {
  if (url.origin === previewOrigin) return 'preview';
  if (url.origin === 'https://api.open-meteo.com' && url.pathname === '/v1/forecast') return 'weather';
  return 'blocked';
}
module.exports = {allowedPreview,providerFixture,classifyRequest};
