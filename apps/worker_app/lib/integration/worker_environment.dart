import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Opt in explicitly; profile/release builds can never activate local previews.
abstract final class WorkerEnvironment {
  static const developmentPreview =
      kDebugMode &&
      bool.fromEnvironment('WORKER_DEVELOPMENT_PREVIEW', defaultValue: false);
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return '';
    return kIsWeb ? 'http://localhost:5001' : 'http://10.0.2.2:5001';
  }

  static Uri? get apiOrigin {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (!kDebugMode && uri.scheme != 'https') ||
        !['https', 'http'].contains(uri.scheme)) {
      return null;
    }
    return uri;
  }
}
