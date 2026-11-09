# MUNORA deployment status

The Flutter app requests Open-Meteo directly and stores preferences, feedback and
cached weather on the device. Android weather notifications use local delivery
and periodic background checks. No Firebase SDK or backend is required.

The dormant Firebase backend, deployment configuration and backend CI job were
removed from the repository on 9 November 2026. No cloud resources were deleted
or changed. Previous records described the `munora-weather-hzlsmd` project on Spark
with Firestore deny-all rules and no deployed weather function; that historical
status has not been reverified against the live cloud project.

The historical OpenWeatherMap credential still requires owner revocation if that
has not already been done. The current Open-Meteo flow requires no replacement key.

See [weather setup](WEATHER_SETUP.md) for the current run and build instructions.
