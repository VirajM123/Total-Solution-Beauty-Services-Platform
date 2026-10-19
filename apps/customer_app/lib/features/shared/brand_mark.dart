import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        AppAssets.hiBeautyLogo,
        key: const ValueKey('hi-beauty-logo'),
        width: compact ? 132 : 190,
        height: compact ? 132 : 190,
        fit: BoxFit.contain,
        semanticLabel: PinkoraBrand.name,
      ),
      SizedBox(height: compact ? 2 : 6),
      Text(
        PinkoraBrand.tagline,
        style: TextStyle(
          color: PinkoraBrand.charcoal,
          fontSize: compact ? 11 : 13,
          letterSpacing: 0.4,
        ),
      ),
    ],
  );
}
