# Dimensional Weather Icons

The shared WeatherIcon now paints shaded, highlighted, layered weather artwork instead of flat Material weather glyphs. This is a 3D-style illustration rendered on Flutter Canvas, not a mesh/3D engine. Home and all forecast samples use the same widget. Navigation and command icons keep familiar symbols.

Sun rays, clouds, rain, snow, wind and lightning move gently for 2.4 seconds when shown or when conditions change, then settle to conserve battery. Reduced-motion settings and disabled TickerMode stop the animation. Each icon has fixed bounds, a semantic condition label, and an isolated repaint boundary. No remote assets or new packages are required.

Light-rain matching now reaches the drizzle variant rather than being consumed by the generic rain branch. Thunderstorms retain priority.

Verification: 45 Flutter tests pass; analysis is clean; release web build succeeds. Tests cover the mapping regression, fixed layout, all 11 variants, reduced motion, and different raster pixels across animation frames. The initial raster test stalled because image readback needed tester.runAsync; that test-harness issue was corrected and the full suite rerun successfully. No native phone rendering/profile claims are made.

This branch builds on codex/weather-notifications to preserve that feature. Merge the notification work first, then the icon update.

Browser fixture checks of Home and Forecast at 390x900 and 1366x900 produced no JavaScript errors. Screenshots were visually inspected for icon rendering, framing and overlap. These checks use synthetic weather and do not measure native phone performance.
