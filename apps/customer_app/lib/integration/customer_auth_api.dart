import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api/mobile_api.dart';
import 'customer_backend.dart';

class CustomerOtpResult {
  const CustomerOtpResult({this.registrationToken, this.identity});
  final String? registrationToken;
  final CustomerIdentity? identity;
  bool get registrationRequired => registrationToken != null;
}

class CustomerOtpRequest {
  const CustomerOtpRequest({
    this.challengeId,
    this.registrationRequired = false,
  });

  final String? challengeId;
  final bool registrationRequired;
}

abstract interface class CustomerTokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureCustomerTokenStorage implements CustomerTokenStorage {
  SecureCustomerTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'hii_beauty.customer.mobile_session';

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class CustomerAuthApi {
  CustomerAuthApi({required this.api, CustomerTokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? SecureCustomerTokenStorage();

  final MobileApi api;
  final CustomerTokenStorage _tokenStorage;

  Future<String> requestOtp(String phone) async {
    final request = await requestLoginOtp(phone);
    if (request.registrationRequired) {
      throw const MobileApiException(
        'REGISTRATION_REQUIRED',
        'No customer account exists for this number. Please register first.',
      );
    }
    final challengeId = request.challengeId;
    if (challengeId == null) {
      throw const MobileApiException(
        'INVALID_RESPONSE',
        'Missing OTP challenge.',
      );
    }
    return challengeId;
  }

  Future<CustomerOtpRequest> requestLoginOtp(String phone) =>
      _requestOtp(phone, flow: 'login');

  Future<String> requestRegistrationOtp(String phone) async {
    final request = await _requestOtp(phone, flow: 'registration');
    final challengeId = request.challengeId;
    if (challengeId == null) {
      throw const MobileApiException(
        'INVALID_RESPONSE',
        'Missing OTP challenge.',
      );
    }
    return challengeId;
  }

  Future<CustomerOtpRequest> _requestOtp(
    String phone, {
    required String flow,
  }) async {
    final data = await api.post(
      '/mobile/auth/otp/request',
      body: {
        'mobileNumber': normalizeIndianMobile(phone),
        'appType': 'customer',
        'flow': flow,
      },
    );
    if (data['registrationRequired'] == true) {
      return const CustomerOtpRequest(registrationRequired: true);
    }
    final challengeId = data['challengeId'];
    if (challengeId is! String) {
      throw const MobileApiException(
        'INVALID_RESPONSE',
        'Missing OTP challenge.',
      );
    }
    return CustomerOtpRequest(challengeId: challengeId);
  }

  Future<void> resendOtp(String challengeId) async {
    await api.post(
      '/mobile/auth/otp/resend',
      body: {'challengeId': challengeId},
    );
  }

  Future<CustomerOtpResult> verifyOtp(
    String challengeId,
    String code, {
    String fullName = 'Customer',
  }) async {
    final data = await api.post(
      '/mobile/auth/otp/verify',
      body: {
        'challengeId': challengeId,
        'code': code,
        'fullName': fullName.trim().isNotEmpty ? fullName.trim() : 'Customer',
      },
    );
    if (data['registrationRequired'] == true) {
      final proof = data['registrationToken'];
      if (proof is! String) {
        throw const MobileApiException(
          'INVALID_RESPONSE',
          'Missing registration proof.',
        );
      }
      return CustomerOtpResult(registrationToken: proof);
    }
    final token = data['accessToken'];
    final user = data['user'];
    if (token is! String || user is! Map) {
      throw const MobileApiException(
        'INVALID_RESPONSE',
        'Missing customer session.',
      );
    }
    await _tokenStorage.write(token);
    return CustomerOtpResult(
      identity: CustomerIdentity(
        id: '${user['id']}',
        phone: '${user['mobileNumber']}',
        name: '${user['fullName']}',
      ),
    );
  }

  Future<CustomerIdentity> register({
    required String registrationToken,
    required String name,
    String? email,
  }) async {
    final data = await api.post(
      '/mobile/auth/register/customer',
      body: {
        'registrationToken': registrationToken,
        'fullName': name,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    final token = data['accessToken'];
    final user = data['user'];
    if (token is! String || user is! Map) {
      throw const MobileApiException(
        'INVALID_RESPONSE',
        'Missing customer session.',
      );
    }
    await _tokenStorage.write(token);
    return CustomerIdentity(
      id: '${user['id']}',
      phone: '${user['mobileNumber']}',
      name: '${user['fullName']}',
    );
  }

  Future<void> logout() async {
    final token = await _tokenStorage.read();
    if (token == null) return;
    try {
      await api.post(
        '/mobile/customer/logout',
        body: const {},
        accessToken: token,
      );
    } finally {
      await _tokenStorage.delete();
    }
  }

  Future<String?> sessionToken() => _tokenStorage.read();
}
