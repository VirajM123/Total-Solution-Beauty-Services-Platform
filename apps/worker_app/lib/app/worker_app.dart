import 'package:flutter/foundation.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB20A50)),
        scaffoldBackgroundColor: const Color(0xFFFFF9F5),
      ),

      home: const WorkerSplashScreen(demoEnabled: kDebugMode),
    );
  }
}
