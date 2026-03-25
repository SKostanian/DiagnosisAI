import 'package:diagnosis_ai/screens/auth_screen.dart';
import 'package:diagnosis_ai/services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {

    // we can mock shard preferences

    // Singh, P. (2025) Ultimate guide to using shared preferences in Flutter, Medium. Available at: https://medium.com/easy-flutter/ultimate-guide-to-using-shared-preferences-in-flutter-711efd28c2ec (Accessed: March 25, 2026).

    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    // reset before every test
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildApp({
    required VoidCallback onSkip,
    required ValueChanged<bool> onThemeChanged,
    bool isDarkMode = false,
  }) {
    return EasyLocalization(
      supportedLocales: const [Locale('en')],
      fallbackLocale: const Locale('en'),
      path: 'unused',
      assetLoader: const TestLoader(),
      child: Builder(
        builder: (context) {
          return MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            // the routes
            routes: {
              '/email-register': (_) => const Scaffold(
                body: Center(child: Text('email page')),
              ),
              '/phone-sign_in': (_) => const Scaffold(
                body: Center(child: Text('phone page')),
              ),
              '/privacy': (_) => const Scaffold(
                body: Center(child: Text('privacy page')),
              ),
              '/terms': (_) => const Scaffold(
                body: Center(child: Text('terms page')),
              ),
              '/disclaimer': (_) => const Scaffold(
                body: Center(child: Text('disclaimer page')),
              ),
            },
            home: AuthScreen(
              onSkip: onSkip,
              isDarkMode: isDarkMode,
              onThemeChanged: onThemeChanged,
              // here I call fake auth
              authService: FakeAuthService(),
              showImages: false, // no images in tests
            ),
          );
        },
      ),
    );
  }

  // An introduction to widget testing (2026) Flutter.dev.
  // Available at: https://docs.flutter.dev/cookbook/testing/widget/introduction (Accessed: March 25, 2026).
  testWidgets('screen builds', (tester) async {
    await tester.pumpWidget(
      buildApp(
        onSkip: () {},
        onThemeChanged: (_) {},
      ),
    );
    // it calls pump repeatedly

    // pumpAndSettle method (2026) Flutter.dev. Available at: https://api.flutter.dev/flutter/flutter_test/WidgetTester/pumpAndSettle.html (Accessed: March 25, 2026).
    await tester.pumpAndSettle();

    // expect matches with keys in auth screen

    // Dart package (2026) Dart packages.
    // Available at: https://pub.dev/packages/test (Accessed: March 25, 2026).
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byKey(const Key('theme_switch')), findsOneWidget);
    expect(find.byKey(const Key('google_button')), findsOneWidget);
    expect(find.byKey(const Key('email_phone_button')), findsOneWidget);
    expect(find.byKey(const Key('skip_button')), findsOneWidget);
  });

  testWidgets('theme switch calls callback', (tester) async {
    bool changed = false;

    await tester.pumpWidget(
      buildApp(
        onSkip: () {},
        onThemeChanged: (_) {
          changed = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    // I can use .tap to simulate tap
    await tester.tap(find.byKey(const Key('theme_switch')));
    await tester.pump();

    expect(changed, true);
  });

  testWidgets('skip opens consent', (tester) async {
    await tester.pumpWidget(
      buildApp(
        onSkip: () {},
        onThemeChanged: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('skip_button')));
    await tester.pumpAndSettle();

    // check that consent buttons enabled
    expect(find.byKey(const Key('consent_checkbox')), findsOneWidget);
    expect(find.byKey(const Key('consent_accept_button')), findsOneWidget);
  });

  testWidgets('accept checkbox enables button', (tester) async {
    await tester.pumpWidget(
      buildApp(
        onSkip: () {},
        onThemeChanged: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('skip_button')));
    await tester.pumpAndSettle();

    final before = tester.widget<ElevatedButton>(
      find.byKey(const Key('consent_accept_button')),
    );
    // beore onPressed is null and after is not null

    expect(before.onPressed, isNull);

    await tester.tap(find.byKey(const Key('consent_checkbox')));
    await tester.pump();

    final after = tester.widget<ElevatedButton>(
      find.byKey(const Key('consent_accept_button')),
    );
    expect(after.onPressed, isNotNull);
  });

  testWidgets('dialog yes calls onSkip', (tester) async {
    bool skipped = false;

    SharedPreferences.setMockInitialValues({
      'consentAccepted': true,
    });

    await tester.pumpWidget(
      buildApp(
        onSkip: () {
          skipped = true;
        },
        onThemeChanged: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('skip_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog_yes')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dialog_yes')));
    await tester.pumpAndSettle();

    expect(skipped, true);
  });

  testWidgets('email phone opens sheet', (tester) async {
    SharedPreferences.setMockInitialValues({
      'consentAccepted': true,
    });

    await tester.pumpWidget(
      buildApp(
        onSkip: () {},
        onThemeChanged: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('email_phone_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('email_option')), findsOneWidget);
    expect(find.byKey(const Key('phone_option')), findsOneWidget);
  });
}

// fake auth for tests
class FakeAuthService implements AuthService {
  @override
  User? get currentUser => null;

  // Stream.empty constructor - Stream - dart:async library - Dart API (2026) Dart.dev.
  // Available at: https://api.dart.dev/dart-async/Stream/Stream.empty.html (Accessed: March 25, 2026).

  @override
  // no events and stream empty
  Stream<User?> get userChanges => const Stream.empty();

  @override
  bool shouldShowAccountHeader(User u) => false;

  @override
  Future<User?> signInWithGoogle({bool forceChooseAccount = false}) async {
    return null;
  }

  @override
  Future<void> signOutAll() async {}

  // noSuchMethod method (2026) Flutter.dev.
  // Available at: https://api.flutter.dev/flutter/dart-core/Object/noSuchMethod.html (Accessed: March 25, 2026).
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// translations for test
class TestLoader extends AssetLoader {
  const TestLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'auth.dialog_are_you_sure': 'Are you sure?',
      'auth.dialog_not_saved': 'Data will not be saved',
      'auth.no': 'No',
      'auth.yes': 'Yes',
      'auth.continue_google': 'Continue with Google',
      'auth.sign_in_email_phone': 'Sign in with email or phone',
      'auth.skip_registration': 'Skip registration',
      'auth.sign_in_using': 'Sign in using',
      'auth.email_password': 'Email and password',
      'auth.phone_number': 'Phone number',
      'auth.or': 'or',
      'auth.google_failed': 'Google failed',
      'auth.welcome': 'Welcome',
      'auth.signed_in_as': 'Signed in as',
      'auth.continue': 'Continue',
      'auth.signed_out': 'Signed out',
      'auth.switched_account': 'Switched account',
      'auth.google_use_another': 'Use another Google account',
      'auth.sign_out': 'Sign out',
      'auth.email_unverified_banner': 'Email is not verified',
      'auth.verify_now': 'Verify now',
      'auth.title_part1': 'Your ',
      'auth.title_highlight': 'health ',
      'auth.title_part2': 'assistant',
      'consent.title': 'Consent',
      'consent.description': 'Please accept',
      'consent.privacy_policy': 'Privacy Policy',
      'consent.terms_of_use': 'Terms of Use',
      'consent.medical_disclaimer': 'Medical Disclaimer',
      'consent.accept_checkbox': 'I agree',
      'consent.accept_button': 'Accept',
      'consent.decline': 'Decline',
    };
  }
}