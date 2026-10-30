import 'dart:convert';

import 'package:customer_app/integration/customer_auth_api.dart';
import 'package:customer_app/integration/customer_mobile_operations_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStorage implements CustomerTokenStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  test(
    'booking retries can reuse their idempotency key and preserve conflicts',
    () async {
      final keys = <String?>[];
      final api = CustomerMobileOperationsApi(
        apiBaseUrl: 'https://example.test/api',
        tokenStorage: _TokenStorage(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/mobile/customer/bookings');
          keys.add(request.headers['x-idempotency-key']);
          return http.Response(
            '{"success":true,"data":{"_id":"booking-id"}}',
            201,
          );
        }),
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        final result = await api.createBooking(
          serviceAreaId: 'area-id',
          items: const [
            {'serviceId': 'service-id', 'quantity': 1},
          ],
          addressId: 'address-id',
          startsAt: DateTime.utc(2030, 1, 1, 10),
          idempotencyKey: 'booking-attempt-123456',
        );
        expect(result['_id'], 'booking-id');
      }
      expect(keys, ['booking-attempt-123456', 'booking-attempt-123456']);

      final conflictApi = CustomerMobileOperationsApi(
        apiBaseUrl: 'https://example.test/api',
        tokenStorage: _TokenStorage(),
        client: MockClient(
          (_) async => http.Response(
            '{"success":false,"error":{"code":"SLOT_UNAVAILABLE","message":"Appointment slot is unavailable."}}',
            409,
          ),
        ),
      );
      await expectLater(
        conflictApi.createBooking(
          serviceAreaId: 'area-id',
          items: const [
            {'serviceId': 'service-id', 'quantity': 1},
          ],
          addressId: 'address-id',
          startsAt: DateTime.utc(2030, 1, 1, 10),
          idempotencyKey: 'booking-attempt-123456',
        ),
        throwsA(
          isA<CustomerMobileApiException>()
              .having((error) => error.statusCode, 'statusCode', 409)
              .having((error) => error.code, 'code', 'SLOT_UNAVAILABLE')
              .having(
                (error) => error.message,
                'message',
                'Appointment slot is unavailable.',
              ),
        ),
      );
    },
  );

  test(
    'catalog loads services after the first page and sends real query parameters',
    () async {
      for (final usePageCount in [false, true]) {
        for (final basePath in ['', '/api', '/api/v1']) {
          final pages = <int>[];
          final api = CustomerMobileOperationsApi(
            apiBaseUrl: 'https://example.test$basePath',
            tokenStorage: _TokenStorage(),
            client: MockClient((request) async {
              expect(
                request.url.path,
                basePath == '/api/v1'
                    ? '/api/v1/catalog/services'
                    : '/api/catalog/services',
              );
              expect(request.url.queryParameters['limit'], '100');
              final page = int.parse(request.url.queryParameters['page']!);
              pages.add(page);
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'name': page == 1 ? 'Hair Spa' : 'Gold Facial',
                        '_id': '$page',
                      },
                    ],
                    'pagination': {
                      'page': page,
                      if (usePageCount) 'pages': 2 else 'hasMore': page == 1,
                    },
                  },
                }),
                200,
              );
            }),
          );
          final services = await api.getCatalogServices();
          expect(pages, [1, 2]);
          expect(services.map((service) => service['name']), [
            'Hair Spa',
            'Gold Facial',
          ]);
        }
      }
    },
  );
}
