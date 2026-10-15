import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import 'customer_app.dart';

void bootstrap(AppConfig config) {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = FlutterError.presentError;
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught application error: $error');
    return false;
  };
  runApp(CustomerApp(config: config));
}
