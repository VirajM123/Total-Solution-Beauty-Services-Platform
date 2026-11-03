import 'package:flutter/material.dart';

/// Two bounded source rectangles keep the complete original wordmark visible.
class WorkerAuthBrand extends StatelessWidget {
  const WorkerAuthBrand({
    super.key,
    this.subtitle = 'For Beauty Professionals',
  });
  final String subtitle;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Hi Beauty',
    image: true,
    child: ExcludeSemantics(
      child: SizedBox(
        width: 190,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/dashboard/reference_brand.png',
              width: 190,
              fit: BoxFit.contain,
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 68, top: 2),
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF686080),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _BrandFragment extends StatelessWidget {
  const _BrandFragment({required this.source});
  final Rect source;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: source.width / source.height,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / source.width;
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: -source.left * scale,
                top: -source.top * scale,
                width: 1254 * scale,
                height: 1254 * scale,
                child: Image.asset(
                  'assets/images/logo/logo.png',
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Bounded artwork keeps the subject clear of form controls at every height.
class WorkerAuthHero extends StatelessWidget {
  const WorkerAuthHero({super.key, this.height = 230, this.phone = false});
  final double height;
  final bool phone;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        phone
            ? 'assets/images/illustrations/worker_customer_otp_phone.png'
            : 'assets/images/backgrounds/worker_auth_petals.png',
        fit: BoxFit.cover,
        alignment: phone ? const Alignment(0, -.25) : const Alignment(.65, -.1),
        excludeFromSemantics: true,
      ),
    ),
  );
}

class WorkerAuthSteps extends StatelessWidget {
  const WorkerAuthSteps({super.key, required this.active});
  final int active;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < 4; index++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1.5,
                        color: index == 0
                            ? Colors.transparent
                            : const Color(0xFFFFCEE0),
                      ),
                    ),
                    Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == active
                            ? const Color(0xFFFF1678)
                            : Colors.white,
                        border: Border.all(color: const Color(0xFFFFCEE0)),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          color: index == active
                              ? Colors.white
                              : const Color(0xFF686080),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1.5,
                        color: index == 3
                            ? Colors.transparent
                            : const Color(0xFFFFCEE0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  const [
                    'Personal\nDetails',
                    'Work\nDetails',
                    'Documents',
                    'Complete',
                  ][index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    color: index == active
                        ? const Color(0xFFFF1678)
                        : const Color(0xFF686080),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Decorative lotus from the existing brand artwork, without the wordmark.
class WorkerLotusArtwork extends StatelessWidget {
  const WorkerLotusArtwork({super.key});
  @override
  Widget build(BuildContext context) =>
      const _BrandFragment(source: Rect.fromLTWH(120, 68, 1010, 738));
}
