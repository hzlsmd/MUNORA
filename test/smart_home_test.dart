import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/widgets/smart_home.dart';
import 'package:munora/widgets/weather_view.dart';

import 'weather_fixture.dart';

void main() {
  testWidgets(
    'home guidance explains actual rain and labels rules separately from AI',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeatherLiveStatus(
                isLive: true,
                child: SmartHome(
                  weather: WeatherSnapshot.fromJson(weatherFixture()),
                  onPlan: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Smart Recommendations'), findsOneWidget);
      expect(find.textContaining('Rule-based'), findsOneWidget);
      expect(find.textContaining('umbrella'), findsOneWidget);
      expect(find.textContaining('light rain'), findsOneWidget);
    },
  );
}
