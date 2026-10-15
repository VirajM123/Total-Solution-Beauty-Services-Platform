import 'package:flutter/material.dart';

/// Full-bleed artwork, with layout and text kept as independent Flutter widgets.
class FloralBackground extends StatelessWidget {
  const FloralBackground({super.key, required this.asset, required this.child});

  final String asset;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(asset, fit: BoxFit.cover, excludeFromSemantics: true),
      child,
    ],
  );
}
