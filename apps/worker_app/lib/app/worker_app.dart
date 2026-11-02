import '../integration/worker_environment.dart';

import 'package:flutter/material.dart';

import '../features/splash/worker_splash_screen.dart';

class WorkerApp extends StatelessWidget {
  const WorkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hi Beauty | Partner',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Montserrat',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF52D7A),
        ).copyWith(primary: const Color(0xFFF52D7A), surface: Colors.white),
        scaffoldBackgroundColor: const Color(0xFFFFF8FB),
        visualDensity: VisualDensity.compact,
        appBarTheme: const AppBarTheme(
          toolbarHeight: 48,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Color(0xFFFFF8FB),
        ),
        iconTheme: const IconThemeData(size: 20),
        listTileTheme: const ListTileThemeData(
          dense: true,
          minVerticalPadding: 6,
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF4DDE6)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF52D7A),
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF52D7A),
            minimumSize: const Size(48, 44),
          ),
        ),
      ),

      home: const WorkerSplashScreen(
        demoEnabled: WorkerEnvironment.developmentPreview,
      ),
    );
  }
}
