import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/weather_insights.dart';

import 'weather_insights_test.dart' show detailFixture;

void main() {
  test('cached detail remains timestamped reference and cannot pass live freshness', () async {
    final now = DateTime.utc(2026, 11, 16, 5);
    SharedPreferences.setMockInitialValues({});
    final online = WeatherInsightsService(
      now: () => now,
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(detailFixture(now))),
          200,
        ),
      ),
    );
    await online.fetch('Manila');
    online.dispose();
    final offline = WeatherInsightsService(
      now: () => now.add(const Duration(hours: 2)),
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    addTearDown(offline.dispose);
    final saved = await offline.cached('Manila');
    expect(saved, isNotNull);
    expect(saved!.saved, isTrue);
    expect(saved.fetchedAt, now);
    expect(saved.hours, isNotEmpty);
    expect(saved.isFresh(now), isFalse);
    final fallback = await offline.fetch('Manila');
    expect(fallback.saved, isTrue);
    expect(fallback.fetchedAt, now);
  });
}
