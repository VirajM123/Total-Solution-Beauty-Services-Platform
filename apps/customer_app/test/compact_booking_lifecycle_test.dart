import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:customer_app/integration/customer_auth_api.dart';
import 'package:customer_app/integration/customer_mobile_operations_api.dart';
import 'package:customer_app/integration/mobile_push.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
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
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });
  for (final width in [320.0, 393.0, 412.0]) {
    testWidgets(
      'compact lifecycle preserves server states and actions $width',
      (tester) async {
        tester.view.physicalSize = Size(width, width == 320 ? 686 : 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final writes = <String>[];
        var otpAttempts = 0;
        final booking = <String, dynamic>{
          '_id': 'booking123456',
          'status': 'assigned',
          'assignmentStatus': 'accepted',
          'startsAt': '2026-11-03T04:30:00Z',
          'totalPaise': 170000,
          'subtotalPaise': 170000,
          'paymentStatus': 'pending',
          'worker': {'fullName': 'Priya Sharma'},
          'addressSnapshot': {
            'label': 'Home',
            'line1': '12 Rose Lane',
            'city': 'Latur',
          },
          'items': [
            {'name': 'Gold Facial', 'quantity': 1, 'pricePaise': 120000},
            {'name': 'Manicure', 'quantity': 1, 'pricePaise': 50000},
          ],
        };
        final operations = CustomerMobileOperationsApi(
          apiBaseUrl: 'https://example.test/api',
          tokenStorage: _Storage(),
          client: MockClient((request) async {
            final path = request.url.path;
            if (request.method != 'GET') writes.add('$path ${request.body}');
            dynamic data = <String, dynamic>{
              'items': [],
              'user': {'fullName': 'Customer'},
            };
            if (path.endsWith('/bookings/booking123456')) data = booking;
            if (path.endsWith('/bookings'))
              data = {
                'items': [booking],
              };
            if (path.endsWith('/service-otp/reveal')) {
              otpAttempts++;
              if (otpAttempts == 1) {
                return http.Response(
                  jsonEncode({
                    'error': {'message': 'Retry required'},
                  }),
                  503,
                );
              }
              data = {'otp': '4826'};
            }
            if (path.endsWith('/services'))
              data = {
                'items': [
                  for (final item in booking['items'] as List)
                    {
                      ...item as Map,
                      '_id': item['name'] == 'Manicure'
                          ? 'bbbbbbbbbbbbbbbbbbbbbbbb'
                          : 'aaaaaaaaaaaaaaaaaaaaaaaa',
                      'category': {'name': 'Beauty'},
                      'durationMinutes': 60,
                      'thumbnail': item['name'] == 'Manicure'
                          ? 'assets/images/home/manicure.png'
                          : 'assets/images/home/gold_facial.png',
                    },
                ],
              };
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Montserrat'),
            home: RepaintBoundary(
              key: const ValueKey('capture'),
              child: DevelopmentHomeScreen(operationsApi: operations),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('View All').first);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('service-categories')),
          findsOneWidget,
        );
        MobilePush.pendingOpen.value = {
          'type': 'booking.updated',
          'entityId': 'booking123456',
        };
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('track-professional')),
          findsOneWidget,
        );
        expect(find.text('Priya Sharma'), findsOneWidget);
        expect(find.byKey(const ValueKey('service-categories')), findsNothing);
        expect(tester.takeException(), isNull);
        await _capture(tester, '$width-assigned');
        await tester.tap(find.byKey(const ValueKey('track-professional')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('professional-tracking-content')),
          findsOneWidget,
        );
        await _capture(tester, '$width-tracking');
        expect(
          find.byKey(const ValueKey('view-service-start-code')),
          findsNothing,
        );
        expect(
          writes.any((request) => request.contains('service-otp/reveal')),
          isFalse,
        );
        booking['status'] = 'arrived';
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(otpAttempts, greaterThanOrEqualTo(2));
        expect(find.text('4826'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _capture(tester, '$width-otp');
        booking['status'] = 'in_progress';
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('service-elapsed-time')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _capture(tester, '$width-progress');
        booking['pendingExtraServices'] = [
          {'_id': 'extra1', 'name': 'Head Massage', 'amountPaise': 30000},
        ];
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Decline'));
        await _capture(tester, '$width-extra-approval');
        await tester.tap(find.text('Decline'));
        await tester.pumpAndSettle();
        expect(
          writes.any(
            (w) =>
                w.contains('/extra-services/extra1/respond') &&
                w.contains('reject'),
          ),
          isTrue,
        );
        booking['pendingExtraServices'] = [];
        booking['serviceFinishedAt'] = '2026-11-03T06:00:00Z';
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.text('Awaiting payment'), findsOneWidget);
        await _capture(tester, '$width-awaiting-payment');
        expect(find.byKey(const ValueKey('rate-service')), findsNothing);
        booking['status'] = 'completed';
        booking['paymentStatus'] = 'paid';
        MobilePush.pendingOpen.value = {
          'type': 'booking.updated',
          'entityId': 'booking123456',
        };
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('rate-service')), findsOneWidget);
        await _capture(tester, '$width-completed');
        await tester.tap(find.byKey(const ValueKey('rate-service')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('experience-rating-5')));
        await tester.enterText(
          find.byKey(const ValueKey('experience-review-text')),
          'Excellent service',
        );
        await tester.pumpAndSettle();
        await _capture(tester, '$width-review');
        await tester.tap(
          find.byKey(const ValueKey('submit-experience-review')),
        );
        await tester.pumpAndSettle();
        expect(
          writes.any(
            (w) => w.contains('review') && w.contains('Excellent service'),
          ),
          isTrue,
        );
        await tester.tap(
          find.byKey(const ValueKey('bookings-filter-Completed')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Gold Facial + Manicure'), findsOneWidget);
        await _capture(tester, '$width-bookings');
        await tester.tap(find.text('View Details'));
        await tester.pumpAndSettle();
        expect(find.text('Booking details'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        operations.close();
        MobilePush.pendingOpen.value = null;
      },
    );
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_BOOKINGS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('../../../output/compact-booking-review');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
