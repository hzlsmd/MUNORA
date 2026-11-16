import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/saved_rain_insight.dart';
import 'package:munora/services/rain_model.dart';

void main() {
  test('validated AI result survives storage but expires and stays location-specific', () async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.utc(2026, 11, 16);
    await SavedRainInsight.save('Manila', RainPrediction(.75, now, 'test-v1'));
    expect((await SavedRainInsight.load('Manila', now))?.probability, .75);
    expect(await SavedRainInsight.load('Muntinlupa', now), isNull);
    expect(
      await SavedRainInsight.load('Manila', now.add(const Duration(days: 8))),
      isNull,
    );
  });
}
