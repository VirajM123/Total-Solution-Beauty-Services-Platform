import 'package:flutter/material.dart';

/// Visual primitives shared by the worker's primary screens.
abstract final class WorkerDesign {
  static const pink = Color(0xFFF52D7A);
  static const deep = Color(0xFF111D3A);
  static const muted = Color(0xFF667085);
  static const cream = Color(0xFFFFF7FA);
  static const border = Color(0xFFF4DDE6);

  static BoxDecoration surface({double radius = 16}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
    boxShadow: const [
      BoxShadow(color: Color(0x14C74776), blurRadius: 10, offset: Offset(0, 3)),
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
    constraints: const BoxConstraints(minHeight: 76),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
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
                'assets/images/backgrounds/worker_soft_canvas.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
        Positioned(
          right: -20,
          top: -20,
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0x48FFFFFF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 22,
          child: Icon(icon, size: 28, color: const Color(0x66E91368)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 58, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 3),
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
