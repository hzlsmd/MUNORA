# MUNORA Firebase setup

Verified on 7 November 2026:

- Project: `munora-weather-hzlsmd` (display name: MUNORA).
- Default Firestore database: Standard edition, Native mode, `asia-southeast1` (Singapore).
- Firestore rules deployed successfully. Direct client reads and writes are denied.
- The app still requires no user sign-in. Firebase Auth is not enabled by this setup.

Console: <https://console.firebase.google.com/project/munora-weather-hzlsmd/overview>

## Remaining deployment requirements

The weather function is **not deployed**. Firebase rejected function deployment
because the project is on the Spark plan. Upgrade to Blaze using:
<https://console.firebase.google.com/project/munora-weather-hzlsmd/usage/details>

The previously committed OpenWeatherMap key must be revoked in the provider's
account. Configure its replacement as `OPENWEATHER_API_KEY` in Secret Manager;
do not put it in source or chat. See [Weather setup](WEATHER_SETUP.md) for commands.

After billing and the replacement secret are ready, deploy the weather function,
verify a live response, and build Flutter with the returned HTTPS function URL
as `WEATHER_API_URL`. There is no live weather endpoint yet.
