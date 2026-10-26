import 'package:flutter/foundation.dart';
import 'environment.dart';

class AppConfig {
  const AppConfig(this.environment);
  final Environment environment;

  String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return kIsWeb ? 'http://localhost:5001' : 'http://10.0.2.2:5001';
  }

  bool get mockAuthEnabled => environment == Environment.development && kDebugMode;
}
