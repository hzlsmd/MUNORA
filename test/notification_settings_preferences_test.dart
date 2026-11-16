import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/widgets/notification_settings.dart';
import 'package:munora/services/notification_preferences.dart';

void main() {
  testWidgets(
    'category and quiet-hour controls persist real delivery preferences',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'notifications.weather.enabled': true,
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: NotificationSettings()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Weather notifications'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Weather notifications'),
            )
            .value,
        isTrue,
      );
      final clear = find.widgetWithText(
        CheckboxListTile,
        'Clear-weather suggestions',
      );
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(
        (await NotificationPreferences.load()).categories,
        contains('clear'),
      );
      final quiet = find.widgetWithText(
        SwitchListTile,
        'Quiet hours (including weather alerts)',
      );
      await tester.ensureVisible(quiet);
      await tester.tap(quiet);
      await tester.pumpAndSettle();
      final stored = await NotificationPreferences.load();
      expect(stored.quietStart, 22);
      expect(stored.quietEnd, 7);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
