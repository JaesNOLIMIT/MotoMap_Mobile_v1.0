import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motomap_mobile/config/supabase_config.dart';
import 'package:motomap_mobile/main.dart';
import 'package:motomap_mobile/screens/main_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
        pkceAsyncStorage: _TestAsyncStorage(),
      ),
    );
  });

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
      find.text('Create your verified MotoMap rider profile'),
      findsOneWidget,
    );
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('Birth Date'), findsOneWidget);
    expect(find.text('Uppercase'), findsOneWidget);
    expect(find.text('Lowercase'), findsOneWidget);
    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Special character'), findsOneWidget);
  });

  testWidgets('toggles password visibility', (tester) async {
    await pumpAppToLogin(tester);

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('requires valid credentials before sign in', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAppToLogin(tester);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Sign in to your rider profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates between the main destinations after authentication', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const MainShell(),
      ),
    );
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

class _TestAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }
}
