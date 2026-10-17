import 'package:flutter/material.dart';
import '../../core/constants/pinkora_brand.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        PinkoraBrand.name,
        style: TextStyle(
          color: PinkoraBrand.berry,
          fontFamily: 'Montserrat',
          fontSize: compact ? 27 : 38,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          height: 1.1,
        ),
      ),
      SizedBox(height: compact ? 3 : 6),
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
