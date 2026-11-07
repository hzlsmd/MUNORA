import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/weather_service.dart';
import 'package:munora/widgets/weather_view.dart';
import 'weather_fixture.dart';

class FakeWeatherService extends WeatherService {
  final requests = <String, Completer<WeatherSnapshot>>{};
  WeatherSnapshot? saved;
  @override
  Future<WeatherSnapshot?> cached(String city) async =>
      saved?.city == city ? saved : null;
  @override
  Future<WeatherSnapshot> fetch(String city) =>
      (requests[city] = Completer<WeatherSnapshot>()).future;
}

Widget view(FakeWeatherService service, String city) => MaterialApp(
        home: Scaffold(
      body: WeatherView(
          city: city,
          service: service,
          builder: (snapshot) =>
              Center(child: Text('Weather for ${snapshot.city}'))),
    ));

void main() {
  testWidgets('loading, failure and retry work without sign-in',
      (tester) async {
    final service = FakeWeatherService();
    addTearDown(service.dispose);
    await tester.pumpWidget(view(service, 'Muntinlupa'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.requests['Muntinlupa']!
        .completeError(const WeatherException('Check your connection.'));
    await tester.pumpAndSettle();
    expect(find.text('Check your connection.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    service.requests['Muntinlupa']!
        .complete(WeatherSnapshot.fromJson(weatherFixture()));
    await tester.pumpAndSettle();
    expect(find.text('Weather for Muntinlupa'), findsOneWidget);
  });

  testWidgets('saved weather remains visible after an update fails',
      (tester) async {
    final service = FakeWeatherService()
      ..saved = WeatherSnapshot.fromJson(weatherFixture());
    addTearDown(service.dispose);
    await tester.pumpWidget(view(service, 'Muntinlupa'));
    await tester.pump();
    service.requests['Muntinlupa']!
        .completeError(const WeatherException('Connection unavailable.'));
    await tester.pumpAndSettle();
    expect(find.text('Weather for Muntinlupa'), findsOneWidget);
    expect(find.textContaining('Saved weather.'), findsOneWidget);
    expect(find.textContaining('Observed'), findsOneWidget);
  });

  testWidgets('late responses cannot replace a newly selected city',
      (tester) async {
    final service = FakeWeatherService();
    addTearDown(service.dispose);
    await tester.pumpWidget(view(service, 'Muntinlupa'));
    await tester.pump();
    await tester.pumpWidget(view(service, 'Manila'));
    await tester.pump();
    service.requests['Manila']!
        .complete(WeatherSnapshot.fromJson(weatherFixture(city: 'Manila')));
    await tester.pumpAndSettle();
    service.requests['Muntinlupa']!
        .complete(WeatherSnapshot.fromJson(weatherFixture()));
    await tester.pumpAndSettle();
    expect(find.text('Weather for Manila'), findsOneWidget);
    expect(find.text('Weather for Muntinlupa'), findsNothing);
  });
}
