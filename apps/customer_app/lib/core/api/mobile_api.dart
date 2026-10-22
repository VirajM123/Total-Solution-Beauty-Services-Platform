import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MobileApiException implements Exception {
  const MobileApiException(this.code, this.message, {this.status});
  final String code;
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Public catalog transport. Never borrows an Admin cookie or credential.
class MobileApi {
  MobileApi({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _baseUrl = baseUrl,
       _client = client ?? http.Client();
  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;
  bool _closed = false;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    final base = Uri.tryParse(_baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['http', 'https'].contains(base.scheme) ||
        (!kDebugMode && base.scheme != 'https') ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const MobileApiException(
        'CONFIGURATION_REQUIRED',
        'Configure API_BASE_URL for the central Hii Beauty backend.',
      );
    }
    if (!path.startsWith('/') || path.contains('..') || path.contains('://')) {
      throw ArgumentError.value(path, 'path');
    }
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$path',
      queryParameters: query.isEmpty ? null : query,
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      if (_closed) {
        throw const MobileApiException('CANCELLED', 'Request cancelled.');
      }
      try {
        final response = await _client
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(timeout);
        if (_closed) {
          throw const MobileApiException('CANCELLED', 'Request cancelled.');
        }
        // Only safe GET requests are retried, once, on transient failures.
        if ([502, 503, 504].contains(response.statusCode) && attempt == 0) {
          continue;
        }
        final Object? decoded;
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          throw MobileApiException(
            'INVALID_RESPONSE',
            'The server returned an invalid response.',
            status: response.statusCode,
          );
        }
        if (decoded is! Map<String, dynamic>) {
          throw const MobileApiException(
            'INVALID_RESPONSE',
            'Invalid API envelope.',
          );
        }
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            decoded['success'] != true) {
          final error = decoded['error'];
          throw MobileApiException(
            error is Map ? '${error['code'] ?? 'API_ERROR'}' : 'API_ERROR',
            response.statusCode == 401
                ? 'Your session has expired. Please sign in again.'
                : response.statusCode == 403
                ? 'You do not have permission for this action.'
                : 'The service is unavailable. Please try again.',
            status: response.statusCode,
          );
        }
        final data = decoded['data'];
        if (data is! Map<String, dynamic>) {
          throw const MobileApiException(
            'INVALID_RESPONSE',
            'Invalid API data.',
          );
        }
        return data;
      } on TimeoutException {
        if (attempt == 1) {
          throw const MobileApiException(
            'TIMEOUT',
            'The request timed out. Please retry.',
          );
        }
      } on http.ClientException {
        if (attempt == 1 || _closed) {
          throw const MobileApiException(
            'NETWORK_UNAVAILABLE',
            'Unable to connect. Check your connection and retry.',
          );
        }
      }
    }
    throw const MobileApiException('NETWORK_UNAVAILABLE', 'Unable to connect.');
  }

  void close() {
    _closed = true;
    _client.close();
  }
}
