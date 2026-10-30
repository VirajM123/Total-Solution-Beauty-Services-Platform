import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:customer_app/core/constants/app_assets.dart';
import 'package:customer_app/integration/customer_mobile_operations_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _BookingApi extends CustomerMobileOperationsApi {
  final bookingIdempotencyKeys = <String?>[];

  @override
  Future<List<Map<String, dynamic>>> getCatalogServices() async => [
    {
      'id': '123456789012345678901234',
      'name': 'Gold Facial',
      'category': {'name': 'Facial'},
      'pricePaise': '120000',
      'durationMinutes': 60,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getAddresses() async => [
    {
      '_id': '123456789012345678901235',
      'label': 'Saved home',
      'line1': 'Backend street',
      'city': 'Latur',
      'postalCode': '413512',
      'serviceAreaId': '123456789012345678901236',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getBookings() async => [];

  @override
  Future<Map<String, dynamic>> getProfile() async => {
    'user': {'fullName': 'Backend Customer'},
  };

  @override
  Future<List<Map<String, dynamic>>> getRecords(String path) async =>
      path.endsWith('/categories')
      ? [
          {'id': 'category-1', 'name': 'Facial'},
        ]
      : [];

  @override
  Future<Map<String, dynamic>> createBooking({
    required String serviceAreaId,
    required List<Map<String, dynamic>> items,
    required String addressId,
    DateTime? startsAt,
    String method = 'cash',
    String? idempotencyKey,
  }) async {
    bookingIdempotencyKeys.add(idempotencyKey);
    expect(items.single['serviceId'], '123456789012345678901234');
    throw const CustomerMobileApiException(
      statusCode: 409,
      code: 'SLOT_UNAVAILABLE',
      message: 'Appointment slot is unavailable.',
    );
  }
}

class _EmptyApi extends _BookingApi {
  @override
  Future<List<Map<String, dynamic>>> getCatalogServices() async => [];
  @override
  Future<List<Map<String, dynamic>>> getAddresses() async => [];
  @override
  Future<List<Map<String, dynamic>>> getRecords(String path) async => [];
}

class _CustomApi extends _BookingApi {
  @override
  Future<List<Map<String, dynamic>>> getCatalogServices() async => [
    {
      'id': '123456789012345678901234',
      'name': 'Backend Custom Treatment',
      'category': {'name': 'Backend Custom Category'},
      'pricePaise': '135000',
      'durationMinutes': 75,
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> getRecords(String path) async =>
      path.endsWith('/categories')
      ? [
          {'id': 'category-1', 'name': 'Backend Custom Category'},
        ]
      : [];
}

class _OfferApi extends _BookingApi {
  @override
  Future<List<Map<String, dynamic>>> getCatalogServices() async => [
    {
      'id': '123456789012345678901234',
      'name': 'Gold Facial',
      'category': {'name': 'Facial'},
      'pricePaise': 120000,
      'compareAtPricePaise': 150000,
      'durationMinutes': 60,
      'description': 'Backend-discounted facial.',
      'thumbnail': 'https://images.example.test/facial-service.jpg',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getRecords(String path) async {
    if (path.endsWith('/categories')) {
      return [
        {
          'id': 'category-1',
          'name': 'Facial',
          'image': {'url': 'https://images.example.test/facial.jpg'},
        },
      ];
    }
    if (path.endsWith('/offers')) {
      return [
        {
          'id': 'offer-1',
          'name': 'Real Backend Offer',
          'discountType': 'percentage',
          'value': 25,
          'code': 'LIVE25',
          'minimumOrderPaise': 0,
          'thumbnail': 'https://images.example.test/offer.jpg',
        },
      ];
    }
    if (path.endsWith('/packages')) {
      return [
        {
          'id': 'package-1',
          'name': 'Backend Glow Package',
          'description': 'A real backend package description.',
          'pricePaise': 159900,
          'durationMinutes': 105,
          'components': [
            {'serviceId': '123456789012345678901234', 'quantity': 1},
          ],
          'thumbnail': 'https://images.example.test/package.jpg',
        },
      ];
    }
    return [];
  }
}

class _ManyCatalogItemsApi extends _BookingApi {
  @override
  Future<List<Map<String, dynamic>>> getCatalogServices() async => [
    for (var index = 0; index < 6; index++)
      {
        'id': '12345678901234567890123${index + 1}',
        'name': 'Backend service ${index + 1}',
        'category': {'name': index == 5 ? 'Threading' : 'Facials'},
        'pricePaise': 120000,
        'durationMinutes': 60,
      },
  ];

  @override
  Future<List<Map<String, dynamic>>> getRecords(String path) async =>
      path.endsWith('/categories')
      ? [
          {'id': 'category-1', 'name': 'Facials'},
          {'id': 'category-2', 'name': 'Hair Spa'},
          {'id': 'category-3', 'name': 'Makeup'},
          {'id': 'category-4', 'name': 'Waxing'},
          {'id': 'category-5', 'name': 'Manicure & Pedicure'},
          {'id': 'category-6', 'name': 'Threading'},
        ]
      : [];
}

void main() {
  testWidgets(
    'empty backend does not produce sample services or saved addresses',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        MaterialApp(home: DevelopmentHomeScreen(operationsApi: _EmptyApi())),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-Gold Facial')), findsNothing);
      expect(find.byKey(const ValueKey('add-Bridal Makeup')), findsNothing);
      expect(find.text('Select an address'), findsOneWidget);
      expect(find.text('Bridal Packages'), findsNothing);
      expect(find.text('Top Rated Professionals'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new backend categories and services display without app code changes',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        MaterialApp(home: DevelopmentHomeScreen(operationsApi: _CustomApi())),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('add-Backend Custom Treatment')),
        findsOneWidget,
      );
      expect(find.text('Backend Custom Category'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('category-All Services')));
      await tester.pumpAndSettle();
      expect(find.text('Backend Custom Category'), findsWidgets);
      expect(find.text('Bridal Services'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dashboard offers and category photos use backend data', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(home: DevelopmentHomeScreen(operationsApi: _OfferApi())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Real Backend Offer'), findsOneWidget);
    expect(find.text('LIVE25'), findsOneWidget);
    expect(find.text('25% OFF'), findsNWidgets(2));
    expect(find.text('BEAUTY20'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url ==
                'https://images.example.test/facial.jpg',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home limits featured items and All Services keeps full catalog',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        MaterialApp(
          home: DevelopmentHomeScreen(operationsApi: _ManyCatalogItemsApi()),
        ),
      );
      await tester.pumpAndSettle();

      for (var index = 1; index <= 4; index++) {
        expect(
          find.byKey(ValueKey('add-Backend service $index')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('add-Backend service 5')), findsNothing);
      expect(find.byKey(const ValueKey('category-Threading')), findsNothing);
      expect(
        find.byKey(const ValueKey('category-All Services')),
        findsOneWidget,
      );

      await tester.tap(find.text('View All').first);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('service-categories')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Threading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('offers and profile retain original layouts with live records', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(home: DevelopmentHomeScreen(operationsApi: _OfferApi())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offers').last);
    await tester.pumpAndSettle();

    expect(find.text('Offers & Packages'), findsOneWidget);
    expect(find.byKey(const ValueKey('offers-tab-Offers')), findsOneWidget);
    expect(find.byKey(const ValueKey('offers-category-All')), findsOneWidget);
    expect(find.text('Real Backend Offer'), findsOneWidget);
    expect(find.text('Gold Facial'), findsOneWidget);
    final offerDetails = find.byKey(
      const ValueKey('offer-promotion-details-LIVE25'),
    );
    await tester.ensureVisible(offerDetails);
    await tester.tap(offerDetails);
    await tester.pumpAndSettle();
    expect(find.text('Discount: 25% off'), findsOneWidget);
    expect(find.text('Code: LIVE25'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == AppAssets.offersBanner,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();
    expect(find.text('Backend Glow Package'), findsOneWidget);
    expect(
      find.textContaining('A real backend package description.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('add-package-backend glow package')),
    );
    await tester.pumpAndSettle();
    expect(find.text('My Cart (1)'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-menu-Settings')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('profile-settings-screen')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-menu-Settings')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Offer updates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> confirmGoldFacial(
    WidgetTester tester, {
    _BookingApi? operationsApi,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DevelopmentHomeScreen(
          operationsApi: operationsApi ?? _BookingApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-Gold Facial')));
    await tester.tap(find.text('My Cart').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proceed-to-booking')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('checkout-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('checkout-continue')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('continue-to-booking-confirmation')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-booking')));
    await tester.pumpAndSettle();
  }

  testWidgets('home offers only services returned by the backend catalog', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(home: DevelopmentHomeScreen(operationsApi: _BookingApi())),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-Gold Facial')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-Bridal Makeup')), findsNothing);
    expect(find.byKey(const ValueKey('add-Hair Spa')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed booking preserves checkout and never assigns a sample professional',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = _BookingApi();
      await confirmGoldFacial(tester, operationsApi: api);
      expect(
        find.text(
          'This appointment time is no longer available. Choose another time and try again.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('confirm-booking')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-confirmation-review')),
        findsOneWidget,
      );
      expect(find.text('No preview booking is available.'), findsNothing);
      expect(find.text('Review your booking'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-booking')));
      await tester.pumpAndSettle();
      expect(api.bookingIdempotencyKeys, hasLength(2));
      expect(api.bookingIdempotencyKeys[0], api.bookingIdempotencyKeys[1]);
      expect(
        find.byKey(const ValueKey('booking-confirmation-review')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('track-professional')), findsNothing);
      expect(find.text('Professional Assigned'), findsNothing);
      expect(find.text('Priya Shinde'), findsNothing);
      expect(find.byKey(const ValueKey('service-start-otp')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
