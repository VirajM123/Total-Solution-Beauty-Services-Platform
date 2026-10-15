import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/core/config/app_config.dart';
import 'package:customer_app/core/config/environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Set CAPTURE_VISUALS=true to write actual Flutter renderings for review.
void main() {
  const captureVisuals = bool.fromEnvironment('CAPTURE_VISUALS');
  if (!captureVisuals) return;

  for (final size in const [
    Size(360, 800),
    Size(393, 852),
    Size(400, 686),
    Size(412, 915),
  ]) {
    testWidgets('capture ${size.width}x${size.height}', (tester) async {
      final fontFile = File('build/visual_review/Roboto-Regular.ttf');
      if (fontFile.existsSync()) {
        await tester.runAsync(() async {
          final font = FontLoader('Roboto')
            ..addFont(fontFile.readAsBytes().then(ByteData.sublistView));
          await font.load();
        });
      }
      for (final entry in <(String, String)>[
        ('Georgia', 'C:/Windows/Fonts/georgia.ttf'),
        (
          'MaterialIcons',
          'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
        ),
        (
          'packages/font_awesome_flutter/FontAwesomeBrands',
          'build/unit_test_assets/packages/font_awesome_flutter/lib/fonts/fa-brands-400.ttf',
        ),
      ]) {
        final file = File(entry.$2);
        if (!file.existsSync()) continue;
        await tester.runAsync(() async {
          final font = FontLoader(entry.$1)
            ..addFont(file.readAsBytes().then(ByteData.sublistView));
          await font.load();
        });
      }
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: const CustomerApp(config: AppConfig(Environment.development)),
        ),
      );

      Future<void> capture(String screen) async {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final directory = Directory('build/visual_review')
            ..createSync(recursive: true);
          File(
            '${directory.path}/${size.width.toInt()}x${size.height.toInt()}_$screen.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      await capture('splash');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await capture('onboarding');
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await capture('login');
      expect(tester.takeException(), isNull);
    });
  }
}
