import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munora/services/weather_insights.dart';
import 'package:munora/widgets/insight_panels.dart';

void main() {
  testWidgets(
    'confidence level exposes its measured basis and handles missing comparison',
    (tester) async {
      Widget panel(int? score) => MaterialApp(
        home: Scaffold(
          body: ModelAgreementPanel(
            insights: WeatherInsights(
              fetchedAt: DateTime.now(),
              agreementPercent: score,
            ),
          ),
        ),
      );
      await tester.pumpWidget(panel(100));
      expect(find.text('Model Prediction Confidence'), findsOneWidget);
      expect(find.text('High · 100% model agreement'), findsOneWidget);
      expect(
        find.textContaining('not measured forecast accuracy'),
        findsOneWidget,
      );
      await tester.pumpWidget(panel(67));
      expect(find.text('Low · 67% model agreement'), findsOneWidget);
      await tester.pumpWidget(panel(null));
      expect(find.text('Unavailable — no complete comparison'), findsOneWidget);
    },
  );
}
