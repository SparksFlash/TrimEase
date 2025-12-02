// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:barberapp/main.dart';

void main() {
  testWidgets('Auth page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(firebaseAvailable: false));
    // Allow routing to /auth and animations to settle
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Expect to find the app title from the AuthPage header
    expect(find.text('TrimEase'), findsOneWidget);
  });
}
