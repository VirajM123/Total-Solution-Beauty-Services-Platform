import 'dart:math' as math;
import 'dart:async';
import 'cancellable_http.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'customer_auth_api.dart';

class CustomerMobileApiException implements Exception {
  const CustomerMobileApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String? code;
  final String message;

  @override
  String toString() => message;
}

class CustomerMobileOperationsApi {
  CustomerMobileOperationsApi({
    http.Client? client,
    CustomerTokenStorage? tokenStorage,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _storage = tokenStorage ?? SecureCustomerTokenStorage(),
       _apiBaseUrl =
           apiBaseUrl ??
           (const String.fromEnvironment('API_BASE_URL').isNotEmpty
               ? const String.fromEnvironment('API_BASE_URL')
               : (kIsWeb
                     ? 'http://localhost:5001/api'
                     : 'http://10.0.2.2:5001/api'));

  final http.Client _client;
  late final _transport = CancellableHttp(_client);
  final CustomerTokenStorage _storage;
  final String _apiBaseUrl;

  Uri _uri(String path) {
    final base = Uri.tryParse(_apiBaseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['http', 'https'].contains(base.scheme) ||
        (!kDebugMode && base.scheme != 'https') ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw Exception('Invalid API Base URL: $_apiBaseUrl');
    }
    final relative = Uri.parse(path);
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    final relativePath = RegExp(r'/api(?:/v1)?$').hasMatch(basePath)
        ? relative.path.replaceFirst(RegExp(r'^/api'), '')
        : relative.path;
    return base.replace(
      path: '$basePath$relativePath',
      query: relative.hasQuery ? relative.query : null,
    );
  }

  Future<String?> _token() async {
    final stored = await _storage.read();
    if (stored != null && stored.isNotEmpty) return stored;
    return CustomerAuthApi.devBypassToken;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final token = await _token();
    final uri = _uri(path);
    final ik =
        idempotencyKey ??
        'ik_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999).toString().padLeft(6, '0')}';
    final headers = {
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      'x-idempotency-key': ik,
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
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map<String, dynamic>) {
            return decoded['data'] as Map<String, dynamic>;
          }
          return decoded;
        }
        return {'data': decoded};
      }
      final msg =
          (decoded is Map &&
              decoded['error'] is Map &&
              decoded['error']['message'] != null)
          ? decoded['error']['message']
          : 'Request to $path failed with status ${response.statusCode}';
      final errorCode = decoded is Map && decoded['error'] is Map
          ? decoded['error']['code']
          : null;
      throw CustomerMobileApiException(
        statusCode: response.statusCode,
        code: errorCode is String ? errorCode : null,
        message: '$msg',
      );
    } catch (e) {
      debugPrint('[CustomerMobileOperationsApi] $method $path error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAddresses() async {
    return getRecords('/api/mobile/customer/addresses');
  }

  Future<Map<String, dynamic>> saveAddress({
    required String label,
    required String line1,
    String? line2,
    required String city,
    required String postalCode,
    required String serviceAreaId,
  }) async {
    return _request(
      'POST',
      '/api/mobile/customer/addresses',
      body: {
        'label': label,
        'line1': line1,
        if (line2 != null && line2.isNotEmpty) 'line2': line2,
        'city': city,
        'postalCode': postalCode,
        'serviceAreaId': serviceAreaId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getCatalogServices() =>
      getRecords('/api/catalog/services');

  Future<List<Map<String, dynamic>>> getCatalogCategories() =>
      getRecords('/api/catalog/categories');

  Future<List<Map<String, dynamic>>> getRecords(String path) async {
    final items = <Map<String, dynamic>>[];
    for (var page = 1; ; page++) {
      final res = await _request('GET', '$path?page=$page&limit=100');
      final records = (res['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      items.addAll(records);
      final pagination = res['pagination'];
      if (pagination is! Map || records.isEmpty) return items;
      final pages = int.tryParse('${pagination['pages']}');
      if (pagination['hasMore'] != true && (pages == null || page >= pages))
        return items;
    }
  }

  Future<Map<String, dynamic>> getProfile() =>
      _request('GET', '/api/mobile/customer/profile');

  Future<Map<String, dynamic>> updateProfile(String fullName) => _request(
    'PATCH',
    '/api/mobile/customer/profile',
    body: {'fullName': fullName},
  );

  Future<void> submitReview(
    String bookingId,
    int rating,
    String comment,
  ) async {
    await _request(
      'POST',
      '/api/mobile/customer/reviews',
      body: {'bookingId': bookingId, 'rating': rating, 'comment': comment},
    );
  }

  Future<List<Map<String, dynamic>>> getServiceAreas(String postalCode) async {
    final areas = await getRecords('/api/catalog/service-areas');
    return areas
        .where(
          (area) =>
              (area['postalCodes'] as List? ?? const []).contains(postalCode),
        )
        .toList();
  }

  Future<Map<String, dynamic>> updateCart({
    required String serviceAreaId,
    required List<Map<String, dynamic>> items,
  }) async {
    return _request(
      'PUT',
      '/api/mobile/customer/cart',
      body: {'serviceAreaId': serviceAreaId, 'items': items},
    );
  }

  Future<Map<String, dynamic>> quoteCart({
    required String serviceAreaId,
    required List<Map<String, dynamic>> items,
    required String couponCode,
  }) => _request(
    'POST',
    '/api/mobile/customer/quote',
    body: {
      'serviceAreaId': serviceAreaId,
      'items': items,
      'couponCode': couponCode,
    },
  );

  Future<Map<String, dynamic>> createBooking({
    required String serviceAreaId,
    required List<Map<String, dynamic>> items,
    required String addressId,
    DateTime? startsAt,
    String method = 'cash',
    String? idempotencyKey,
    String? couponCode,
  }) async {
    // Lead time must be in future (minimum 30-60 minutes ahead)
    final slot =
        startsAt ?? DateTime.now().toUtc().add(const Duration(minutes: 60));
    return _request(
      'POST',
      '/api/mobile/customer/bookings',
      body: {
        'cart': {
          'serviceAreaId': serviceAreaId,
          'items': items,
          if (couponCode != null) 'couponCode': couponCode,
        },
        'addressId': addressId,
        'startsAt': slot.toIso8601String(),
        'method': method,
      },
      idempotencyKey: idempotencyKey,
    );
  }

  Future<List<Map<String, dynamic>>> getBookings() async {
    return getRecords('/api/mobile/customer/bookings');
  }

  Future<Map<String, dynamic>> getBooking(String id) async {
    return _request('GET', '/api/mobile/customer/bookings/$id');
  }

  Future<Map<String, dynamic>> respondToExtraService({
    required String bookingId,
    required String extraServiceId,
    required bool approve,
  }) async {
    return _request(
      'POST',
      '/api/mobile/customer/bookings/$bookingId/extra-services/$extraServiceId/respond',
      body: {'decision': approve ? 'approve' : 'reject'},
    );
  }

  Future<Map<String, dynamic>> respondToDurationExtension({
    required String bookingId,
    required String extensionId,
    required bool approve,
  }) {
    final decision = approve ? 'approve' : 'decline';
    return _request(
      'POST',
      '/api/mobile/customer/bookings/$bookingId/duration-extensions/$extensionId/respond',
      body: {'decision': decision},
      idempotencyKey: 'duration_extension_${extensionId}_$decision',
    );
  }

  Future<String> revealServiceOtp(String bookingId) async {
    final res = await _request(
      'POST',
      '/api/mobile/customer/bookings/$bookingId/service-otp/reveal',
    );
    return '${res['otp'] ?? ''}';
  }

  Future<Map<String, dynamic>> getNotificationPreferences() =>
      _request('GET', '/api/mobile/customer/notification-preferences');

  Future<void> updateNotificationPreferences({
    required bool notificationsEnabled,
    required bool marketingNotificationsEnabled,
  }) async {
    await _request(
      'PATCH',
      '/api/mobile/customer/notification-preferences',
      body: {
        'notificationsEnabled': notificationsEnabled,
        'marketingNotificationsEnabled': marketingNotificationsEnabled,
      },
    );
  }

  void close() => _transport.close();
}
