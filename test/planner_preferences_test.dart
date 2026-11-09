import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/planner_preferences.dart';
import 'package:munora/services/activity_planner.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('routine persists by city and can be removed', () async {
    final store = PlannerPreferences();
    await store.saveRoutine(
      'Manila',
      const ActivityRoutine(
        activity: Activity.exercise,
        hour: 7,
        durationHours: 2,
      ),
    );
    expect((await store.loadRoutine('Manila'))?.activity, Activity.exercise);
    expect(await store.loadRoutine('Muntinlupa'), isNull);
    await store.saveRoutine('Manila', null);
    expect(await store.loadRoutine('Manila'), isNull);
  });
  test('routine computes next PHT occurrence across midnight', () {
    const routine = ActivityRoutine(
      activity: Activity.walk,
      hour: 7,
      durationHours: 1,
    );
    expect(
      routine.nextStart(DateTime.utc(2026, 11, 9, 23)),
      DateTime.utc(2026, 11, 9, 23),
    );
    expect(
      routine.nextStart(DateTime.utc(2026, 11, 9, 23, 1)),
      DateTime.utc(2026, 11, 10, 23),
    );
  });
  test('corrupt and unsupported routine values are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'planner.routine.Manila': '{"activity":"fly","hour":99,"duration":8}',
    });
    expect(await PlannerPreferences().loadRoutine('Manila'), isNull);
  });
}
