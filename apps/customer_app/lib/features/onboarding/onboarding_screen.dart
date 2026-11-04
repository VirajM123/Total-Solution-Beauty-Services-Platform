import '../shared/auth_brand_mark.dart';
import '../shared/customer_refinements.dart';
import 'package:flutter/material.dart';
import '../../app/route_names.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';
import '../shared/floral_background.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _continue(BuildContext context) =>
      Navigator.of(context).pushReplacementNamed(RouteNames.login);

  @override
  Widget build(BuildContext context) => Theme(
    data: CustomerRefinements.theme(Theme.of(context)),
    child: Scaffold(
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: TextButton(
                              onPressed: () => _continue(context),
                              child: const Text('Skip'),
                            ),
                          ),
                        ),
                        SizedBox(height: height * (compact ? .25 : .29)),
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00FFFAF9),
                                Color(0xE6FFFAF9),
                                Color(0x00FFFAF9),
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              const AuthBrandMark(compact: true),
                              const SizedBox(height: 10),
                              Text(
                                'Beauty that fits\nyour life.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: PinkoraBrand.berry,
                                  fontSize: compact ? 29 : 33,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                  letterSpacing: -.8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'A little time for you, wherever you are.\nExplore beauty services on your terms.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: PinkoraBrand.muted,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: FilledButton(
                            onPressed: () => _continue(context),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Get Started'),
                                SizedBox(width: 12),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
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
    ),
  );
}
