# MUNORA (Flutter)

This is a Flutter/Dart port of the MUNORA weather app, rebuilt screen-for-screen
from the original React/Figma-Make source (colors, gradients, spacing, copy,
and mock data all carried over 1:1). Splash → Home → Forecast → Alerts → AI.

## Project structure

```
lib/
  main.dart              # entrypoint
  app.dart                # MaterialApp + screen router (mirrors old App.tsx)
  theme.dart               # colors, gradients, shared card decoration
  models/city_weather.dart # data classes
  data/mock_data.dart      # mock weather data (ported from the original)
  widgets/
    bottom_nav.dart        # bottom tab bar + AppScreen enum
    weather_icon.dart       # condition string -> icon mapping
  screens/
    splash_screen.dart
    home_screen.dart        # hero, city picker modal, stats, hourly carousel
    forecast_screen.dart    # hourly/weekly tabs
    alerts_screen.dart
    ai_screen.dart           # insights, recommendations, chat modal
```

## 1. Install Flutter

If you don't have it yet: <https://docs.flutter.dev/get-started/install>

Verify with:

```bash
flutter doctor
```

## 2. Get dependencies

```bash
cd munora
flutter pub get
```

## 3. Run it

```bash
flutter run
```

Pick a connected device/emulator, or run `flutter run -d chrome` to try it in
a browser first.

## 4. Build for release

```bash
flutter build apk        # Android
flutter build ios        # iOS (needs a Mac + Xcode)
flutter build web        # Web
```

## What's mocked vs. real

Just like the original export, **all weather data here is hardcoded** in
`lib/data/mock_data.dart` — 17 NCR cities, hourly points, a 7-day forecast,
and canned alerts/AI responses. Nothing calls a real API yet.

## Next steps to make it "real"

1. **Live weather data** — add the `http` package, pick a weather API
   (OpenWeatherMap, WeatherAPI, or PAGASA for PH-specific alerts), and fetch
   into `HomeScreen`/`ForecastScreen`/`AlertsScreen` with `FutureBuilder` or
   a state-management solution (Provider/Riverpod/Bloc) instead of raw
   `setState`.
2. **Real AI chat** — `AIScreen`'s chat currently just echoes a random canned
   response after a 1.2s delay (see `_ChatModalState.sendMessage`). Swap that
   for a real call to an LLM API (e.g. Anthropic's Messages API via `http`).
3. **City search/geocoding** — the city picker is a fixed list of 17 cities;
   wire it to a geocoding API if you want arbitrary city search.
4. **Weather icons** — `lib/widgets/weather_icon.dart` currently maps
   conditions to Material icons for simplicity. If you want the original's
   hand-drawn animated SVG icons (sun rays spinning, rain falling, etc.),
   port them to Flutter as `CustomPainter`s with `AnimationController`s, or
   use a package like `weather_icons`.
5. **App icon/splash config** — use `flutter_launcher_icons` and
   `flutter_native_splash` packages to set the real app icon and native
   splash screen (the in-app `SplashScreen` widget currently just fakes it
   with a 3-second timer).

## Notes

- Built for **Flutter 3.x / Dart 3.x** (`environment.sdk: '>=3.3.0 <4.0.0'`
  in `pubspec.yaml`).
- Uses `google_fonts` for Poppins (matches the original's font choice) — no
  manual font files needed, it fetches at runtime.
- This code was written and reviewed carefully, but wasn't compiled with the
  actual Flutter SDK (not available in this environment) — run `flutter
  analyze` after `pub get` and let me know if anything needs fixing.
