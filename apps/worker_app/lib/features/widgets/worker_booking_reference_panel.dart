import 'package:flutter/material.dart';
import '../home/worker_booking_data.dart';
import 'worker_images.dart';
import 'worker_reference_widgets.dart';
import 'worker_auth_visuals.dart';

/// Presentation only: all booking transitions remain in the owning screen.
class WorkerBookingReferencePanel extends StatelessWidget {
  const WorkerBookingReferencePanel({
    super.key,
    required this.order,
    required this.demoMode,
    required this.onContact,
    required this.onLocation,
  });
  final WorkerDashboardOrder order;
  final bool demoMode;
  final VoidCallback onContact;
  final VoidCallback onLocation;

  Widget _surface(Widget child, {bool tinted = false}) => Container(
    padding: const EdgeInsets.all(11),
    decoration: workerReferenceSurface(tinted: tinted, radius: 15),
    child: child,
  );

  Widget _icon(IconData icon) => Container(
    width: 36,
    height: 36,
    decoration: const BoxDecoration(
      color: Color(0xFFFFEAF3),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: workerPink, size: 23),
  );

  @override
  Widget build(BuildContext context) {
    final date = order.appointmentDate?.toLocal();
    final dateLabel = date == null
        ? 'Date unavailable'
        : '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';
    final titleStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: workerInk,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Booking Details',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: workerInk,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE6F0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 17,
                    color: workerPink,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    order.status,
                    style: const TextStyle(fontSize: 11, color: workerPink),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const Text(
              'Booking ID  ',
              style: TextStyle(fontSize: 12, color: workerMuted),
            ),
            Flexible(
              child: Text(
                order.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: workerInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.content_paste_outlined,
              size: 16,
              color: workerMuted,
            ),
          ],
        ),
        const SizedBox(height: 13),
        _surface(
          Row(
            children: [
              _CustomerPhoto(order: order, demoMode: demoMode, size: 76),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customer,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: workerInk,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      order.customerPhone?.isNotEmpty == true
                          ? order.customerPhone!
                          : 'Phone unavailable',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: workerMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Customer contact',
                onPressed: onContact,
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 21,
                  color: workerPink,
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Call customer',
                onPressed: onContact,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD8E8),
                ),
                icon: const Icon(
                  Icons.call_rounded,
                  size: 23,
                  color: workerPink,
                ),
              ),
            ],
          ),
          tinted: true,
        ),
        const SizedBox(height: 10),
        _surface(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child:
                    demoMode && order.service.toLowerCase().contains('facial')
                    ? Image.asset(
                        'assets/images/dashboard/reference_facial.png',
                        width: 108,
                        height: 96,
                        fit: BoxFit.cover,
                      )
                    : WorkerServiceImage(
                        service: order.service,
                        serviceId: order.serviceId,
                        imageUrl: order.serviceImageUrl,
                        demoMode: demoMode,
                        width: 108,
                        height: 96,
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.service,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: workerInk,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 18,
                          color: workerInk,
                        ),
                        Text(
                          order.duration,
                          style: const TextStyle(
                            fontSize: 12,
                            color: workerInk,
                          ),
                        ),
                        Text(
                          '  ${order.formattedCustomerPayable}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: workerInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.itemsDescription?.isNotEmpty == true
                          ? order.itemsDescription!
                          : order.service,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: workerMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          tinted: true,
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _surface(
                Row(
                  children: [
                    _icon(Icons.calendar_month_rounded),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: workerInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: workerMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _surface(
                Row(
                  children: [
                    _icon(Icons.account_balance_wallet_rounded),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment on Service',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: workerInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.paymentMethod?.isNotEmpty == true
                                ? order.paymentMethod!
                                : 'Not specified',
                            style: const TextStyle(
                              fontSize: 11,
                              color: workerMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: workerPink,
                    size: 23,
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text('Customer Location', style: titleStyle)),
                  TextButton(
                    onPressed: onLocation,
                    style: TextButton.styleFrom(
                      foregroundColor: workerPink,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                    ),
                    child: const Text(
                      'Open in Maps',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.location.isEmpty
                          ? 'Address unavailable'
                          : order.location,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: workerMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/images/dashboard/reference_map.png',
                      width: 112,
                      height: 74,
                      fit: BoxFit.cover,
                      semanticLabel: 'Illustrative map preview',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _surface(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _icon(Icons.description_outlined),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer Note', style: titleStyle),
                    const SizedBox(height: 4),
                    Text(
                      order.customerNote?.trim().isNotEmpty == true
                          ? order.customerNote!
                          : 'No special requests noted for this appointment.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: workerMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (order.compensationRupees != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Worker Compensation: \u20b9${order.compensationRupees}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF14865E)),
            ),
          ),
      ],
    );
  }
}

class WorkerTravelReferenceView extends StatelessWidget {
  const WorkerTravelReferenceView({
    super.key,
    required this.order,
    required this.demoMode,
    required this.onBack,
    required this.onContact,
    required this.onLocation,
    required this.onArrived,
    required this.busy,
  });
  final WorkerDashboardOrder order;
  final bool demoMode;
  final VoidCallback onBack, onContact, onLocation;
  final VoidCallback? onArrived;
  final bool busy;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFFBFD),
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/dashboard/reference_route.png',
              fit: BoxFit.cover,
              semanticLabel: 'Illustrative map preview',
            ),
          ),
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton.filled(
                  onPressed: onBack,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: workerPink,
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                const Spacer(),
                const WorkerAuthBrand(subtitle: 'Worker App'),
                const Spacer(),
              ],
            ),
          ),
          if (!demoMode)
            const Positioned(
              top: 80,
              left: 20,
              child: Chip(label: Text('Map preview')),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBFD),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7D2E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: workerReferenceSurface(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFFFE5F0),
                              radius: 23,
                              child: Icon(
                                Icons.directions_car_rounded,
                                color: workerPink,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    demoMode ? '8 min' : 'On the way',
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700,
                                      color: workerInk,
                                    ),
                                  ),
                                  Text(
                                    demoMode
                                        ? '2.5 km'
                                        : 'To customer location',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: workerMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: workerReferenceSurface(tinted: true),
                              child: const Text(
                                'Arriving at\nCustomer',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: workerPink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 25, color: Color(0xFFFFDFEB)),
                        Row(
                          children: [
                            _CustomerPhoto(
                              order: order,
                              demoMode: demoMode,
                              size: 68,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.customer,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: workerInk,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    order.location,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: workerMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.outlined(
                              onPressed: onContact,
                              icon: const Icon(Icons.call, color: workerPink),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onLocation,
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text('Open in Maps'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: workerPink,
                                  side: const BorderSide(color: workerPink),
                                  minimumSize: const Size(0, 45),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: FilledButton.icon(
                                key: const Key('start-service-entry'),
                                onPressed: onArrived,
                                icon: const Icon(Icons.near_me, size: 18),
                                label: Text(
                                  busy ? 'Updating...' : 'I Have Arrived',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: workerPink,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 45),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CustomerPhoto extends StatelessWidget {
  const _CustomerPhoto({
    required this.order,
    required this.demoMode,
    required this.size,
  });
  final WorkerDashboardOrder order;
  final bool demoMode;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFFFCEE0)),
      boxShadow: const [BoxShadow(color: Color(0x15FF1678), blurRadius: 8)],
    ),
    child: demoMode && (order.customerPhotoUrl?.isEmpty ?? true)
        ? ClipOval(
            child: Image.asset(
              'assets/images/dashboard/reference_customer.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          )
        : WorkerProfilePhoto(path: order.customerPhotoUrl, size: size),
  );
}
