import 'package:worker_app/features/widgets/worker_reference_widgets.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_bookings_screen.dart';
import 'package:worker_app/features/home/worker_dashboard_screen.dart';
import 'package:worker_app/features/home/worker_incoming_booking_screen.dart';

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  final orders = [
    WorkerDashboardOrder(
      id: 'fixture-facial',
      customer: 'Test Customer One',
      service: 'Gold Facial',
      time: '10:30 AM',
      location: 'Test service area',
      customerPayable: 1200,
      status: 'Accepted',
      appointmentDate: today,
      customerNote: 'Please use fragrance-free products.',
    ),
    WorkerDashboardOrder(
      id: 'fixture-hair',
      customer: 'Test Customer Two',
      service: 'Hair Spa',
      time: '1:00 PM',
      location: 'Test service area',
      customerPayable: 800,
      status: 'Scheduled',
      appointmentDate: today,
    ),
    WorkerDashboardOrder(
      id: 'fixture-makeup',
      customer: 'Test Customer Three',
      service: 'Bridal Makeup',
      time: '4:00 PM',
      location: 'Test service area',
      customerPayable: 2500,
      status: 'Completed',
      appointmentDate: today,
      completedAt: today,
      compensationRupees: 500,
    ),
  ];

  testWidgets('reference booking pages fit phone widths with decoded artwork', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      ),
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Montserrat')
      ..addFont(rootBundle.load('assets/fonts/Montserrat-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      final pages = <String, Widget>{
        'dashboard': WorkerDashboardScreen(
          demoMode: true,
          orders: orders,
          currentDate: today.add(const Duration(hours: 9)),
          workerName: 'Test Expert',
          location: 'Test service area',
          isApproved: true,
        ),
        'bookings': WorkerBookingsScreen(
          demoMode: true,
          orders: orders,
          location: 'Test service area',
          onNavigationSelected: (_) {},
        ),
        'incoming': WorkerIncomingBookingScreen(order: orders.first),
      };
      for (final page in pages.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Montserrat'),
            home: RepaintBoundary(key: key, child: page.value),
          ),
        );
        await tester.runAsync(() async {
          await Future.wait([
            for (final asset in [
              'assets/images/logo/logo.png',
              'assets/images/services/gold_facial.png',
              'assets/images/services/hair_spa.png',
              'assets/images/services/bridal_makeup.png',
            ])
              precacheImage(AssetImage(asset), key.currentContext!),
          ]);
        });
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull, reason: '${page.key} at $width');
        expect(
          tester.getSize(find.byType(WorkerReferenceHeader)).height,
          greaterThan(50),
          reason: page.key,
        );
        expect(
          tester.getTopLeft(find.byType(WorkerReferenceHeader)).dy,
          greaterThanOrEqualTo(0),
          reason: page.key,
        );
        if (width == 390) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory(
              '../../../output/worker-booking-reference-review',
            );
            await dir.create(recursive: true);
            await File(
              '${dir.path}/${page.key}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('accept and expiry return the existing offer decisions', (
    tester,
  ) async {
    WorkerOfferDecision? result;
    Future<void> mount(Duration expiry) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<WorkerOfferDecision>(
                        MaterialPageRoute(
                          builder: (_) => WorkerIncomingBookingScreen(
                            order: orders.first,
                            isLiveOffer: true,
                            expiresAfter: expiry,
                          ),
                        ),
                      );
                },
                child: const Text('Open offer'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open offer'));
      await tester.pumpAndSettle();
    }

    await mount(const Duration(seconds: 60));
    await tester.tap(find.text('Accept Booking'));
    await tester.pumpAndSettle();
    expect(result?.type, WorkerOfferDecisionType.accepted);
    await tester.pumpWidget(const SizedBox());
    result = null;
    await mount(const Duration(seconds: 2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3100)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(result?.type, WorkerOfferDecisionType.expired);
    expect(tester.takeException(), isNull);
  });
}
