import 'dart:async';
import 'package:customer_app/core/api/mobile_api.dart';
import 'package:customer_app/integration/customer_backend.dart';
import 'package:customer_app/integration/customer_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('unmounted promotions and private content remain pending', () async {
    const content = PendingCustomerContentBackend();
    await expectLater(content.packages(page: 1), throwsA(isA<IntegrationPending>()));
    await expectLater(content.offers(page: 1), throwsA(isA<IntegrationPending>()));
    await expectLater(content.banners(), throwsA(isA<IntegrationPending>()));
    await expectLater(content.notifications(page: 1), throwsA(isA<IntegrationPending>()));
    await expectLater(content.submitReview(BookingReview(bookingId: 'server-booking',
      rating: 5, comment: 'Review')), throwsA(isA<IntegrationPending>()));
  });
  test('GET preserves API prefix and query and unwraps data', () async {
    final api = MobileApi(
      baseUrl: 'https://example.test/api/',
      client: MockClient((request) async {
        expect(request.url.path, '/api/catalog/services');
        expect(request.url.queryParameters['search'], 'facial & spa');
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response('{"success":true,"data":{"items":[]}}', 200);
      }),
    );
    expect(
      await api.get('/catalog/services', query: {'search': 'facial & spa'}),
      {'items': []},
    );
    api.close();
  });
  test('safe transient GET retries once with no fixtures', () async {
    var calls = 0;
    final api = MobileApi(
      baseUrl: 'https://example.test/api',
      client: MockClient((_) async {
        calls++;
        return http.Response(
          '{"success":false,"error":{"code":"API_NOT_CONFIGURED"}}',
          503,
        );
      }),
    );
    await expectLater(
      api.get('/catalog/services'),
      throwsA(
        isA<MobileApiException>().having(
          (e) => e.code,
          'code',
          'API_NOT_CONFIGURED',
        ),
      ),
    );
    expect(calls, 2);
    api.close();
  });
  test('unauthorized is not retried', () async {
    var calls = 0;
    final api = MobileApi(
      baseUrl: 'https://example.test/api',
      client: MockClient((_) async {
        calls++;
        return http.Response(
          '{"success":false,"error":{"code":"UNAUTHORIZED"}}',
          401,
        );
      }),
    );
    await expectLater(
      api.get('/catalog/services'),
      throwsA(isA<MobileApiException>().having((e) => e.status, 'status', 401)),
    );
    expect(calls, 1);
    api.close();
  });
  test('malformed response and missing configuration fail honestly', () async {
    final api = MobileApi(
      baseUrl: 'https://example.test/api',
      client: MockClient((_) async => http.Response('html', 200)),
    );
    await expectLater(
      api.get('/catalog/services'),
      throwsA(isA<MobileApiException>()),
    );
    api.close();
    final missing = MobileApi(baseUrl: '');
    await expectLater(
      missing.get('/catalog/services'),
      throwsA(
        isA<MobileApiException>().having(
          (e) => e.code,
          'code',
          'CONFIGURATION_REQUIRED',
        ),
      ),
    );
    missing.close();
  });
  test('timeout maps to typed error', () async {
    final api = MobileApi(
      baseUrl: 'https://example.test/api',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) async => Completer<http.Response>().future),
    );
    await expectLater(
      api.get('/catalog/services'),
      throwsA(
        isA<MobileApiException>().having((e) => e.code, 'code', 'TIMEOUT'),
      ),
    );
    api.close();
  });
  test(
    'Indian mobile normalization accepts +91 and rejects invalid prefixes',
    () {
      expect(normalizeIndianMobile('+91 98765 43210'), '+919876543210');
      expect(() => normalizeIndianMobile('1234567890'), throwsFormatException);
    },
  );
  test('pending adapters never fabricate bookings or authentication', () async {
    const backend = PendingCustomerBackend();
    await expectLater(
      backend.verifyOtp('challenge', '123456'),
      throwsA(isA<IntegrationPending>()),
    );
    await expectLater(
      backend.createBooking(
        const BookingRequest(
          quoteId: 'q',
          addressId: 'a',
          slotId: 's',
          idempotencyKey: 'retry-key',
          method: CollectionMethod.cash,
        ),
      ),
      throwsA(isA<IntegrationPending>()),
    );
    await expectLater(backend.cart(), throwsA(isA<IntegrationPending>()));
    await expectLater(
      backend.bookings(page: 1),
      throwsA(isA<IntegrationPending>()),
    );
  });
}
