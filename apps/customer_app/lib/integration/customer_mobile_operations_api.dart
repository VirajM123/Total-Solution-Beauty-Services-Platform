import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'customer_auth_api.dart';

class CustomerMobileOperationsApi {
  CustomerMobileOperationsApi({
    http.Client? client,
    CustomerTokenStorage? tokenStorage,
    String? apiBaseUrl,
  })  : _client = client ?? http.Client(),
        _storage = tokenStorage ?? SecureCustomerTokenStorage(),
        _apiBaseUrl = apiBaseUrl ??
            (kIsWeb ? 'http://localhost:5001' : 'http://10.0.2.2:5001');

  final http.Client _client;
  final CustomerTokenStorage _storage;
  final String _apiBaseUrl;

  Uri _uri(String path) {
    final base = Uri.tryParse(_apiBaseUrl);
    if (base == null || !base.hasAuthority) {
      throw Exception('Invalid API Base URL: $_apiBaseUrl');
    }
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$path',
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
  }) async {
    final token = await _token();
    final uri = _uri(path);
    final ik = 'ik_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999).toString().padLeft(6, '0')}';
    final headers = {
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      'x-idempotency-key': ik,
    };
    try {
      final response = await switch (method) {
        'GET' => _client.get(uri, headers: headers).timeout(const Duration(seconds: 12)),
        'POST' => _client
            .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
            .timeout(const Duration(seconds: 12)),
        'PUT' => _client
            .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
            .timeout(const Duration(seconds: 12)),
        'PATCH' => _client
            .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
            .timeout(const Duration(seconds: 12)),
        'DELETE' => _client.delete(uri, headers: headers).timeout(const Duration(seconds: 12)),
        _ => throw UnsupportedError('Method $method not supported'),
      };
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
      final msg = (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null)
          ? decoded['error']['message']
          : 'Request to $path failed with status ${response.statusCode}';
      throw Exception(msg);
    } catch (e) {
      debugPrint('[CustomerMobileOperationsApi] $method $path error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAddresses() async {
    try {
      final res = await _request('GET', '/api/mobile/customer/addresses');
      if (res['items'] is List) {
        return (res['items'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[CustomerMobileOperationsApi] getAddresses error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> saveAddress({
    required String label,
    required String line1,
    String? line2,
    required String city,
    required String postalCode,
    required String serviceAreaId,
  }) async {
    return _request('POST', '/api/mobile/customer/addresses', body: {
      'label': label,
      'line1': line1,
      if (line2 != null && line2.isNotEmpty) 'line2': line2,
      'city': city,
      'postalCode': postalCode,
      'serviceAreaId': serviceAreaId,
    });
  }

  Future<List<Map<String, dynamic>>> getCatalogServices() async {
    try {
      final res = await _request('GET', '/api/catalog/services');
      if (res['items'] is List) {
        return (res['items'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[CustomerMobileOperationsApi] getCatalogServices error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getCatalogCategories() async {
    try {
      final res = await _request('GET', '/api/catalog/categories');
      if (res['items'] is List) {
        return (res['items'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[CustomerMobileOperationsApi] getCatalogCategories error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> updateCart({
    required String serviceAreaId,
    required List<Map<String, dynamic>> items,
  }) async {
    return _request('PUT', '/api/mobile/customer/cart', body: {
      'serviceAreaId': serviceAreaId,
      'items': items,
    });
  }

  Future<Map<String, dynamic>> createBooking({
    required String serviceAreaId,
    required String serviceId,
    required String addressId,
    DateTime? startsAt,
    String method = 'cash',
  }) async {
    // Lead time must be in future (minimum 30-60 minutes ahead)
    final slot = startsAt ?? DateTime.now().toUtc().add(const Duration(minutes: 60));
    return _request('POST', '/api/mobile/customer/bookings', body: {
      'cart': {
        'serviceAreaId': serviceAreaId,
        'items': [
          {'serviceId': serviceId, 'quantity': 1}
        ],
      },
      'addressId': addressId,
      'startsAt': slot.toIso8601String(),
      'method': method,
    });
  }

  Future<List<Map<String, dynamic>>> getBookings() async {
    try {
      final res = await _request('GET', '/api/mobile/customer/bookings');
      if (res['items'] is List) {
        return (res['items'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[CustomerMobileOperationsApi] getBookings error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getBooking(String id) async {
    return _request('GET', '/api/mobile/customer/bookings/$id');
  }

  Future<String> revealServiceOtp(String bookingId) async {
    final res = await _request('POST', '/api/mobile/customer/bookings/$bookingId/service-otp/reveal');
    return '${res['otp'] ?? ''}';
  }
}

