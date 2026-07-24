import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motomap_mobile/main.dart';

void main() {
  Future<void> pumpAppToLogin(WidgetTester tester) async {
    await tester.pumpWidget(const MotoMapApp());
    await tester.pumpAndSettle();
  }

  testWidgets('shows the splash screen before login', (tester) async {
    await tester.pumpWidget(const MotoMapApp());

    expect(find.text('Ride further, ride smarter'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Sign in to your rider profile'), findsOneWidget);
  });

  testWidgets('shows the MotoMap login screen', (tester) async {
    await pumpAppToLogin(tester);

    expect(find.text('MotoMap'), findsOneWidget);
    expect(find.text('Sign in to your rider profile'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('opens the create account sheet', (tester) async {
    await pumpAppToLogin(tester);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(
      find.text('Join MotoMap and start mapping your rides today'),
      findsOneWidget,
    );
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  testWidgets('toggles password visibility', (tester) async {
    await pumpAppToLogin(tester);

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
}
