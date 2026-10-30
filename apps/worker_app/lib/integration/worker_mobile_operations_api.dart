import 'dart:async';
import 'cancellable_http.dart';
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
  late final _transport = CancellableHttp(_client);
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
    String? idempotencyKey,
  }) async {
    final uri = _uri(path);
    final headers = {
      'Accept': 'application/json',
      ...?body == null ? null : {'Content-Type': 'application/json'},
      if (token != null) 'Authorization': 'Bearer $token',
      ...?idempotencyKey == null ? null : {'x-idempotency-key': idempotencyKey},
    };
    try {
      if (!const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method))
        throw ArgumentError.value(method, 'method');
      final response = await _transport.request(
        method,
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
        timeout: Duration(seconds: path.endsWith('/payment-qr') ? 30 : 12),
      );
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
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final data = await _request('GET', '/mobile/worker/profile', token: token);
    final profile = data['profile'];
    if (profile is! Map) {
      throw const WorkerAuthException(
        'WORKER_PROFILE_NOT_FOUND',
        'The worker profile for this login was not found.',
      );
    }
    return profile['isOnline'] == true;
  }

  Future<List<WorkerDashboardOrder>> fetchWorkerOrders() async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final orders = <WorkerDashboardOrder>[];
    for (var page = 1; ; page++) {
      final data = await _request(
        'GET',
        '/mobile/worker/bookings?page=$page&limit=100',
        token: token,
      );
      final items = data['items'];
      if (items is! List) {
        throw const WorkerAuthException(
          'INVALID_RESPONSE',
          'The server returned an invalid bookings list.',
        );
      }
      orders.addAll(items.whereType<Map<String, dynamic>>().map(_mapOrder));
      final pagination = data['pagination'];
      if (pagination is! Map || items.isEmpty) return orders;
      final pages = int.tryParse('${pagination['pages']}');
      if (pagination['hasMore'] != true && (pages == null || page >= pages))
        return orders;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCatalogServices() async {
    return fetchCatalogRecords('services');
  }

  Future<List<Map<String, dynamic>>> fetchCatalogRecords(
    String resource,
  ) async {
    if (![
      'services',
      'banners',
      'offers',
      'packages',
      'categories',
    ].contains(resource)) {
      throw ArgumentError.value(resource, 'resource');
    }
    final items = <Map<String, dynamic>>[];
    for (var page = 1; ; page++) {
      final data = await _request(
        'GET',
        '/catalog/$resource?page=$page&limit=100',
      );
      final records = (data['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      items.addAll(records);
      final pagination = data['pagination'];
      if (pagination is! Map || records.isEmpty) return items;
      final pages = int.tryParse('${pagination['pages']}');
      if (pagination['hasMore'] != true && (pages == null || page >= pages))
        return items;
    }
  }

  Future<List<Map<String, dynamic>>> fetchOffers() async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final data = await _request('GET', '/mobile/worker/offers', token: token);
    final items = data['items'];
    if (items is! List) {
      throw const WorkerAuthException(
        'INVALID_RESPONSE',
        'The server returned an invalid booking-offers list.',
      );
    }
    return items.whereType<Map<String, dynamic>>().toList(growable: false);
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
    List<String> evidenceIds = const [],
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
      if (evidenceIds.isNotEmpty) 'evidenceIds': evidenceIds,
    };
    final data = await _request(
      'POST',
      '/mobile/worker/bookings/$bookingId/progress',
      token: token,
      body: body,
    );
    return data;
  }

  Future<Map<String, dynamic>> reportCashCollection({
    required String bookingId,
    required int amountPaise,
    required String reference,
    required String idempotencyKey,
  }) async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    return _request(
      'POST',
      '/mobile/worker/bookings/$bookingId/cash-collection',
      token: token,
      body: {'amountPaise': amountPaise, 'reference': reference},
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Map<String, dynamic>> uploadProductEvidence({
    required String bookingId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const WorkerAuthException(
        'INVALID_FILE',
        'Product photos must be smaller than 5 MB.',
      );
    }
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final uri = _uri('/mobile/worker/bookings/$bookingId/product-evidence');
    final response = await _client
        .post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'Content-Type': 'image/jpeg',
            'x-file-name': Uri.encodeComponent(fileName),
            'x-idempotency-key':
                'evidence_${bookingId}_${DateTime.now().microsecondsSinceEpoch}',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const WorkerAuthException(
        'INVALID_RESPONSE',
        'The server returned an invalid evidence response.',
      );
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true ||
        decoded['data'] is! Map<String, dynamic>) {
      final error = decoded['error'];
      throw WorkerAuthException(
        error is Map ? '${error['code'] ?? 'API_ERROR'}' : 'API_ERROR',
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'Could not upload the product photo.',
      );
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> proposeExtraService({
    required String bookingId,
    required String serviceKey,
    required String name,
    required int amountPaise,
    required int durationMinutes,
  }) async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    return _request(
      'POST',
      '/mobile/worker/bookings/$bookingId/extra-services',
      token: token,
      idempotencyKey: 'extra_${bookingId}_$serviceKey',
      body: {
        'name': name,
        'amountPaise': amountPaise,
        'durationMinutes': durationMinutes,
      },
    );
  }

  Future<Map<String, dynamic>> createBookingPaymentQr(String bookingId) async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    return _request(
      'POST',
      '/mobile/worker/bookings/$bookingId/payment-qr',
      token: token,
      idempotencyKey: 'qr_$bookingId',
      body: const {},
    );
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
    final city = addressSnapshot?['city'] ?? '';
    final location = line1.isNotEmpty ? '$line1, $city' : city;
    final totalPaise = int.tryParse('${doc['totalPaise']}') ?? 0;
    final customerPayable = totalPaise ~/ 100;

    DateTime? startsAt;
    if (doc['startsAt'] != null) {
      startsAt = DateTime.tryParse('${doc['startsAt']}');
    }

    DateTime? completedAt;
    if (doc['completedAt'] != null) {
      completedAt = DateTime.tryParse('${doc['completedAt']}');
    }
    final serviceStartedAt = doc['serviceStartedAt'] == null
        ? null
        : DateTime.tryParse('${doc['serviceStartedAt']}');
    final serviceEndsAt = doc['serviceEndsAt'] == null
        ? null
        : DateTime.tryParse('${doc['serviceEndsAt']}');
    final serviceFinishedAt = doc['serviceFinishedAt'] == null
        ? null
        : DateTime.tryParse('${doc['serviceFinishedAt']}');
    final cashCollectionReportedAt = doc['cashCollectionReportedAt'] == null
        ? null
        : DateTime.tryParse('${doc['cashCollectionReportedAt']}');
    final extension = doc['durationExtension'] is Map
        ? Map<String, dynamic>.from(doc['durationExtension'] as Map)
        : null;

    String timeStr = 'Schedule unavailable';
    if (startsAt != null) {
      final local = startsAt.toLocal();
      final hour = local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      timeStr = '$displayHour:$minute $period';
    }

    final rawStatus =
        doc['serviceFinishedAt'] != null && doc['paymentStatus'] != 'paid'
        ? 'payment pending'
        : '${doc['status'] ?? 'scheduled'}';
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
    final durationMinutes = doc['durationMinutes'];

    final customerPhone = customerSnapshot?['mobileNumber']?.toString();
    final paymentMethod = doc['paymentMethod']?.toString();
    final paymentStatus = doc['paymentStatus']?.toString();
    final compensationPaise = doc['compensationPaise'] is num
        ? (doc['compensationPaise'] as num).toInt()
        : null;
    final compensationRupees = compensationPaise != null
        ? compensationPaise ~/ 100
        : null;

    String? itemsDescription;
    if (items != null && items.isNotEmpty) {
      itemsDescription = items
          .map((i) {
            final name = i['name'] ?? 'Service';
            final qty = i['quantity'] ?? 1;
            final pricePaise = i['pricePaise'] is num
                ? (i['pricePaise'] as num).toInt()
                : 0;
            final priceRupees = pricePaise ~/ 100;
            return '$name (x$qty) - ₹$priceRupees';
          })
          .join('\n');
    }

    return WorkerDashboardOrder(
      id: id,
      customer: customerName,
      service: serviceName,
      time: timeStr,
      location: location,
      customerPayable: customerPayable,
      status: status,
      duration: durationMinutes == null
          ? 'Duration unavailable'
          : '$durationMinutes min',
      appointmentDate: startsAt,
      completedAt: completedAt,
      customerPhone: customerPhone,
      itemsDescription: itemsDescription,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      customerPayablePaise: totalPaise,
      compensationRupees: compensationRupees,
      serviceStartedAt: serviceStartedAt,
      serviceEndsAt: serviceEndsAt,
      serviceFinishedAt: serviceFinishedAt,
      cashCollectionReportedAt: cashCollectionReportedAt,
      durationExtension: extension,
    );
  }

  Future<WorkerDashboardOrder> fetchBookingDetailsOrThrow(
    String bookingId,
  ) async {
    final token = await _storage.read();
    if (token == null)
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    final doc = await _request(
      'GET',
      '/mobile/worker/bookings/$bookingId',
      token: token,
    );
    return _mapOrder(doc);
  }

  Future<WorkerDashboardOrder?> fetchBookingDetails(String bookingId) async {
    try {
      return await fetchBookingDetailsOrThrow(bookingId);
    } catch (_) {
      return null;
    }
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

  Future<List<Map<String, dynamic>>> fetchSettlements() async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final records = <Map<String, dynamic>>[];
    for (var page = 1; ; page++) {
      final data = await _request(
        'GET',
        '/mobile/worker/settlements?page=$page&limit=100',
        token: token,
      );
      final items = data['items'];
      if (items is! List)
        throw const WorkerAuthException(
          'INVALID_RESPONSE',
          'The server returned an invalid settlements list.',
        );
      records.addAll(items.whereType<Map<String, dynamic>>());
      final pagination = data['pagination'];
      if (items.isEmpty || pagination is! Map) return records;
      final pages = int.tryParse(pagination['pages'].toString());
      if (pagination['hasMore'] != true && (pages == null || page >= pages))
        return records;
    }
  }

  @override
  Future<WorkerPage<WorkerSettlementRecord>> settlements({int page = 1}) async {
    return WorkerPage(items: const [], page: page, hasMore: false);
  }

  Future<List<Map<String, dynamic>>> fetchLeaves() async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    final data = await _request('GET', '/mobile/worker/leaves', token: token);
    final items = data['items'];
    if (items is! List) {
      throw const WorkerAuthException(
        'INVALID_RESPONSE',
        'The server returned an invalid leave list.',
      );
    }
    return items.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Map<String, dynamic>> fetchWorkerProfile() async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    return await _request('GET', '/mobile/worker/profile', token: token);
  }

  Future<Map<String, dynamic>> updateWorkerProfile(
    Map<String, dynamic> body,
  ) async {
    final token = await _storage.read();
    if (token == null) {
      throw const WorkerAuthException(
        'UNAUTHENTICATED',
        'Sign in is required.',
      );
    }
    return await _request(
      'PATCH',
      '/mobile/worker/profile',
      token: token,
      body: body,
    );
  }

  Future<Map<String, dynamic>> submitLeaveRequest({
    required DateTime startsAt,
    required DateTime endsAt,
    required String reason,
  }) async {
    final token = await _storage.read();
    if (token == null) {
      throw Exception('Authentication required to submit leave request');
    }
    final key = 'idem-leave-${DateTime.now().microsecondsSinceEpoch}';
    return await _request(
      'POST',
      '/mobile/worker/leaves',
      token: token,
      idempotencyKey: key,
      body: {
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'reason': reason,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final token = await _storage.read();
    if (token == null) return const [];
    final data = await _request(
      'GET',
      '/mobile/worker/notifications',
      token: token,
    );
    final items = data['items'] as List?;
    if (items == null) return const [];
    return items.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<bool> markNotificationAsRead(String notificationId) async {
    final token = await _storage.read();
    if (token == null) return false;
    try {
      await _request(
        'PATCH',
        '/mobile/worker/notifications/$notificationId/read',
        token: token,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllNotificationsAsRead() async {
    final token = await _storage.read();
    if (token == null) return false;
    try {
      await _request(
        'POST',
        '/mobile/worker/notifications/read-all',
        token: token,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void close() => _transport.close();
}
