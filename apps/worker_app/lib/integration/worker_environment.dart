import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Application entrypoints always use authenticated backend data.
abstract final class WorkerEnvironment {
  static const legacyWorkerOffersEnabled = bool.fromEnvironment(
    'LEGACY_WORKER_OFFERS_ENABLED',
    defaultValue: false,
  );
  static const developmentPreview = false;
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      final trimmed = configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
      return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
    }
    if (!kDebugMode) return 'https://salonadminpanel.onrender.com/api';
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return '';
    return kIsWeb ? 'http://localhost:5001/api' : 'http://10.0.2.2:5001/api';
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
