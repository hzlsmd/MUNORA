import 'package:flutter_test/flutter_test.dart';
import 'package:munora/services/push_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('topic contract and notification timestamps are validated', () {
    expect(cityTopic('Quezon City'), 'munora_weather_quezon_city');
    expect(() => cityTopic('Unknown'), throwsArgumentError);
    final now = DateTime.utc(2026, 11, 12, 8);
    final payload = {
      'city': 'Manila',
      'eventId': 'manila:123',
      'issuedAt': now.toIso8601String(),
      'route': 'alerts',
    };
    expect(PushAlert.parse(payload, now)?.city, 'Manila');
    expect(PushAlert.parse(payload, now.add(const Duration(hours: 2))), isNull);
    expect(PushAlert.parse({...payload, 'city': 'unknown'}, now), isNull);
    expect(PushAlert.parse({...payload, 'route': 'other'}, now), isNull);
  });
  test(
    'failed unsubscribe is persisted and retried before changing city',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final actions = <String>[];
      var fail = false;
      final state = PushSubscriptions(
        prefs,
        subscribe: (topic) async => actions.add('subscribe:$topic'),
        unsubscribe: (topic) async {
          actions.add('unsubscribe:$topic');
          if (fail) throw StateError('offline');
        },
      );
      await state.reconcile(enabled: true, city: 'Manila');
      fail = true;
      await expectLater(
        state.reconcile(enabled: true, city: 'Makati'),
        throwsStateError,
      );
      expect(
        actions.where((a) => a == 'subscribe:munora_weather_makati'),
        isEmpty,
      );
      fail = false;
      await state.reconcile(enabled: true, city: 'Makati');
      expect(actions.last, 'subscribe:munora_weather_makati');
      await state.reconcile(enabled: false, city: 'Makati');
      expect(prefs.getStringList(PushSubscriptions.knownKey), isEmpty);
    },
  );
  test('ambiguous subscribe is cleaned up after restart and opt-out', () async {
    final prefs = await SharedPreferences.getInstance();
    final state = PushSubscriptions(
      prefs,
      subscribe: (_) async => throw StateError('timeout'),
      unsubscribe: (_) async {},
    );
    await expectLater(
      state.reconcile(enabled: true, city: 'Manila'),
      throwsStateError,
    );
    final cleaned = <String>[];
    await PushSubscriptions(
      prefs,
      subscribe: (_) async {},
      unsubscribe: (t) async => cleaned.add(t),
    ).reconcile(enabled: false, city: 'Manila');
    expect(cleaned, ['munora_weather_manila']);
  });
}
