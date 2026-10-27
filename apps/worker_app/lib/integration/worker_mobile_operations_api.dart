import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'worker_api.dart';
import 'worker_environment.dart';
import 'worker_mobile_auth_api.dart';
import '../features/home/worker_booking_data.dart';

class WorkerMobileOperationsApi implements WorkerOperationsApi {
  WorkerMobileOperationsApi({
    http.Client? client,
    WorkerTokenStorage? tokenStorage,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _storage = tokenStorage ?? SecureWorkerTokenStorage(),
       _apiBaseUrl = apiBaseUrl ?? WorkerEnvironment.apiBaseUrl;

  final http.Client _client;
  final WorkerTokenStorage _storage;
  final String _apiBaseUrl;

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
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$path',
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
        'PUT' =>
          _client
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 12)),
        'PATCH' =>
          _client
              .patch(uri, headers: headers, body: jsonEncode(body))
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
        return const <String, dynamic>{};
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
  Future<bool> updateAvailability(bool online) async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final data = await _request(
      'PUT',
      '/mobile/worker/availability',
      token: token,
      body: {'isOnline': online},
    );
    return data['isOnline'] == true;
  }

  @override
  Future<bool> availability() async {
    final token = await _storage.read();
    if (token == null) return false;
    try {
      final data = await _request(
        'GET',
        '/mobile/worker/profile',
        token: token,
      );
      final profile = data['profile'];
      if (profile is Map) {
        return profile['isOnline'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<List<WorkerDashboardOrder>> fetchWorkerOrders() async {
    final token = await _storage.read();
    if (token == null) return const [];
    try {
      final data = await _request(
        'GET',
        '/mobile/worker/bookings',
        token: token,
      );
      final items = data['items'] as List?;
      if (items == null) return const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(_mapOrder)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchOffers() async {
    final token = await _storage.read();
    if (token == null) return const [];
    try {
      final data = await _request(
        'GET',
        '/mobile/worker/offers',
        token: token,
      );
      final items = data['items'] as List?;
      if (items == null) return const [];
      return items.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> respondToOffer({
    required String assignmentId,
    required String decision,
    String? reason,
  }) async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final data = await _request(
      'POST',
      '/mobile/worker/assignments/$assignmentId/respond',
      token: token,
      body: {
        'decision': decision,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return data['status'] == 'accepted';
  }

  Future<Map<String, dynamic>> updateBookingProgress({
    required String bookingId,
    required String action,
    String? otp,
  }) async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final body = <String, dynamic>{
      'action': action,
      if (otp != null && otp.trim().isNotEmpty) 'otp': otp.trim(),
    };
    final data = await _request(
      'POST',
      '/mobile/worker/bookings/$bookingId/progress',
      token: token,
      body: body,
    );
    return data;
  }

  WorkerDashboardOrder _mapOrder(Map<String, dynamic> doc) {
    final id = '${doc['_id'] ?? ''}';
    final items = doc['items'] as List?;
    final serviceName = items != null && items.isNotEmpty
        ? items.map((i) => i['name'] ?? 'Beauty Service').join(', ')
        : 'Beauty Service';
    final customerSnapshot = doc['customerSnapshot'] as Map?;
    final customerName = customerSnapshot?['fullName'] ?? 'Customer';
    final addressSnapshot = doc['addressSnapshot'] as Map?;
    final line1 = addressSnapshot?['line1'] ?? '';
    final city = addressSnapshot?['city'] ?? 'Latur';
    final location = line1.isNotEmpty ? '$line1, $city' : city;
    final totalPaise = doc['totalPaise'] is num
        ? (doc['totalPaise'] as num).toInt()
        : 0;
    final customerPayable = totalPaise ~/ 100;

    DateTime? startsAt;
    if (doc['startsAt'] != null) {
      startsAt = DateTime.tryParse('${doc['startsAt']}');
    }

    DateTime? completedAt;
    if (doc['completedAt'] != null) {
      completedAt = DateTime.tryParse('${doc['completedAt']}');
    }

    String timeStr = '10:00 AM';
    if (startsAt != null) {
      final local = startsAt.toLocal();
      final hour = local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      timeStr = '$displayHour:$minute $period';
    }

    final rawStatus = '${doc['status'] ?? 'scheduled'}';
    final status = switch (rawStatus.toLowerCase()) {
      'assigned' => 'Assigned',
      'confirmed' => 'Confirmed',
      'travelling' => 'Travelling',
      'arrived' => 'Arrived',
      'in_progress' => 'In Progress',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => rawStatus,
    };
    final durationMinutes = doc['durationMinutes'] ?? 60;

    return WorkerDashboardOrder(
      id: id,
      customer: customerName,
      service: serviceName,
      time: timeStr,
      location: location,
      customerPayable: customerPayable,
      status: status,
      duration: '$durationMinutes min',
      appointmentDate: startsAt,
      completedAt: completedAt,
    );
  }

  @override
  Future<WorkerPage<WorkerAssignmentRecord>> assignments({int page = 1}) async {
    return WorkerPage(items: const [], page: page, hasMore: false);
  }

  @override
  Future<WorkerAssignmentRecord> transition({
    required String assignmentId,
    required WorkerJobAction action,
    required String idempotencyKey,
    String? rejectionReason,
    String? arrivalOtp,
  }) async {
    throw const WorkerIntegrationPending('transition');
  }

  @override
  Future<WorkerCollectionRecord> collection(String bookingId) async {
    throw const WorkerIntegrationPending('collection');
  }

  @override
  Future<WorkerCollectionRecord> recordCash({
    required String bookingId,
    required String idempotencyKey,
  }) async {
    throw const WorkerIntegrationPending('recordCash');
  }

  @override
  Future<WorkerPage<WorkerSettlementRecord>> settlements({int page = 1}) async {
    return WorkerPage(items: const [], page: page, hasMore: false);
  }

  void close() => _client.close();
}

