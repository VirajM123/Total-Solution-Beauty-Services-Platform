import 'package:flutter/foundation.dart';

/// Opt in explicitly; profile/release builds can never activate local previews.
abstract final class WorkerEnvironment {
  static const developmentPreview =
      kDebugMode &&
      bool.fromEnvironment('WORKER_DEVELOPMENT_PREVIEW', defaultValue: false);
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

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
