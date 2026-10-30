import 'mobile_push.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'worker_api.dart';
import 'worker_environment.dart';

class WorkerAuthException implements Exception {
  const WorkerAuthException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

abstract interface class WorkerTokenStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureWorkerTokenStorage implements WorkerTokenStorage {
  SecureWorkerTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'hii_beauty.worker.mobile_session';

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class WorkerMobileAuthApi implements WorkerAuthApi {
  WorkerMobileAuthApi({
    http.Client? client,
    WorkerTokenStorage? tokenStorage,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _storage = tokenStorage ?? SecureWorkerTokenStorage(),
       _apiBaseUrl = apiBaseUrl ?? WorkerEnvironment.apiBaseUrl;

  final http.Client _client;
  final WorkerTokenStorage _storage;
  final String _apiBaseUrl;
  String? _challengeId;
  String? _requestedMobile;

  String _normalizeMobile(String input) {
    var value = input.replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('+91')) value = value.substring(3);
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
      throw const WorkerAuthException(
        'INVALID_MOBILE',
        'Enter a valid 10-digit Indian mobile number.',
      );
    }
    return '+91$value';
  }

  Uri _uri(String path) {
    final base = Uri.tryParse(_apiBaseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['https', 'http'].contains(base.scheme) ||
        (!kDebugMode && base.scheme != 'https') ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const WorkerAuthException(
        'CONFIGURATION_REQUIRED',
        'Configure API_BASE_URL for the central Hii Beauty backend.',
      );
    }
    final relative = Uri.parse(path);
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}${relative.path}',
      query: relative.hasQuery ? relative.query : null,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = _uri(path);
    final headers = {
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      final response = await switch (method) {
        'GET' =>
          _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 12)),
        'POST' =>
          _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 12)),
        _ => throw ArgumentError.value(method, 'method'),
      };
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const WorkerAuthException(
          'INVALID_RESPONSE',
          'The server returned an invalid response.',
        );
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        final error = decoded['error'];
        throw WorkerAuthException(
          error is Map ? '${error['code'] ?? 'API_ERROR'}' : 'API_ERROR',
          error is Map && error['message'] is String
              ? error['message'] as String
              : 'The service is unavailable. Please try again.',
        );
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const WorkerAuthException(
          'INVALID_RESPONSE',
          'The server returned invalid data.',
        );
      }
      return data;
    } on TimeoutException {
      throw const WorkerAuthException(
        'TIMEOUT',
        'The request timed out. Retry.',
      );
    } on http.ClientException {
      throw const WorkerAuthException(
        'NETWORK_UNAVAILABLE',
        'Unable to connect. Check your connection and retry.',
      );
    } on FormatException {
      throw const WorkerAuthException(
        'INVALID_RESPONSE',
        'The server returned an invalid response.',
      );
    }
  }

  @override
  Future<void> requestOtp(
    String indianMobile, {
    bool forRegistration = false,
  }) async {
    final mobile = _normalizeMobile(indianMobile);
    final data = await _request(
      'POST',
      '/mobile/auth/otp/request',
      body: {
        'mobileNumber': mobile,
        'appType': 'worker',
        'flow': forRegistration ? 'registration' : 'login',
      },
    );
    if (data['registrationRequired'] == true) {
      throw const WorkerAuthException(
        'REGISTRATION_REQUIRED',
        'No worker account exists for this number. Please register first.',
      );
    }
    final challenge = data['challengeId'];
    if (challenge is! String) {
      throw const WorkerAuthException(
        'INVALID_RESPONSE',
        'Missing OTP challenge.',
      );
    }
    _challengeId = challenge;
    _requestedMobile = mobile;
  }

  @override
  Future<WorkerIdentity> verifyOtp(
    String indianMobile,
    String otp, {
    String fullName = 'Worker',
  }) async {
    final mobile = _normalizeMobile(indianMobile);
    final challenge = _challengeId;
    if (challenge == null || mobile != _requestedMobile) {
      throw const WorkerAuthException(
        'OTP_CHALLENGE_REQUIRED',
        'Request a new verification code before continuing.',
      );
    }
    final data = await _request(
      'POST',
      '/mobile/auth/otp/verify',
      body: {
        'challengeId': challenge,
        'code': otp,
        'fullName': fullName.trim().isNotEmpty ? fullName.trim() : 'Worker',
      },
    );
    if (data['registrationRequired'] == true) {
      final proof = data['registrationToken'];
      if (proof is! String) {
        throw const WorkerAuthException(
          'INVALID_RESPONSE',
          'Missing worker registration proof.',
        );
      }
      return WorkerIdentity(
        workerId: '',
        approval: WorkerApproval.notRegistered,
        registrationToken: proof,
      );
    }
    return _storeSession(data);
  }

  @override
  Future<void> resendOtp() async {
    final challenge = _challengeId;
    if (challenge == null) {
      throw const WorkerAuthException(
        'OTP_CHALLENGE_REQUIRED',
        'Request a new verification code before continuing.',
      );
    }
    await _request(
      'POST',
      '/mobile/auth/otp/resend',
      body: {'challengeId': challenge},
    );
  }

  @override
  Future<WorkerIdentity> completeRegistration({
    required String registrationToken,
    required String fullName,
    String? email,
  }) async {
    final data = await _request(
      'POST',
      '/mobile/auth/register/worker',
      body: {
        'registrationToken': registrationToken,
        'fullName': fullName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );
    return _storeSession(data);
  }

  Future<WorkerIdentity> _storeSession(Map<String, dynamic> data) async {
    final token = data['accessToken'];
    final user = data['user'];
    if (token is! String || user is! Map) {
      throw const WorkerAuthException(
        'INVALID_RESPONSE',
        'The server did not return an authorized worker session.',
      );
    }
    await _storage.write(token);
    unawaited(MobilePush.instance?.sync() ?? Future<void>.value());
    final approval = switch ('${data['workerStatus'] ?? 'not_registered'}') {
      'approved' => WorkerApproval.approved,
      'pending' => WorkerApproval.pending,
      'rejected' => WorkerApproval.rejected,
      'suspended' => WorkerApproval.suspended,
      _ => WorkerApproval.notRegistered,
    };
    return WorkerIdentity(workerId: '${user['id']}', approval: approval);
  }

  @override
  Future<WorkerIdentity> currentIdentity() async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final data = await _request('GET', '/mobile/worker/profile', token: token);
    final profile = data['profile'];
    final approval = profile is Map ? '${profile['status']}' : 'not_registered';
    final state = switch (approval) {
      'approved' => WorkerApproval.approved,
      'pending' => WorkerApproval.pending,
      'rejected' => WorkerApproval.rejected,
      'suspended' => WorkerApproval.suspended,
      _ => WorkerApproval.notRegistered,
    };
    final user = data['user'];
    return WorkerIdentity(
      workerId: profile is Map
          ? '${profile['_id']}'
          : '${user is Map ? user['_id'] : ''}',
      approval: state,
    );
  }

  @override
  Future<String> uploadDocument({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final token = await _storage.read();
    if (token == null)
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    final uri = _uri('/mobile/worker/media');
    final response = await _client
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer ' + token,
            'Content-Type': mimeType,
            'x-file-name': Uri.encodeComponent(fileName),
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      final error = decoded is Map ? decoded['error'] : null;
      throw WorkerAuthException(
        error is Map
            ? '' + (error['code'] ?? 'UPLOAD_FAILED')
            : 'UPLOAD_FAILED',
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'Failed to upload document. Please try again.',
      );
    }
    final data = decoded['data'];
    if (data is Map && data['_id'] != null) {
      return '' + data['_id'];
    }
    throw const WorkerAuthException(
      'INVALID_RESPONSE',
      'Invalid response from media server.',
    );
  }

  @override
  Future<WorkerIdentity> submitRegistration({
    required int experienceYears,
    required List<String> serviceIds,
    required List<String> serviceAreaIds,
    required String identityMediaAssetId,
  }) async {
    final token = await _storage.read();
    if (token == null)
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    final data = await _request(
      'POST',
      '/mobile/worker/registration',
      token: token,
      body: {
        'experienceYears': experienceYears,
        'serviceIds': serviceIds,
        'serviceAreaIds': serviceAreaIds,
        'documents': [
          {'mediaAssetId': identityMediaAssetId, 'kind': 'identity'},
        ],
      },
    );
    return WorkerIdentity(
      workerId: '' + (data['_id'] ?? ''),
      approval: WorkerApproval.pending,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchServiceAreas() async {
    return _fetchCatalogRecords('/catalog/service-areas');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchServices() async {
    return _fetchCatalogRecords('/catalog/services');
  }

  Future<List<Map<String, dynamic>>> _fetchCatalogRecords(String path) async {
    final records = <Map<String, dynamic>>[];
    for (var page = 1; ; page++) {
      final data = await _request('GET', '$path?page=$page&limit=100');
      final items = data['items'];
      if (items is! List) {
        throw const WorkerAuthException(
          'INVALID_RESPONSE',
          'The server returned an invalid catalog list.',
        );
      }
      records.addAll(items.whereType<Map<String, dynamic>>());
      final pagination = data['pagination'];
      if (pagination is! Map || items.isEmpty) return records;
      final pages = int.tryParse('${pagination['pages']}');
      if (pagination['hasMore'] != true && (pages == null || page >= pages)) {
        return records;
      }
    }
  }

  Future<Map<String, dynamic>> checkWorkerStatus() async {
    final token = await _storage.read();
    if (token == null)
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    return _request('GET', '/mobile/worker/status', token: token);
  }

  static const devBypassToken = 'HiiBeautyWorkerDevBypassTokenForTesting9999';

  Future<WorkerIdentity> devBypassLogin() async {
    if (!kDebugMode) {
      throw const WorkerAuthException(
        'FORBIDDEN',
        'Dev bypass is only available in debug mode.',
      );
    }
    await _storage.write(devBypassToken);
    return currentIdentity();
  }

  @override
  Future<void> logout() async {
    final token = await _storage.read();
    if (token == null) return;
    try {
      await _request(
        'POST',
        '/mobile/worker/logout',
        body: const {},
        token: token,
      );
    } finally {
      await _storage.delete();
      await MobilePush.instance?.signedOut();
      _challengeId = null;
      _requestedMobile = null;
    }
  }

  void close() => _client.close();
}
