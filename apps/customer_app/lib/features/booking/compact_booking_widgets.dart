import '../shared/customer_image.dart';
import '../shared/compact_customer_surface.dart';
import 'package:flutter/material.dart';

const bookingPink = Color(0xFFE90057);
const bookingBlush = Color(0xFFFFF0F5);

/// Presentation of the existing search state, with a connected step indicator.
class CompactSearchProgress extends StatelessWidget {
  const CompactSearchProgress({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 3; i++)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Icon(
                      i == 0
                          ? Icons.check_circle
                          : i == 1
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: i < 2 ? bookingPink : const Color(0xFFD7D0D6),
                    ),
                    if (i < 2)
                      Expanded(
                        child: Container(
                          width: 1,
                          color: const Color(0xFFF3DAE3),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    const [
                      'Booking received',
                      'Searching nearby professionals',
                      'Expert assignment pending',
                    ][i],
                    style: TextStyle(
                      fontSize: 13,
                      color: i == 1 ? bookingPink : const Color(0xFF66545D),
                      fontWeight: i == 1 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class CompactBookingThumbnail extends StatelessWidget {
  const CompactBookingThumbnail({super.key, this.image});
  final String? image;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => const ColoredBox(
      color: bookingBlush,
      child: Center(
        child: Icon(Icons.spa_outlined, size: 23, color: bookingPink),
      ),
    );
    if (image == null || image!.isEmpty) return fallback();
    return Image(
      image: image!.startsWith('http')
          ? customerImageProvider(image!)
          : AssetImage(image!) as ImageProvider,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback(),
    );
  }
}

/// Presentation only: booking state and actions remain owned by the caller.
class CompactBookingPanel extends StatelessWidget {
  const CompactBookingPanel({
    super.key,
    required this.child,
    this.tinted = false,
    this.flat = false,
  });
  final Widget child;
  final bool tinted;
  final bool flat;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(flat ? 0 : 10),
    decoration: BoxDecoration(
      color: flat
          ? Colors.transparent
          : tinted
          ? bookingBlush
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: flat ? null : Border.all(color: const Color(0xFFF5D9E3)),
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
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 44,
            height: 44,
            child: image == null || image!.isEmpty
                ? const ColoredBox(
                    color: bookingBlush,
                    child: Icon(Icons.spa_outlined, color: bookingPink),
                  )
                : Image(
                    image: image!.startsWith('http')
                        ? customerImageProvider(image!)
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.35)),
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
    color:
        context.findAncestorWidgetOfExactType<CompactCustomerSurface>() != null
        ? Colors.transparent
        : const Color(0xFFFFFAFC),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient:
            decorated &&
                context
                        .findAncestorWidgetOfExactType<
                          CompactCustomerSurface
                        >() ==
                    null
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
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
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
                      fontSize: 20,
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [body],
            ),
          ),
          if (action != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: double.infinity,
                    minHeight: 48,
                  ),
                  child: action,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
