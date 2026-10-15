import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../../app/route_names.dart';
import '../shared/brand_mark.dart';

class DevelopmentHomeScreen extends StatelessWidget {
  const DevelopmentHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: BeautyPage(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BrandMark(),
        const SizedBox(height: 40),
        const BeautyCard(child: Column(children: [
          Icon(Icons.construction_rounded, color: BeautyColors.pink, size: 42),
          SizedBox(height: 12),
          Text('Home screen coming in the next phase', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('Temporary development placeholder. No booking or account was created.', textAlign: TextAlign.center),
        ])),
        const SizedBox(height: 24),
        BeautyButton(label: 'Back to onboarding', onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.onboarding, (route) => false)),
      ],
    )),
  );
}
