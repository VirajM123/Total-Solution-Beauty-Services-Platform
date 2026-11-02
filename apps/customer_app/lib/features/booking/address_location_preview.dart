import 'package:flutter/material.dart';
import 'compact_booking_widgets.dart';

/// A decorative service-area illustration, never a live or geocoded map.
class AddressLocationPreview extends StatelessWidget {
  const AddressLocationPreview({super.key, required this.city});
  final String city;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height < 740 ? 86 : 116,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _AreaStreets()),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: bookingPink, size: 34),
              const SizedBox(height: 5),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    city.isEmpty
                        ? 'Select your service address'
                        : '$city, Maharashtra',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AreaStreets extends CustomPainter {
  const _AreaStreets();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFE5EC),
    );
    final street = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    for (var index = -3; index < 14; index++) {
      final x = index * size.width / 8;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.width * .25, size.height),
        street,
      );
    }
    for (var index = -1; index < 7; index++) {
      final y = index * size.height / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y - size.height * .45),
        street,
      );
    }
    canvas.drawLine(
      Offset(size.width * .15, 0),
      Offset(size.width * .85, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 8,
    );
  }

  @override
  bool shouldRepaint(covariant _AreaStreets oldDelegate) => false;
}
