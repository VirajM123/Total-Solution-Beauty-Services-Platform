import 'dart:async';
import '../integration/mobile_push.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import 'customer_app.dart';

Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = FlutterError.presentError;
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught application error: $error');
    return false;
  };
  runApp(CustomerApp(config: config));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      MobilePush.initialize(appType: 'customer', apiBaseUrl: config.apiBaseUrl),
    );
  });
}
