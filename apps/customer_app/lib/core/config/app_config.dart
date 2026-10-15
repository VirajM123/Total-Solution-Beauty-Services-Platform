import 'package:flutter/foundation.dart';
import 'environment.dart';

class AppConfig {
  const AppConfig(this.environment);
  final Environment environment;
  bool get mockAuthEnabled => environment == Environment.development && kDebugMode;
}
