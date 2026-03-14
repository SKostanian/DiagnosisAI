import 'package:diagnosis_ai/screens/web_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:diagnosis_ai/screens/auth_screen.dart';
import 'package:diagnosis_ai/screens/email_register.dart';
import 'package:diagnosis_ai/screens/email_sign_in.dart';
import 'package:diagnosis_ai/screens/phone_sign_in.dart';
import 'package:diagnosis_ai/screens/body_selection.dart';
import 'package:diagnosis_ai/screens/chat_screen.dart';

Future<void> _configureBackends() async {
  if (!kDebugMode) return;

  // Bizzotto, A. (2026) How to use defaultTargetPlatform and kIsWeb, Code With Andrea.
  // Available at: https://codewithandrea.com/tips/default-target-platform/ (Accessed: March 10, 2026).
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final host = isAndroid ? '10.0.2.2' : 'localhost';

  // Run functions locally (2026) Firebase.
  // Available at: https://firebase.google.com/docs/functions/local-emulator (Accessed: March 10, 2026).
  final fns = FirebaseFunctions.instanceFor(region: 'us-central1');
  fns.useFunctionsEmulator(host, 5001);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
}

Future<void> main() async {

  // (2026) Stackoverflow.com.
  // Available at: https://stackoverflow.com/questions/63873338/what-does-widgetsflutterbinding-ensureinitialized-do (Accessed: March 10, 2026).
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await _configureBackends();
  // Flutter package (2026) Dart packages.
  // Available at: https://pub.dev/packages/easy_localization (Accessed: March 10, 2026).
  await EasyLocalization.ensureInitialized();

  // Get a new user with each application run
  // Using firebase authentication (2026) Flutter.dev.
  // Available at: https://firebase.flutter.dev/docs/auth/usage/ (Accessed: March 10, 2026).
  await FirebaseAuth.instance.signOut();
  final user = (await FirebaseAuth.instance.signInAnonymously()).user;

  // Get ID token for authentication
  if (user != null && kDebugMode) {

    // Firebase SDK (2026) Firebase.
    // Available at: https://firebase.google.com/docs/reference/js/v8/firebase.User (Accessed: March 10, 2026).
    final idToken = await user.getIdToken(true);
    debugPrint("Firebase ID Token: $idToken");
  } else if (user == null && kDebugMode) {
    debugPrint("FirebaseAuth signInAnonymously failed");
  }

  runApp(
    EasyLocalization(
      // languages
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('el'),
      ],
      // Choudhary, S. (2024) Simplify Flutter Localization with EasyLocalization ✨, Medium.
      // Available at: https://medium.com/@sachin.dev2910/simplify-flutter-localization-with-easylocalization-261db4e41cbb (Accessed: March 10, 2026).
      path: 'assets/translations',
      useOnlyLangCode: true,
      fallbackLocale: const Locale('en'),
      saveLocale: true,
      child: const HealthAssistantApp(),
    ),
  );
}

class HealthAssistantApp extends StatefulWidget {
  const HealthAssistantApp({Key? key}) : super(key: key);

  @override
  State<HealthAssistantApp> createState() => _HealthAssistantAppState();
}

class _HealthAssistantAppState extends State<HealthAssistantApp> {
  // themeMode: ThemeMode.system tells Flutter to use the device/platform theme setting
  // (2026) Stackoverflow.com.
  // Available at: https://stackoverflow.com/questions/60232070/how-to-implement-dark-mode-and-light-mode-in-flutter (Accessed: March 10, 2026).
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(bool isDark) {

    // (2026) Stackoverflow.com.
    // Available at: https://stackoverflow.com/questions/72649789/how-to-use-a-switch-to-change-between-light-and-dark-theme-with-provider-in-flut (Accessed: March 10, 2026).
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Flutter - remove the debug banner (2022) GeeksforGeeks.
      // Available at: https://www.geeksforgeeks.org/flutter/flutter-remove-the-debug-banner/ (Accessed: March 10, 2026).
      debugShowCheckedModeBanner: false,
      title: 'Health Assistant',
      themeMode: _themeMode,
      theme: ThemeData(
        // What is usematerial3 in flutter? (2023) GeeksforGeeks.
        // Available at: https://www.geeksforgeeks.org/flutter/what-is-usematerial3-in-flutter/ (Accessed: March 10, 2026).
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFD2F4FF),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // routes of my app
      initialRoute: '/',
      routes: {
        '/': (context) => AuthScreen(
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _toggleTheme,
          onSkip: () => Navigator.pushReplacementNamed(context, '/body_selection'),
        ),
        '/body_selection': (context) => BodyPartSelectionScreen(onThemeChanged: _toggleTheme),
        '/email-register': (context) =>
            EmailRegisterScreen(isDarkMode: _themeMode == ThemeMode.dark, onThemeChanged: _toggleTheme),
        '/email-sign-in': (context) =>
            EmailSignInScreen(isDarkMode: _themeMode == ThemeMode.dark, onThemeChanged: _toggleTheme),
        '/phone-sign_in': (context) =>
            PhoneSignInScreen(isDarkMode: _themeMode == ThemeMode.dark, onThemeChanged: _toggleTheme),
        '/privacy': (context) => const WebViewScreen(title: 'Privacy Policy', assetPath: 'assets/privacy.html',),
        '/terms': (context) => const WebViewScreen(title: 'Terms of Use', assetPath: 'assets/terms.html',),
        '/disclaimer': (context) => const WebViewScreen(title: 'Medical Disclaimer', assetPath: 'assets/disclaimer.html',),
      },

      // Pass arguments to a named route (2026) Flutter.dev.
      // Available at: https://docs.flutter.dev/cookbook/navigation/navigate-with-arguments (Accessed: March 10, 2026).
      onGenerateRoute: (settings) {
        if (settings.name == TriageChatScreen.routeName) {
          final args = settings.arguments as TriageChatArgs;
          return MaterialPageRoute(
            builder: (_) => TriageChatScreen(selectedAreas: args.selectedAreas),
          );
        }
        return null;
      },

      // Navigation and routing (2026) Flutter.dev.
      // Available at: https://docs.flutter.dev/ui/navigation (Accessed: March 10, 2026).
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => AuthScreen(
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _toggleTheme,

          // NamedRoutes
          // Yasser, A. (2025) Mastering Navigation and routing in Flutter: A complete guide, Medium.
          // Available at: https://medium.com/@ImAmmarYasser/navigation-and-routing-in-flutter-a-comprehensive-guide-2575042ebe88 (Accessed: March 10, 2026).
          onSkip: () => Navigator.pushReplacementNamed(_, '/body_selection'),
        ),
      ),
    );
  }
}
