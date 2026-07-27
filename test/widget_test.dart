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

  testWidgets('signs in and navigates between the main destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAppToLogin(tester);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Fresh rides from your people'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Find the road—and people—you haven’t met yet.'),
      findsOneWidget,
    );
    expect(find.text('Explore your way'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Plan').last);
    await tester.pumpAndSettle();
    expect(find.text('Plan a ride'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Rides').last);
    await tester.pumpAndSettle();
    expect(find.text('My rides'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Alex Rider'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
