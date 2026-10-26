import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:customer_app/core/api/mobile_api.dart';
import 'package:customer_app/features/catalog/catalog_repository.dart';

void main() {
  test(
    'catalog forwards backend pagination and filters, retains paise precision',
    () async {
      final api = MobileApi(
        baseUrl: 'https://example.com/api',
        client: MockClient((request) async {
          expect(request.url.path, '/api/catalog/services');
          expect(request.url.queryParameters, {
            'page': '3',
            'limit': '20',
            'search': 'facial',
            'categoryId': 'category-id',
          });
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'service-id',
                    'name': 'Facial',
                    'category': {'id': 'category-id', 'name': 'Skin'},
                    'pricePaise': '12345',
                    'durationMinutes': 45,
                    'images': [],
                    'benefits': [],
                    'isHomeServiceAvailable': true,
                  },
                ],
                'pagination': {'page': 3, 'pages': 4, 'total': 70},
              },
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final page = await CatalogRepository(
        api,
      ).services(page: 3, search: 'facial', categoryId: 'category-id');
      expect(page.page, 3);
      expect(page.pages, 4);
      expect(page.items.single.id, 'service-id');
      expect(page.items.single.priceLabel, '₹123.45');
      expect(page.items.single.homeService, isTrue);
    },
  );
  test('catalog failures never become fixture services', () async {
    final api = MobileApi(
      baseUrl: 'https://example.com/api',
      client: MockClient(
        (request) async => http.Response(
          '{"success":false,"error":{"code":"NOT_FOUND","message":"Unavailable"}}',
          404,
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      CatalogRepository(api).service('missing'),
      throwsA(isA<MobileApiException>()),
    );
  });

  test('published packages and offers use the public catalog DTOs', () async {
    final api = MobileApi(
      baseUrl: 'https://example.com/api',
      client: MockClient((request) async {
        expect(request.url.queryParameters, {'page': '2', 'limit': '20'});
        if (request.url.path == '/api/catalog/packages') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    '_id': 'package-id',
                    'name': 'Glow package',
                    'description': 'A published service bundle',
                    'components': [
                      {'serviceId': 'service-id', 'quantity': 1},
                    ],
                    'pricePaise': 249950,
                    'durationMinutes': 90,
                    'thumbnail': 'https://media.example.com/package.jpg',
                  },
                ],
                'pagination': {'page': 2, 'limit': 20, 'hasMore': false},
              },
            }),
            200,
          );
        }
        expect(request.url.path, '/api/catalog/offers');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [
                {
                  '_id': 'offer-id',
                  'name': 'Welcome offer',
                  'description': 'Save on your first service',
                  'code': 'WELCOME20',
                  'discountType': 'percentage',
                  'value': 20,
                  'minimumOrderPaise': 10000,
                  'maximumDiscountPaise': 50000,
                  'startsAt': '2026-10-01T00:00:00.000Z',
                  'endsAt': '2026-11-01T00:00:00.000Z',
                  'thumbnail': 'https://media.example.com/offer.jpg',
                },
              ],
              'pagination': {'page': 2, 'limit': 20, 'hasMore': true},
            },
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final repository = CatalogRepository(api);
    final packages = await repository.packages(page: 2);
    expect(packages.items.single.id, 'package-id');
    expect(packages.items.single.priceLabel, '₹2499.50');
    expect(packages.items.single.durationMinutes, 90);
    expect(packages.items.single.serviceIds, ['service-id']);
    expect(packages.hasMore, isFalse);

    final offers = await repository.offers(page: 2);
    expect(offers.items.single.code, 'WELCOME20');
    expect(offers.items.single.discountLabel, '20% off');
    expect(offers.items.single.endsAt, DateTime.utc(2026, 11));
    expect(offers.items.single.minimumOrderPaise, BigInt.from(10000));
    expect(offers.hasMore, isTrue);
  });
}
