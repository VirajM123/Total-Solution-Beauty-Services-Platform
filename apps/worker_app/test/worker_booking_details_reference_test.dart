import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_booking_details_screen.dart';
import 'package:worker_app/features/widgets/worker_booking_reference_panel.dart';
import 'package:worker_app/integration/worker_mobile_operations_api.dart';

final fixture = WorkerDashboardOrder(
  id: 'HB28491',
  customer: 'Sneha Patil',
  service: 'Gold Facial',
  time: '10:30 AM',
  location: 'Mangalwar Peth, Latur',
  customerPayable: 1200,
  status: 'Accepted',
  appointmentDate: DateTime(2026, 11, 2),
  customerPhone: '+91 98765 43210',
  customerNote: 'Please use gentle products. I have sensitive skin.',
  itemsDescription: 'Deep cleansing, brightening and radiant skin.',
  paymentMethod: 'cash',
);

class TravelApi extends WorkerMobileOperationsApi {
  WorkerDashboardOrder current = fixture;
  final actions = <String>[];
  @override
  Future<WorkerDashboardOrder?> fetchBookingDetails(String id) async => current;
  @override
  Future<Map<String, dynamic>> updateBookingProgress({
    required String bookingId,
    required String action,
    String? otp,
    List<String> evidenceIds = const [],
  }) async {
    actions.add(action);
    current = current.copyWith(
      status: action == 'travel' ? 'Travelling' : 'Arrived',
    );
    return {};
  }
}

void main() {
  testWidgets(
    'booking details and travel layouts retain travel and arrival transitions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final font = FontLoader('WorkerDashboardText')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 844);
        final api = TravelApi();
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: WorkerBookingDetailsScreen(
                order: fixture,
                demoMode: false,
                operationsApi: api,
                onNavigationSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(fixture.customerNote!), findsOneWidget);
        expect(find.text('Start Navigation'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 390) await save(tester, key, 'booking-details');
        await tester.tap(find.byKey(const Key('start-service-entry')));
        await tester.pumpAndSettle();
        expect(api.actions, ['travel']);
        expect(find.byType(WorkerTravelReferenceView), findsOneWidget);
        expect(find.text('I Have Arrived'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 390) await save(tester, key, 'navigation');
        await tester.tap(find.byKey(const Key('start-service-entry')));
        await tester.pumpAndSettle();
        expect(api.actions, ['travel', 'arrive']);
        expect(find.byType(WorkerTravelReferenceView), findsNothing);
        expect(
          find.text('Upload Product Photo & Enter Customer OTP'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.close();
      }
    },
  );
}

Future<void> save(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    for (final asset in [
      'reference_brand.png',
      'reference_map.png',
      'reference_route.png',
      'reference_customer.png',
      'reference_facial.png',
    ]) {
      await precacheImage(
        AssetImage('assets/images/dashboard/$asset'),
        key.currentContext!,
      );
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('../../../output/booking-details-reference-review');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
