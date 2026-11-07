import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:munora/widgets/weather_icon.dart';

void main() {
  test('light precipitation has a drizzle icon rather than heavy rain', () {
    expect(weatherKindFor('Light rain'), WeatherKind.drizzle);
    expect(weatherKindFor('Heavy rain'), WeatherKind.rain);
    expect(
      weatherKindFor('Thunderstorm with heavy hail'),
      WeatherKind.thunderstorm,
    );
  });

  testWidgets('dimensional icons retain fixed size and accessible labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: WeatherIcon(condition: 'Thunderstorm', size: 80)),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.bySemanticsLabel('Thunderstorm'), findsOneWidget);
    final size = tester.getSize(find.byType(WeatherIcon));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(
        of: find.byType(WeatherIcon),
        matching: find.byType(RepaintBoundary),
      ),
    );
    final first = await tester.runAsync(() => boundary.toImage());
    final pixels = await tester.runAsync(
      () => first!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final second = await tester.runAsync(() => boundary.toImage());
    final movedPixels = await tester.runAsync(
      () => second!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(
      movedPixels!.buffer.asUint8List(),
      isNot(orderedEquals(pixels!.buffer.asUint8List())),
    );
    first!.dispose();
    second!.dispose();
    expect(tester.getSize(find.byType(WeatherIcon)), size);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('all weather variants paint without overflow at compact sizes', (
    tester,
  ) async {
    for (final condition in [
      'Sunny',
      'Partly cloudy',
      'Overcast',
      'Rain',
      'Drizzle',
      'Thunderstorm',
      'Snow',
      'Moon',
      'Fog',
      'Wind',
      'Night rain',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: WeatherIcon(condition: condition, size: 32)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: condition);
    }
  });

  testWidgets('reduced motion does not run an icon ticker', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: WeatherIcon(condition: 'Sunny', size: 80)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
