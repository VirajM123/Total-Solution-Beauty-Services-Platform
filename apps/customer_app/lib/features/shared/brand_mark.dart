import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.spa_rounded, color: BeautyColors.pink, size: compact ? 42 : 70),
      Text('Total Solution', style: TextStyle(color: BeautyColors.deepPink, fontSize: compact ? 20 : 26, fontWeight: FontWeight.w800, height: 1)),
      Text('Beauty at Your Doorstep', style: TextStyle(color: BeautyColors.ink, fontSize: compact ? 10 : 12)),
    ],
  );
}
