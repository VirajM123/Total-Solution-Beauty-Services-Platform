import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';

/// Existing brand artwork, shared by authentication screens.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Image.asset(
    AppAssets.hiBeautyLogo,
    key: const ValueKey('hi-beauty-logo'),
    width: compact ? 100 : 148,
    height: compact ? 100 : 148,
    fit: BoxFit.contain,
    semanticLabel: PinkoraBrand.name,
  );
}
