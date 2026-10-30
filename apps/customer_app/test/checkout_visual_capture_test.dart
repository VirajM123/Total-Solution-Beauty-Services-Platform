import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  if (!const bool.fromEnvironment('CAPTURE_CHECKOUT')) return;

  testWidgets('capture checkout reference screens', (tester) async {
    for (final entry in <(String, String)>[
      ('Montserrat', 'assets/fonts/Montserrat-Regular.ttf'),
      (
        'MaterialIcons',
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      ),
    ]) {
      final file = File(entry.$2);
      if (!file.existsSync()) continue;
      await tester.runAsync(() async {
        final loader = FontLoader(entry.$1)
          ..addFont(file.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      });
    }
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Montserrat'),
          home: const DevelopmentHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File(
          'design_previews/$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    await tester.tap(find.byKey(const ValueKey('add-Gold Facial')));
    await tester.tap(find.byKey(const ValueKey('add-Manicure')));
    await tester.pumpAndSettle();
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
    await capture('booking_summary_flutter');

    await tester.tap(
      find.byKey(const ValueKey('continue-to-booking-confirmation')),
    );
    await tester.pumpAndSettle();
    await capture('booking_confirmation_review_flutter');
    await tester.tap(find.byKey(const ValueKey('confirm-booking')));
    await tester.pumpAndSettle();
    await capture('booking_confirmation_flutter');
    expect(tester.takeException(), isNull);
  });
}
