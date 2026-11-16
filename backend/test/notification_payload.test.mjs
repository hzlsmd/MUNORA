import {test} from 'node:test';
import assert from 'node:assert/strict';
import {notificationMessage, legacyNotificationMessage} from '../src/fcm.mjs';
import {cities} from '../src/cities.mjs';
test('data-only delivery lets Android honor category and quiet-hour preferences in background', () => {
 const now = Date.now();
 const {message} = notificationMessage(cities[0], ['rain','storm'], now, now/1000);
 assert.equal(message.notification, undefined);
 assert.equal(message.android.notification, undefined);
 assert.equal(message.android.priority, 'high');
 assert.deepEqual(JSON.parse(message.data.triggers), ['rain','storm']);
 const tips = JSON.parse(message.data.recommendations);
 assert.match(tips.rain, /umbrella/i);
 assert.match(tips.storm, /indoor|outdoor/i);
 assert.ok(Buffer.byteLength(JSON.stringify(message)) < 4096);
});
import {weatherTriggers} from '../src/weather.mjs';
const now = Date.UTC(2026,10,16,5);
function clearWeather() { return {
 current_units:{time:'unixtime',temperature_2m:'°C',apparent_temperature:'°C',weather_code:'wmo code',wind_speed_10m:'m/s'},
 hourly_units:{time:'unixtime',weather_code:'wmo code',temperature_2m:'°C',apparent_temperature:'°C',wind_speed_10m:'m/s'},
 current:{time:now/1000,temperature_2m:28,apparent_temperature:29,wind_speed_10m:2,weather_code:0},
 hourly:{time:Array.from({length:8},(_,i)=>now/1000+i*3600),weather_code:Array(8).fill(0),temperature_2m:Array(8).fill(28),apparent_temperature:Array(8).fill(29),wind_speed_10m:Array(8).fill(2)}
}; }
test('clear suggestion only accompanies sampled calm daytime weather', () => {
 assert.deepEqual(weatherTriggers(clearWeather(),now),['clear']);
 const weather = clearWeather(); weather.current.weather_code=3;
 assert.deepEqual(weatherTriggers(weather,now),[]);
});
test('forecast heat and wind trigger from validated upcoming readings', () => {
 const weather = clearWeather(); weather.hourly.temperature_2m[2]=36; weather.hourly.wind_speed_10m[2]=12;
 assert.deepEqual(weatherTriggers(weather,now),['heat','wind']);
 weather.hourly_units.wind_speed_10m='km/h';
 assert.throws(()=>weatherTriggers(weather,now));
});

test('legacy payload keeps older installed clients working on their original topic', () => {
 const now=Date.now(); const {message}=legacyNotificationMessage(cities[0],['rain'],now,now/1000);
 assert.equal(message.topic,'munora_weather_muntinlupa');
 assert.match(message.notification.body,/umbrella/i);
 assert.equal(message.android.notification.channel_id,'weather_tips');
 assert.equal(notificationMessage(cities[0],['rain'],now,now/1000).message.topic,'munora_weather_muntinlupa_v2');
});
test('push fingerprints include changing rain probability and UV intensity', () => {
 const weather=clearWeather(); weather.hourly.precipitation_probability=Array(8).fill(60); weather.hourly.uv_index=Array(8).fill(8);
 const before=JSON.parse(notificationMessage(cities[0],['rain','uv'],now,now/1000,weather).message.data.fingerprints);
 weather.hourly.precipitation_probability.fill(100); weather.hourly.uv_index.fill(15);
 const after=JSON.parse(notificationMessage(cities[0],['rain','uv'],now,now/1000,weather).message.data.fingerprints);
 assert.notEqual(before.rain,after.rain); assert.notEqual(before.uv,after.uv);
});
