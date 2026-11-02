import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:customer_app/integration/customer_auth_api.dart';
import 'package:customer_app/integration/customer_mobile_operations_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage implements CustomerTokenStorage {
  @override
  Future<String?> read() async => 'test';
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Montserrat': 'assets/fonts/Montserrat-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final font = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
      await font.load();
    }
  });
  for (final size in [
    const Size(320, 686),
    const Size(393, 852),
    const Size(412, 915),
  ]) {
    testWidgets(
      'compact checkout persists correct backend payloads ${size.width}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const areaId = 'cccccccccccccccccccccccc';
        const addressId = 'dddddddddddddddddddddddd';
        final addresses = <Map<String, dynamic>>[
          {
            '_id': addressId,
            'label': 'Home',
            'line1': 'Flat No. 101, Sai Residency',
            'line2': 'Near Bus Stand',
            'city': 'Latur',
            'postalCode': '413512',
            'serviceAreaId': areaId,
          },
        ];
        final catalog = [
          {
            '_id': 'aaaaaaaaaaaaaaaaaaaaaaaa',
            'name': 'Gold Facial',
            'pricePaise': 120000,
            'durationMinutes': 60,
            'thumbnail': 'assets/images/home/gold_facial.png',
            'category': {'name': 'Beauty'},
            'description':
                'Face cleansing, exfoliation, gold mask application and face massage.',
            'benefits': [
              'Brightens and rejuvenates skin',
              'Deep cleansing and detoxification',
              'Reduces tan and pigmentation',
              'Gives an instant healthy glow',
            ],
          },
          {
            '_id': 'bbbbbbbbbbbbbbbbbbbbbbbb',
            'name': 'Manicure',
            'pricePaise': 50000,
            'durationMinutes': 45,
            'category': {'name': 'Beauty'},
            'thumbnail': 'assets/images/home/manicure.png',
          },
        ];
        final requests = <http.Request>[];
        Map<String, dynamic>? created;
        final operations = CustomerMobileOperationsApi(
          apiBaseUrl: 'https://example.test/api',
          tokenStorage: _Storage(),
          client: MockClient((request) async {
            requests.add(request);
            final path = request.url.path;
            dynamic data = {
              'items': [],
              'user': {'fullName': 'Customer'},
            };
            if (path.endsWith('/services')) data = {'items': catalog};
            if (path.endsWith('/categories'))
              data = {
                'items': [
                  {'name': 'Beauty'},
                ],
              };
            if (path.endsWith('/offers'))
              data = {
                'items': [
                  {
                    'name': 'Beauty Offer',
                    'code': 'HI20',
                    'discountType': 'percentage',
                    'value': 20,
                    'description': 'Save 20%',
                    'minimumOrderPaise': 0,
                  },
                ],
              };
            if (path.endsWith('/service-areas'))
              data = {
                'items': [
                  {
                    '_id': areaId,
                    'city': 'Latur',
                    'postalCodes': ['413512'],
                  },
                ],
              };
            if (path.endsWith('/addresses') && request.method == 'GET')
              data = {'items': addresses};
            if (path.endsWith('/addresses') && request.method == 'POST') {
              final address = {
                '_id': 'eeeeeeeeeeeeeeeeeeeeeeee',
                ...jsonDecode(request.body) as Map<String, dynamic>,
              };
              addresses.add(address);
              data = address;
            }
            if (path.endsWith('/addresses/$addressId') &&
                request.method == 'PATCH') {
              addresses[0] = {
                '_id': addressId,
                ...jsonDecode(request.body) as Map<String, dynamic>,
              };
              data = addresses[0];
            }
            if (path.endsWith('/quote')) data = {'discountPaise': 34000};
            if (path.endsWith('/bookings') && request.method == 'GET')
              data = {
                'items': created == null ? [] : [created],
              };
            if (path.endsWith('/bookings') && request.method == 'POST') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              created = {
                '_id': 'ffffffffffffffffffffffff',
                'status': 'confirmed',
                'assignmentStatus': 'searching',
                'startsAt': body['startsAt'],
                'subtotalPaise': 170000,
                'discountPaise': 34000,
                'totalPaise': 136000,
                'addressSnapshot': addresses.last,
                'items': [
                  {'name': 'Gold Facial', 'quantity': 1, 'pricePaise': 120000},
                  {'name': 'Manicure', 'quantity': 1, 'pricePaise': 50000},
                ],
              };
              data = created;
            }
            if (path.endsWith('/bookings/ffffffffffffffffffffffff'))
              data = created;
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
            );
          }),
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('checkout-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Montserrat'),
              home: DevelopmentHomeScreen(operationsApi: operations),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gold Facial').first);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('service-details-title')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Save service'));
        await tester.pumpAndSettle();
        expect(
          requests.any(
            (r) =>
                r.method == 'PUT' &&
                r.url.path.endsWith('/favorites/aaaaaaaaaaaaaaaaaaaaaaaa'),
          ),
          isTrue,
        );
        await _capture(tester, '${size.width}-service-details');
        await tester.tap(find.byKey(const ValueKey('add-to-cart')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cart-back')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Manicure').first);
        await tester.tap(find.text('Manicure').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('add-to-cart')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Increase Gold Facial quantity'));
        await tester.pumpAndSettle();
        expect(find.text('₹2,900'), findsWidgets);
        await tester.tap(find.byTooltip('Decrease Gold Facial quantity'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cart-offer')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('offer-promotion-details-HI20')),
        );
        await tester.tap(
          find.byKey(const ValueKey('offer-promotion-details-HI20')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply Offer'));
        await tester.pumpAndSettle();
        expect(find.text('₹1,360'), findsWidgets);
        await _capture(tester, '${size.width}-cart');
        await tester.tap(find.byKey(const ValueKey('proceed-to-booking')));
        await tester.pumpAndSettle();
        final date = DateTime.now().add(const Duration(days: 2));
        await tester.tap(
          find.byKey(
            ValueKey('booking-date-${date.year}-${date.month}-${date.day}'),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('booking-time-10:30 AM')));
        await tester.pumpAndSettle();
        await _capture(tester, '${size.width}-date-time');
        await tester.tap(find.byKey(const ValueKey('checkout-continue')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('edit-address-dddddddddddddddddddddddd')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('address-landmark-input')),
          'Near St. Joseph School',
        );
        await _capture(tester, '${size.width}-edit-address');
        await tester.tap(find.byKey(const ValueKey('save-new-address')));
        await tester.pumpAndSettle();
        expect(
          requests.any(
            (r) =>
                r.method == 'PATCH' &&
                r.body.contains('Near St. Joseph School'),
          ),
          isTrue,
        );
        expect(addresses.length, 1);
        await tester.tap(find.byKey(const ValueKey('add-new-address')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Work'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('address-street-input')),
          'Office No. 205, City Plaza',
        );
        await tester.enterText(
          find.byKey(const ValueKey('address-postal-code-input')),
          '123',
        );
        await tester.tap(find.byKey(const ValueKey('save-new-address')));
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid 6-digit PIN code'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('address-postal-code-input')),
          '413512',
        );
        await tester.tap(find.byKey(const ValueKey('save-new-address')));
        await tester.pumpAndSettle();
        expect(addresses.length, 2);
        await _capture(tester, '${size.width}-addresses');
        await tester.tap(find.byKey(const ValueKey('checkout-continue')));
        await tester.pumpAndSettle();
        await _capture(tester, '${size.width}-summary');
        await tester.tap(
          find.byKey(const ValueKey('continue-to-booking-confirmation')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('confirm-booking')));
        await tester.tap(find.byKey(const ValueKey('confirm-booking')));
        await tester.pumpAndSettle();
        final creates = requests
            .where(
              (r) => r.method == 'POST' && r.url.path.endsWith('/bookings'),
            )
            .toList();
        expect(creates.length, 1);
        final body = jsonDecode(creates.single.body) as Map<String, dynamic>;
        expect(body['addressId'], 'eeeeeeeeeeeeeeeeeeeeeeee');
        expect(body['cart']['couponCode'], 'HI20');
        expect(body['cart']['items'], [
          {'serviceId': 'aaaaaaaaaaaaaaaaaaaaaaaa', 'quantity': 1},
          {'serviceId': 'bbbbbbbbbbbbbbbbbbbbbbbb', 'quantity': 1},
        ]);
        expect(body['method'], 'cash');
        expect(creates.single.headers['x-idempotency-key'], isNotEmpty);
        expect(DateTime.parse(body['startsAt']).toLocal().minute, 30);
        expect(
          find.byKey(const ValueKey('professional-search-content')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('find-professional')), findsNothing);
        expect(
          find.byKey(const ValueKey('booking-confirmed-content')),
          findsNothing,
        );
        await _capture(tester, '${size.width}-finding-expert');
        created!['status'] = 'assigned';
        created!['assignmentStatus'] = 'accepted';
        created!['worker'] = {'fullName': 'Assigned Professional'};
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('professional-assigned-content')),
          findsOneWidget,
        );
        expect(find.text('Assigned Professional'), findsOneWidget);
        expect(
          requests
              .where(
                (r) => r.method == 'POST' && r.url.path.endsWith('/bookings'),
              )
              .length,
          1,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        operations.close();
      },
    );
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_CHECKOUT')) return;
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('checkout-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('../../../output/compact-checkout-review');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
