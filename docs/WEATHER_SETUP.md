# Weather setup

## Default: direct Open-Meteo

Run `flutter pub get` and `flutter run` with an Android device/emulator connected.
No login, API key, Firebase project or WEATHER_API_URL define is needed. For a
Codespaces browser preview, run:

```sh
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

Open port 8080 in the Ports panel. For an Android debug APK, use
`flutter build apk --debug` after the Android SDK setup.

The app requests Open-Meteo directly for the selected city's fixed coordinates.
The provider sees your network IP and city coordinates; the app does not request
GPS access or send login credentials. Current conditions are model estimates,
not station observations or official warnings. The visible model timestamp and
local fetch/update time are distinct.

The adapter validates units, WMO codes, hourly array alignment/order, measurements
and age. Six days of hourly data supply at most 40 upcoming three-hour samples;
the UI groups the first five Philippine calendar dates. Daily ranges are sampled
temperature ranges, not full daily extrema. Ten-minute fresh reuse and concurrent
request sharing reduce traffic; manual refresh forces a request. Offline data is
labeled and expires after 24 hours. Provider caches use separate namespaces.

### Terms, attribution and scale

Checked 7 November 2026: the free endpoint is for non-commercial use, with limits
below 600 calls/minute, 5,000/hour, 10,000/day and a stated 300,000/month allowance.
Limits apply by IP/application; shared networks can reach them earlier. Review
the current [terms](https://open-meteo.com/en/terms) and
[pricing](https://open-meteo.com/en/pricing) before adding ads, subscriptions or
broad distribution. No paid plan is enabled.

Weather data is provided under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The app links to Open-Meteo and the license. Data is adapted into descriptions,
rounded display values and three-hour samples. These are third-party estimates
without an availability/accuracy guarantee. See the
[forecast API documentation](https://open-meteo.com/en/docs).

An explicit WEATHER_API_URL overrides the default for a compatible normalized
backend or fixture. Remove old placeholder defines from run configurations to
use Open-Meteo. This is a generic test/custom endpoint override, not a bundled backend.

## Local development and checks

UI development does not need Firebase credentials or a paid project:

```sh
flutter pub get
flutter run
```

The default build requests Open-Meteo. Existing tests inject fixture data and
consume no provider credentials:

```sh
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

`WEATHER_API_URL`, when explicitly supplied, is a public HTTPS endpoint address,
not a credential, and does not provision or enable a backend.

## Credential ownership and remaining milestones

Revoke the historical OpenWeatherMap key exposed in commit `1244f8c`. Removing it
from current source does not invalidate it. Revocation is owner action; never
paste a replacement into Dart, Git or chat. No replacement is needed for fixtures.

Alerts and Tips use live forecast data with documented rules. They do not run a
trained AI model or receive an official warning feed. Do not rely on this app as
the sole source of emergency warnings.

## Backend removal

The dormant Firebase Functions source, Firestore rules, project configuration and
backend CI job were removed from the repository on 9 November 2026. Current app
features use Open-Meteo and on-device storage. No Firebase cloud project, deployed
rules, database or other remote resources were changed. Historical audit reports
refer to the former implementation and are not current setup instructions.
