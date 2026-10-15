import 'dart:async';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../../app/route_names.dart';
import '../../core/constants/app_assets.dart';
import '../shared/brand_mark.dart';
import '../shared/floral_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(RouteNames.onboarding);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FloralBackground(
      asset: AppAssets.splashScene,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final compact = height < 740;
            return Stack(
              children: [
                Positioned(
                  top: height * (compact ? .08 : .13),
                  left: 0,
                  right: 0,
                  child: const BrandMark(),
                ),
                Positioned(
                  top: height * (compact ? .77 : .81),
                  left: 0,
                  right: 0,
                  child: const Text(
                    'Professional Beauty Services\nat Your Home',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BeautyColors.ink,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                Positioned(
                  bottom: height * .045,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 27,
                        height: 4,
                        decoration: BoxDecoration(
                          color: BeautyColors.deepPink,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 27,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7A5BA),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
