import 'package:flutter/foundation.dart';
import 'environment.dart';

class AppConfig {
  const AppConfig(this.environment);
  final Environment environment;
  String get apiBaseUrl => const String.fromEnvironment('API_BASE_URL');

  bool get mockAuthEnabled => environment == Environment.development && kDebugMode;
}
