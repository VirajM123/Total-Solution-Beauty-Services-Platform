import 'professional_portrait.dart';
import 'package:flutter/material.dart';

import 'compact_booking_widgets.dart';

/// Booking presentation only. All profile values come from the booking response.
class AssignedProfessionalDetails extends StatelessWidget {
  const AssignedProfessionalDetails({
    super.key,
    required this.name,
    required this.worker,
    this.compact = false,
    this.onTap,
    this.onContact,
  });

  final String name;
  final Map worker;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onContact;

  @override
  Widget build(BuildContext context) {
    final rating = num.tryParse(
      '${worker['averageRating'] ?? worker['rating'] ?? ''}',
    );
    final count = worker['completedServices'] ?? worker['completedJobs'];
    final verified = worker['isVerified'] == true || worker['verified'] == true;
    final portrait = ProfessionalPortrait(
      worker: worker,
      size: compact ? 48 : 72,
    );
    final profile = Row(
      children: [
        portrait,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: compact ? 12 : 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      color: Color(0xFF1689FF),
                      size: 15,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${worker['specialization'] ?? worker['roleLabel'] ?? 'Beauty Expert'}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFB800),
                    size: 17,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      rating == null
                          ? 'Rating not available'
                          : '${rating.toStringAsFixed(1)}${count == null ? '' : '  ($count services)'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (compact) const Icon(Icons.chevron_right, size: 20),
      ],
    );
    if (compact) {
      return Material(
        color: Colors.white.withValues(alpha: .8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFF0DDE6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(padding: const EdgeInsets.all(9), child: profile),
        ),
      );
    }
    return Column(
      children: [
        profile,
        const SizedBox(height: 12),
        Row(
          children: [
            for (final entry in const [
              (Icons.call, 'Call', bookingPink),
              (Icons.chat, 'WhatsApp', Color(0xFF18B74B)),
              (Icons.sms_outlined, 'Message', Color(0xFF211C36)),
            ]) ...[
              if (entry.$2 != 'Call') const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onContact,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    side: const BorderSide(color: Color(0xFFEADDE5)),
                  ),
                  child: Column(
                    children: [
                      Icon(entry.$1, color: entry.$3, size: 20),
                      const SizedBox(height: 3),
                      Text(
                        entry.$2,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF211C36),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
