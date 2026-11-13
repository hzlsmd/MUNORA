import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/widgets/weather_cards.dart';
import 'weather_fixture.dart';
void main() {
 testWidgets('heat index replaces pressure while preserving numeric AI inputs', (tester) async {
  final json=weatherFixture();
  json['current']['temperature']=32.2222222222;
  json['current']['humidity']=70;
  json['current']['weatherCode']=61;
  final data=WeatherSnapshot.fromJson(json);
  expect(data.humidity,70);
  expect(data.pressure,1010);
  expect(data.weatherCode,61);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:WeatherMetrics(weather:data.current))));
  expect(find.text('HEAT INDEX'),findsOneWidget);
  expect(find.text('PRESSURE'),findsNothing);
  expect(find.text('41.1°C'),findsOneWidget);
  expect(find.text('FEELS LIKE'),findsOneWidget);
 });
 test('invalid optional WMO codes cannot enter the ML feature inputs',(){
  final json=weatherFixture();json['current']['weatherCode']=999;
  expect(()=>WeatherSnapshot.fromJson(json),throwsFormatException);
 });
}
