import 'package:flutter/material.dart';
import '../../core/constants/pinkora_brand.dart';

/// Existing brand artwork, shared by authentication screens.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.compact = false});
  final bool compact;
  double get dimension => compact ? 104 : 160;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/branding/hi_beauty_logo_transparent.png',
    key: const ValueKey('hi-beauty-logo'),
    width: dimension,
    height: dimension,
    fit: BoxFit.contain,
    semanticLabel: PinkoraBrand.name,
  );
}
