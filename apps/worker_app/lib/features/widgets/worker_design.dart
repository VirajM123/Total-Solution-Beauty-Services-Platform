import 'package:flutter/material.dart';

/// Visual primitives shared by the worker's primary screens.
abstract final class WorkerDesign {
  static const pink = Color(0xFFF50070);
  static const deep = Color(0xFF111D3A);
  static const muted = Color(0xFF667085);
  static const cream = Color(0xFFFFF7FA);
  static const border = Color(0xFFF4DDE6);

  static BoxDecoration surface({double radius = 22}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
    boxShadow: const [
      BoxShadow(color: Color(0x14C74776), blurRadius: 18, offset: Offset(0, 7)),
    ],
  );
}

class WorkerPageBanner extends StatelessWidget {
  const WorkerPageBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.photo = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool photo;

  @override
  Widget build(BuildContext context) => Container(
    height: 150,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFEDF4), Color(0xFFFFD9E9), Color(0xFFFFF8FA)],
      ),
    ),
    child: Stack(
      children: [
        if (photo)
          Positioned.fill(
            child: Opacity(
              opacity: .38,
              child: Image.asset(
                'assets/images/dashboard/makeup_brushes.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
        Positioned(
          right: -20,
          top: -20,
          child: Container(
            width: 132,
            height: 132,
            decoration: const BoxDecoration(
              color: Color(0x48FFFFFF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 36,
          child: Icon(icon, size: 72, color: const Color(0x66E91368)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 17, 104, 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                eyebrow.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WorkerDesign.pink,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WorkerDesign.muted,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
