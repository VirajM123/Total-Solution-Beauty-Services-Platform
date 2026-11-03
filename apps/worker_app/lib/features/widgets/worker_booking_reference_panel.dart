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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/dashboard/reference_route.png',
                fit: BoxFit.fill,
                semanticLabel: 'Illustrative map preview',
              ),
            ),
            Positioned(
              top: 8,
              left: 14,
              right: 14,
              child: SizedBox(
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const WorkerAuthBrand(subtitle: 'Worker App'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1AFF1678),
                              blurRadius: 16,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: onBack,
                          color: workerPink,
                          constraints: const BoxConstraints.tightFor(
                            width: 52,
                            height: 52,
                          ),
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFCFD),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1AFF1678),
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4CBD9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: workerReferenceSurface(radius: 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFE7F0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.directions_car_rounded,
                                  color: workerPink,
                                  size: 27,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      demoMode ? '8 min' : 'On the way',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 23,
                                        height: 1.05,
                                        fontWeight: FontWeight.w700,
                                        color: workerInk,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      demoMode
                                          ? '2.5 km'
                                          : 'To customer location',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: workerMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                constraints: const BoxConstraints(minWidth: 92),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F6),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Arriving at',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: workerPink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          size: 18,
                                          color: workerPink,
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            _arrivalDestination(order.location),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: workerPink,
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
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, color: Color(0xFFFFDFEB)),
                          ),
                          Row(
                            children: [
                              _CustomerPhoto(
                                order: order,
                                demoMode: demoMode,
                                size: 62,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.customer,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: workerInk,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 1),
                                          child: Icon(
                                            Icons.location_on_outlined,
                                            size: 18,
                                            color: workerMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            order.location.isEmpty
                                                ? 'Address unavailable'
                                                : order.location,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.25,
                                              color: workerMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 62,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F6),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: const Color(0xFFFFC7DC),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x12FF1678),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  tooltip: 'Call customer',
                                  onPressed: onContact,
                                  color: workerPink,
                                  icon: const Icon(
                                    Icons.call_rounded,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: onLocation,
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Open in Maps',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: workerPink,
                                    side: const BorderSide(color: workerPink),
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  key: const Key('start-service-entry'),
                                  onPressed: onArrived,
                                  icon: const Icon(
                                    Icons.navigation_rounded,
                                    size: 19,
                                  ),
                                  label: Text(
                                    busy ? 'Updating...' : 'I Have Arrived',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: workerPink,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
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
}

class WorkerArrivalReferenceView extends StatelessWidget {
  const WorkerArrivalReferenceView({
    super.key,
    required this.order,
    required this.onConfirm,
    required this.onContact,
    required this.onLocation,
    required this.busy,
  });

  final WorkerDashboardOrder order;
  final VoidCallback? onConfirm;
  final VoidCallback onContact;
  final VoidCallback onLocation;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final address = order.location.isEmpty
        ? 'Address unavailable'
        : order.location;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                children: [
                  Center(
                    child: WorkerAuthBrand(
                      subtitle: _arrivalDestination(order.location),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 164,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F6),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: -26,
                          top: 10,
                          child: _arrivalCircle(104),
                        ),
                        Positioned(
                          right: -18,
                          bottom: -34,
                          child: _arrivalCircle(132),
                        ),
                        Image.asset(
                          'assets/images/illustrations/worker_arrival_house.png',
                          height: 146,
                          fit: BoxFit.contain,
                        ),
                        const Positioned(
                          top: 10,
                          child: Icon(
                            Icons.location_on_rounded,
                            color: workerPink,
                            size: 37,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'You have arrived!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: workerInk,
                            letterSpacing: -.7,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: workerPink,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Please confirm you are at the customer’s location to start the service.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: workerMuted,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: workerReferenceSurface(
                      tinted: true,
                      radius: 20,
                    ),
                    child: Row(
                      children: [
                        _CustomerPhoto(
                          order: order,
                          demoMode: false,
                          size: 72,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: workerInk,
                                ),
                              ),
                              const SizedBox(height: 5),
                              _arrivalDetail(
                                Icons.call_outlined,
                                order.customerPhone?.isNotEmpty == true
                                    ? order.customerPhone!
                                    : 'Phone unavailable',
                              ),
                              const SizedBox(height: 4),
                              _arrivalDetail(
                                Icons.location_on_outlined,
                                address,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 112,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/dashboard/reference_map.png',
                            fit: BoxFit.cover,
                          ),
                          const Center(
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 40,
                              color: workerPink,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: OutlinedButton.icon(
                                onPressed: onLocation,
                                icon: const Icon(
                                  Icons.near_me_outlined,
                                  size: 16,
                                ),
                                label: const Text('Open in Maps'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: workerInk,
                                  minimumSize: const Size(0, 34),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const Key('confirm-customer-arrival'),
                    onPressed: onConfirm,
                    icon: busy
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.location_on_rounded),
                    label: Text(busy ? 'Please wait…' : 'Confirm Arrival'),
                    style: FilledButton.styleFrom(
                      backgroundColor: workerPink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call Customer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: workerPink,
                      side: const BorderSide(color: workerPink),
                      minimumSize: const Size.fromHeight(50),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _arrivalCircle(double size) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFFFFE2EE),
      shape: BoxShape.circle,
    ),
  );

  static Widget _arrivalDetail(
    IconData icon,
    String text, {
    int maxLines = 1,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 16, color: workerMuted),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            height: 1.25,
            color: workerMuted,
          ),
        ),
      ),
    ],
  );
}

String _arrivalDestination(String address) {
  const statesAndTerritories = {
    'andhra pradesh',
    'arunachal pradesh',
    'assam',
    'bihar',
    'chandigarh',
    'chhattisgarh',
    'dadra and nagar haveli and daman and diu',
    'delhi',
    'goa',
    'gujarat',
    'haryana',
    'himachal pradesh',
    'jammu and kashmir',
    'jharkhand',
    'karnataka',
    'kerala',
    'ladakh',
    'lakshadweep',
    'madhya pradesh',
    'maharashtra',
    'manipur',
    'meghalaya',
    'mizoram',
    'nagaland',
    'odisha',
    'puducherry',
    'punjab',
    'rajasthan',
    'sikkim',
    'tamil nadu',
    'telangana',
    'tripura',
    'uttar pradesh',
    'uttarakhand',
    'west bengal',
  };
  final parts = address
      .split(',')
      .map((part) => part.replaceAll(RegExp(r'\b\d{6}\b'), '').trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'Customer';
  final localityParts = parts
      .where((part) => !statesAndTerritories.contains(part.toLowerCase()))
      .toList();
  return localityParts.isEmpty ? parts.last : localityParts.last;
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
