import 'package:flutter/material.dart';
import 'worker_auth_visuals.dart';

const workerInk = Color(0xFF210B35);
const workerMuted = Color(0xFF686080);
const workerPink = Color(0xFFFF1678);

BoxDecoration workerReferenceSurface({
  bool tinted = false,
  double radius = 16,
}) => BoxDecoration(
  color: tinted ? null : Colors.white,
  gradient: tinted
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7FA), Color(0xFFFFE8F2)],
        )
      : null,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0xFFFFDFEB)),
  boxShadow: const [
    BoxShadow(color: Color(0x0DF52D7A), blurRadius: 12, offset: Offset(0, 4)),
  ],
);

class WorkerReferenceHeader extends StatelessWidget {
  const WorkerReferenceHeader({
    super.key,
    this.location,
    this.onNotifications,
    this.unread = 0,
    this.brandWidth = 190,
    this.brandAsset = 'assets/images/dashboard/reference_brand.png',
  });
  final String? location;
  final VoidCallback? onNotifications;
  final int unread;
  final double brandWidth;
  final String? brandAsset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: brandWidth,
              child: brandAsset != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          brandAsset!,
                          width: brandWidth,
                          fit: BoxFit.contain,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 70),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: workerMuted,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  location ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: workerMuted,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: workerMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : WorkerAuthBrand(
                      subtitle: location?.isNotEmpty == true
                          ? location!
                          : 'For Beauty Professionals',
                    ),
            ),
          ),
        ),
        if (onNotifications != null)
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications,
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              backgroundColor: workerPink,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: workerInk,
                size: 28,
              ),
            ),
          ),
      ],
    ),
  );
}

class WorkerReferenceLine extends StatelessWidget {
  const WorkerReferenceLine({
    super.key,
    required this.icon,
    required this.text,
    this.strong = false,
  });
  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: workerInk),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: strong ? workerInk : workerMuted,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
}

class WorkerReferenceNav extends StatelessWidget {
  const WorkerReferenceNav({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected == i
                        ? const Color(0xFFFFE8F2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        const [
                          Icons.home_outlined,
                          Icons.calendar_month_outlined,
                          Icons.bar_chart_rounded,
                          Icons.person_outline,
                        ][i],
                        color: selected == i ? workerPink : workerMuted,
                        size: 25,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        const ['Home', 'Bookings', 'Earnings', 'Profile'][i],
                        style: TextStyle(
                          fontSize: 10,
                          color: selected == i ? workerPink : workerMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
