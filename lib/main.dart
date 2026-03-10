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

  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final host = isAndroid ? '10.0.2.2' : 'localhost';

  final fns = FirebaseFunctions.instanceFor(region: 'us-central1');
  fns.useFunctionsEmulator(host, 5001);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _configureBackends();
  await EasyLocalization.ensureInitialized();

  // Get a new user with each application run
  await FirebaseAuth.instance.signOut();
  final user = (await FirebaseAuth.instance.signInAnonymously()).user;

  // Get ID token for authentication (debug mode only)
  if (user != null && kDebugMode) {
    final idToken = await user.getIdToken(true);
    debugPrint("Firebase ID Token: $idToken");
  } else if (user == null && kDebugMode) {
    debugPrint("FirebaseAuth signInAnonymously failed");
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('el'),
      ],
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
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Health Assistant',
      themeMode: _themeMode,
      theme: ThemeData(
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

      onGenerateRoute: (settings) {
        if (settings.name == TriageChatScreen.routeName) {
          final args = settings.arguments as TriageChatArgs;
          return MaterialPageRoute(
            builder: (_) => TriageChatScreen(selectedAreas: args.selectedAreas),
          );
        }
        return null;
      },

      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => AuthScreen(
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _toggleTheme,
          onSkip: () => Navigator.pushReplacementNamed(_, '/body_selection'),
        ),
      ),
    );
  }
}
