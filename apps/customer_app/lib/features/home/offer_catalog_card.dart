import 'package:flutter/material.dart';

import '../../core/constants/pinkora_brand.dart';

/// Presentation shared by offers, discounted services, and packages.
class OfferCatalogCard extends StatelessWidget {
  const OfferCatalogCard({
    super.key,
    required this.image,
    required this.title,
    required this.description,
    required this.price,
    required this.action,
    required this.onPressed,
    required this.actionKey,
    this.badge,
    this.caption,
    this.originalPrice,
  });

  final Widget image;
  final String title;
  final String description;
  final String price;
  final String action;
  final VoidCallback onPressed;
  final Key actionKey;
  final String? badge;
  final String? caption;
  final String? originalPrice;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0xFFF3DAE3)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 92,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (badge != null)
                Positioned(
                  top: 6,
                  left: 6,
                  right: 6,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PinkoraBrand.berry,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PinkoraBrand.charcoal,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                price,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PinkoraBrand.berry,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              if (originalPrice != null)
                Text(
                  originalPrice!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PinkoraBrand.muted,
                    fontSize: 9,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PinkoraBrand.muted,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PinkoraBrand.muted,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: FilledButton(
                  key: actionKey,
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: PinkoraBrand.berry,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                    action,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
