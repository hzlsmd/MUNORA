import 'package:flutter_test/flutter_test.dart';
import 'package:munora/widgets/weather_scene.dart';

void main() {
  test('provider codes select distinct offline scenes', () {
    expect(skyState(0), SkyState.clear);
    expect(skyState(2), SkyState.partlyCloudy);
    expect(skyState(3), SkyState.cloudy);
    expect(skyState(65), SkyState.rain);
    expect(skyState(95), SkyState.storm);
    expect(skyState(45), SkyState.fog);
    expect(skyState(85), SkyState.snow);
    expect(skyState(null), SkyState.unknown);
  });
}
