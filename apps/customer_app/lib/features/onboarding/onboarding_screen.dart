import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../../app/route_names.dart';
import '../../core/constants/app_assets.dart';
import '../shared/floral_background.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _continue(BuildContext context) =>
      Navigator.of(context).pushReplacementNamed(RouteNames.login);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FloralBackground(
      asset: AppAssets.onboardingScene,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final compact = height < 690;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: height * (compact ? .42 : .45)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Beauty\nOur Care\nAt Home',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: const Color(0xFF4A102B),
                                    fontSize: compact ? 27 : 31,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Professional beauty services\nby certified experts,\nnow at your doorstep\nin Latur.',
                              style: TextStyle(
                                color: BeautyColors.ink,
                                height: 1.25,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Column(
                          children: [
                            BeautyButton(
                              label: 'Get Started',
                              onPressed: () => _continue(context),
                            ),
                            const SizedBox(height: 17),
                            TextButton(
                              onPressed: () => _continue(context),
                              child: const Text(
                                'Skip',
                                style: TextStyle(
                                  color: BeautyColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
