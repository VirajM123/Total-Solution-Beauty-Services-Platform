import 'package:flutter/material.dart';

import '../../core/constants/pinkora_brand.dart';

/// Wordmark and small blossom are real widgets, independent of the hero art.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 31.0 : 43.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: compact ? 18 : 22,
          child: CustomPaint(
            size: Size(compact ? 25 : 31, compact ? 18 : 22),
            painter: _BlossomPainter(),
          ),
        ),
        Text(
          PinkoraBrand.name,
          style: TextStyle(
            color: PinkoraBrand.berry,
            fontFamily: 'Montserrat',
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: -2,
            height: 1,
          ),
        ),
        SizedBox(height: compact ? 3 : 5),
        Text(
          PinkoraBrand.tagline,
          style: TextStyle(
            color: PinkoraBrand.charcoal,
            fontFamily: 'Montserrat',
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w400,
            letterSpacing: compact ? 0.5 : 1.1,
          ),
        ),
      ],
    );
  }
}

class _BlossomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = PinkoraBrand.rose;
    final center = Offset(size.width * .5, size.height * .85);
    for (final angle in [-.8, 0.0, .8]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -size.height * .42),
          width: size.width * .27,
          height: size.height * .68,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
