import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/widgets/insight_panels.dart';

void main() {
  testWidgets('feedback reason persists locally and clearing removes it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GuidanceFeedback(city: 'Manila')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Not helpful'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Timing did not fit'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('tips.feedback.reason.Manila'),
      'Timing did not fit',
    );
    await tester.tap(find.text('Clear feedback'));
    await tester.pumpAndSettle();
    expect(prefs.getInt('tips.feedback.Manila'), isNull);
    expect(prefs.getString('tips.feedback.reason.Manila'), isNull);
  });
}
