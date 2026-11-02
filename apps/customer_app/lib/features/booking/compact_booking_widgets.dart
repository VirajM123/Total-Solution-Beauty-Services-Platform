import 'package:flutter/material.dart';

const bookingPink = Color(0xFFE90057);
const bookingBlush = Color(0xFFFFF0F5);

/// Presentation only: booking state and actions remain owned by the caller.
class CompactBookingPanel extends StatelessWidget {
  const CompactBookingPanel({
    super.key,
    required this.child,
    this.tinted = false,
  });
  final Widget child;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: tinted ? bookingBlush : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF5D9E3)),
    ),
    child: child,
  );
}

class CompactBookingService extends StatelessWidget {
  const CompactBookingService({
    super.key,
    required this.name,
    required this.amount,
    this.image,
    this.subtitle,
  });
  final String name;
  final String amount;
  final String? image;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 48,
            height: 46,
            child: image == null || image!.isEmpty
                ? const ColoredBox(
                    color: bookingBlush,
                    child: Icon(Icons.spa_outlined, color: bookingPink),
                  )
                : Image(
                    image: image!.startsWith('http')
                        ? NetworkImage(image!)
                        : AssetImage(image!) as ImageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: bookingBlush,
                      child: Icon(Icons.spa_outlined, color: bookingPink),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF777078),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 90),
          child: Text(
            amount,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class CompactBookingFact extends StatelessWidget {
  const CompactBookingFact({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: bookingPink),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 11, height: 1.35)),
        ),
      ],
    ),
  );
}

class CompactBookingFrame extends StatelessWidget {
  const CompactBookingFrame({
    super.key,
    required this.title,
    required this.onBack,
    required this.contentKey,
    required this.body,
    this.action,
    this.backKey,
    this.decorated = false,
  });
  final String title;
  final VoidCallback onBack;
  final String contentKey;
  final Widget body;
  final Widget? action;
  final Key? backKey;
  final bool decorated;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFFAFC),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: decorated
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFE4EF),
                  Color(0xFFFFFAFC),
                  Color(0xFFFFEDF5),
                ],
                stops: [0, .5, 1],
              )
            : null,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  key: backKey,
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: bookingPink,
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: ValueKey(contentKey),
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              children: [body],
            ),
          ),
          if (action != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: action,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
