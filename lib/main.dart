import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:diagnosis_ai/screens/auth_screen.dart';
import 'package:diagnosis_ai/screens/email_register.dart';
import 'package:diagnosis_ai/screens/email_sign_in.dart';
import 'package:diagnosis_ai/screens/phone_sign_in.dart';
import 'package:diagnosis_ai/screens/body_selection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('el'),
      ],
      path: 'assets/translations',
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
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
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
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFD2F4FF),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
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
          onSkip: () {
            Navigator.pushReplacementNamed(context, '/body_selection');
          },
        ),
        '/body_selection': (context) => BodyPartSelectionScreen(
          onThemeChanged: _toggleTheme,
        ),
        '/email-register': (context) => EmailRegisterScreen(
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _toggleTheme,
        ),
        '/email-sign-in': (context) => EmailSignInScreen(
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _toggleTheme,
        ),
        '/phone-sign_in': (context) => PhoneSignInScreen(
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: _toggleTheme,
        ),
      },

    );
  }
}
