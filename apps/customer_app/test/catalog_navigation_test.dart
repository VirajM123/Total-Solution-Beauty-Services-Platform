import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:customer_app/core/api/mobile_api.dart';
import 'package:customer_app/core/config/app_config.dart';
import 'package:customer_app/core/config/environment.dart';
import 'package:customer_app/features/catalog/catalog_repository.dart';
import 'package:customer_app/features/catalog/catalog_screen.dart';

Map<String, dynamic> service(String id, {String category = 'skin'}) => {
  'id': id,
  'name': 'Service $id',
  'category': {'id': category, 'name': category},
  'pricePaise': '10050',
  'durationMinutes': 30,
};
http.Response response(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
Map<String, dynamic> page(
  List<Object> items, {
  int number = 1,
  int pages = 1,
}) => {
  'items': items,
  'pagination': {'page': number, 'pages': pages, 'total': items.length},
};

void main() {
  test('detail neighbors cross pages and stay within category', () async {
    final api = MobileApi(
      baseUrl: 'https://example.com/api',
      client: MockClient((request) async {
        expect(request.url.queryParameters['categoryId'], 'skin');
        final number = int.parse(request.url.queryParameters['page']!);
        return response(
          page(
            number == 1
                ? [service('a'), service('b')]
                : [service('wrong', category: 'hair'), service('c')],
            number: number,
            pages: 2,
          ),
        );
      }),
    );
    addTearDown(api.close);
    final repository = CatalogRepository(api);
    final middle = await repository.neighbors(
      CatalogService.fromJson(service('b')),
    );
    expect(middle.previous?.id, 'a');
    expect(middle.next?.id, 'c');
    final first = await repository.neighbors(
      CatalogService.fromJson(service('a')),
    );
    expect(first.previous, isNull);
    expect(first.next?.id, 'b');
    final last = await repository.neighbors(
      CatalogService.fromJson(service('c')),
    );
    expect(last.previous?.id, 'b');
    expect(last.next, isNull);
  });

  testWidgets('catalog empty, failure and retry use backend data', (
    tester,
  ) async {
    var fail = true;
    final api = MobileApi(
      baseUrl: 'https://example.com/api',
      client: MockClient((request) async {
        if (fail) {
          return http.Response(
            '{"error":{"code":"FORBIDDEN","message":"Catalog unavailable"}}',
            403,
          );
        }
        return response(page([]));
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogScreen(
          config: const AppConfig(Environment.production),
          repository: CatalogRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('You do not have permission for this action.'),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text('No services found. Try another search or category.'),
      findsOneWidget,
    );
  });

  testWidgets('packages and offers load from API and refresh updated offers', (
    tester,
  ) async {
    var offerName = 'Welcome offer';
    var categoryServiceRequestCount = 0;
    final api = MobileApi(
      baseUrl: 'https://example.com/api',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/categories')) {
          return response(
            page([
              {'id': 'skin', 'name': 'Skin', 'image': null},
            ]),
          );
        }
        if (request.url.path.endsWith('/services')) {
          if (request.url.queryParameters['categoryId'] != null) {
            categoryServiceRequestCount++;
          }
          return response(page([service('service-a')]));
        }
        if (request.url.path.endsWith('/packages')) {
          return response({
            'items': [
              {
                '_id': 'package-id',
                'name': 'Glow package',
                'description': 'Published package',
                'components': [
                  {'serviceId': 'service-a', 'quantity': 1},
                  {'serviceId': 'service-b', 'quantity': 1},
                ],
                'pricePaise': 249950,
                'durationMinutes': 90,
                'thumbnail': null,
              },
            ],
            'pagination': {'page': 1, 'limit': 20, 'hasMore': false},
          });
        }
        expect(request.url.path, '/api/catalog/offers');
        return response({
          'items': [
            {
              '_id': 'offer-id',
              'name': offerName,
              'description': 'Published offer',
              'code': 'WELCOME20',
              'discountType': 'percentage',
              'value': 20,
              'minimumOrderPaise': 10000,
              'maximumDiscountPaise': 50000,
              'startsAt': '2026-10-01T00:00:00.000Z',
              'endsAt': '2026-11-01T00:00:00.000Z',
              'thumbnail': null,
            },
          ],
          'pagination': {'page': 1, 'limit': 20, 'hasMore': false},
        });
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogScreen(
          config: const AppConfig(Environment.production),
          repository: CatalogRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Skin'), findsOneWidget);
    expect(find.text('Service service-a'), findsOneWidget);
    expect(find.text('₹100.50 · 30 min'), findsOneWidget);
    await tester.tap(find.text('Skin'));
    await tester.pumpAndSettle();
    expect(categoryServiceRequestCount, 1);

    await tester.tap(find.byKey(const ValueKey('catalog-packages-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Glow package'), findsOneWidget);
    expect(find.text('₹2499.50 · 90 min'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('catalog-offers-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome offer'), findsOneWidget);
    expect(find.text('20% off'), findsOneWidget);
    expect(find.text('Code: WELCOME20'), findsOneWidget);

    offerName = 'Admin-edited offer';
    await tester.tap(find.byTooltip('Refresh catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Admin-edited offer'), findsOneWidget);
  });

  testWidgets('detail navigates to fresh neighboring detail', (tester) async {
    final details = <String>[];
    final api = MobileApi(
      baseUrl: 'https://example.com/api',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/categories')) return response(page([]));
        if (request.url.path.endsWith('/services')) {
          return response(page([service('a'), service('b')]));
        }
        final id = request.url.pathSegments.last;
        details.add(id);
        return response(service(id));
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogScreen(
          config: const AppConfig(Environment.production),
          repository: CatalogRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Service a'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Next service'), 200);
    final previous = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Previous service'),
    );
    expect(previous.onPressed, isNull);
    await tester.tap(find.text('Next service'));
    await tester.pumpAndSettle();
    expect(details, ['a', 'b']);
    await tester.scrollUntilVisible(find.text('Next service'), 200);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Next service'))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'unsafe image schemes render placeholders without network images',
    (tester) async {
      for (final url in [
        'http://example.com/image.png',
        'data:image/png;base64,abc',
        'file:///secret',
        'blob:example',
        'https://user:password@example.com/image.png',
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: CatalogImage(url: url, height: 100)),
        );
        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
      }
    },
  );
}
