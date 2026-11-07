# MUNORA deployment status

The Flutter app now defaults to direct Open-Meteo without a key or Firebase.
See [weather setup](WEATHER_SETUP.md). The Firebase status below describes the
dormant alternative backend, which remains blocked from deployment.

Verified on 7 November 2026:

- Project: `munora-weather-hzlsmd` (display name: MUNORA).
- Default Firestore database: Standard edition, Native mode, `asia-southeast1` (Singapore).
- Firestore rules deployed successfully. Direct client reads and writes are denied.
- The app still requires no user sign-in. Firebase Auth is not enabled by this setup.

Console: <https://console.firebase.google.com/project/munora-weather-hzlsmd/overview>

## Dormant Firebase option

The weather function is **not deployed**. Firebase rejected function deployment
because the project is on the Spark plan. Keep the project on Spark for this
non-commercial pilot; direct Open-Meteo does not require billing or a function.

The previously committed OpenWeatherMap key must be revoked in the provider's
account. No replacement provider key is needed for the default Open-Meteo flow.

Do not deploy or enable the alternative backend until a separate reviewed
App Check client integration lands and the owner approves its infrastructure
costs. Setting WEATHER_API_URL alone does not meet those requirements.
