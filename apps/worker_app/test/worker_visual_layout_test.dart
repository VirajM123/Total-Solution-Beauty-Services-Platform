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
import 'package:worker_app/features/home/worker_payouts_screen.dart';
import 'package:worker_app/features/home/worker_service_history_screen.dart';
import 'package:worker_app/features/registration/screens/worker_personal_details_screen.dart';
import 'package:worker_app/features/widgets/worker_images.dart';

void main() {
  final date = DateTime(2026, 11, 2, 9);
  final orders = [
    WorkerDashboardOrder(
      id: 'HB28491',
      customer: 'Sneha Patil',
      service: 'Gold Facial',
      time: '10:30 AM',
      location: 'Mangalwar Peth, Latur',
      customerPayable: 1200,
      status: 'Accepted',
      appointmentDate: date,
    ),
    WorkerDashboardOrder(
      id: 'HB28492',
      customer: 'Rutuja More',
      service: 'Hair Spa',
      time: '1:00 PM',
      location: 'MIDC, Latur',
      customerPayable: 800,
      status: 'Completed',
      appointmentDate: date,
      completedAt: date,
    ),
  ];

  testWidgets(
    'compact worker screens fit phone widths with complete controls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final font = FontLoader('Montserrat')
        ..addFont(rootBundle.load('assets/fonts/Montserrat-Regular.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final screens = <String, Widget Function()>{
        'dashboard': () => WorkerDashboardScreen(
          demoMode: false,
          orders: orders,
          workerName: 'Priya Shinde',
          location: 'Latur, Maharashtra',
          currentDate: date,
        ),
        'bookings': () => WorkerBookingsScreen(demoMode: false, orders: orders),
        'incoming': () => WorkerIncomingBookingScreen(order: orders.first),
        'payouts': () => const WorkerPayoutsScreen(),
        'history': () =>
            WorkerServiceHistoryScreen(demoMode: false, orders: orders),
        'registration': () => const WorkerPersonalDetailsScreen(),
      };
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 844);
        for (final entry in screens.entries) {
          final key = GlobalKey();
          final old = FlutterError.onError;
          FlutterError.onError = (details) {
            debugPrint(details.toString());
            old?.call(details);
          };
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'Montserrat'),
              home: RepaintBoundary(key: key, child: entry.value()),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
          FlutterError.onError = old;
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} at $width',
          );
          if (width == 390) {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('../../../output/worker-app/implemented');
              await dir.create(recursive: true);
              await File(
                '${dir.path}/${entry.key}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets(
    'worker photo uses supplied URL and missing photo stays neutral',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              WorkerProfilePhoto(path: 'https://example.test/priya.jpg'),
              WorkerProfilePhoto(),
            ],
          ),
        ),
      );
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images.length, 1);
      expect(
        (images.single.image as NetworkImage).url,
        'https://example.test/priya.jpg',
      );
      expect(find.byIcon(Icons.person_outline_rounded), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
