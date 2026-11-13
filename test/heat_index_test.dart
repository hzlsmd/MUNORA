import 'package:flutter_test/flutter_test.dart';
import 'package:munora/services/heat_index.dart';

void main() {
  test('matches NWS chart near 90 F and 70 percent humidity', () {
    expect(heatIndexCelsius(32.2222222222, 70), closeTo(41.1, 0.15));
  });
  test('high humidity at 80 F is near the NWS 86 F chart value', () {
    expect(heatIndexCelsius(26.6666666667, 90), closeTo(30, 0.6));
  });
  test('extreme humid combinations do not display polynomial extrapolations', () {
    expect(heatIndexCelsius(44.4, 100), isNull);
  });
  test('cool, extreme and invalid inputs are not extrapolated', () {
    for (final t in [20.0, 50.0, double.nan, double.infinity]) {
      expect(heatIndexCelsius(t, 70), isNull);
    }
    expect(heatIndexCelsius(32, -1), isNull);
    expect(heatIndexCelsius(32, 101), isNull);
    expect(heatIndexCelsius(32, double.nan), isNull);
  });
}
