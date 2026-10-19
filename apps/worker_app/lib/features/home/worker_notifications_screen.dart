import 'package:flutter/material.dart';
import 'worker_booking_data.dart';
import 'worker_demo_booking_store.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _border = Color(0xFFF0D6DF);
const _cream = Color(0xFFFFF9F7);

/// UI-only alerts synthesized from visible worker bookings. This is not a
/// server notification inbox, and none of the items have a delivery timestamp.
class WorkerNotificationsScreen extends StatefulWidget {
  const WorkerNotificationsScreen({super.key, required this.orders,
    this.onBookingTap, this.demoMode = true});

  final List<WorkerDashboardOrder> orders;
  final ValueChanged<WorkerDashboardOrder>? onBookingTap;
  final bool demoMode;

  @override
  State<WorkerNotificationsScreen> createState() => _WorkerNotificationsScreenState();
}

class _WorkerNotificationsScreenState extends State<WorkerNotificationsScreen> {
  String _filter = 'All';
  final Set<String> _readIds = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.addListener(_onBookingsChanged);
    }
  }

  @override
  void dispose() {
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.removeListener(_onBookingsChanged);
    }
    super.dispose();
  }

  void _onBookingsChanged() {
    if (mounted) setState(() {});
  }

  List<_BookingAlert> get _alerts => (widget.demoMode &&
          WorkerDemoBookingStore.repository.isInitialized
      ? WorkerDemoBookingStore.resolveAll(widget.orders)
      : widget.orders)
      .map(_BookingAlert.fromOrder)
      .toList(growable: false);

  List<_BookingAlert> get _visible => _alerts.where((item) {
        if (_filter == 'Unread') return !_readIds.contains(item.id);
        if (_filter == 'Bookings') return item.group == 'Bookings';
        if (_filter == 'Updates') return item.group == 'Updates';
        return true;
      }).toList(growable: false);

  void _open(_BookingAlert alert) {
    setState(() => _readIds.add(alert.id));
    if (widget.onBookingTap != null) {
      widget.onBookingTap!(alert.order);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Booking details are not connected for this preview.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _alerts;
    final unread = alerts.where((a) => !_readIds.contains(a.id)).length;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream, surfaceTintColor: Colors.transparent,
        title: const Text('Notifications', style: TextStyle(color: _deep,
            fontSize: 18, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: unread == 0 ? null : () => setState(() {
              _readIds.addAll(alerts.map((a) => a.id));
            }),
            child: const Text('Mark all read', style: TextStyle(
                color: _pink, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
          if (widget.demoMode) Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: const Color(0xFFFFEDF3),
                borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 17, color: _pink),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Preview alerts from existing bookings. No push notifications or server inbox are connected.',
                style: TextStyle(fontSize: 11, color: _deep))),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Your activity', style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800, color: _deep)),
            const Spacer(),
            Text('$unread unread', style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: _pink)),
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: ['All', 'Unread', 'Bookings', 'Updates'].map((filter) {
              final active = _filter == filter;
              return Padding(padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: Text(filter), selected: active,
                  selectedColor: _pink, backgroundColor: Colors.white,
                  side: BorderSide(color: active ? _pink : _border),
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: active ? Colors.white : _muted),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 12),
          if (_visible.isEmpty)
            Container(padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 18),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
              child: Column(children: [
                const Icon(Icons.notifications_none_rounded, size: 44, color: _pink),
                const SizedBox(height: 9),
                const Text('No notifications here', style: TextStyle(
                    fontWeight: FontWeight.w800, color: _deep)),
                const SizedBox(height: 5),
                Text(_filter == 'Unread' ? 'All visible alerts are marked as read.'
                    : 'Booking updates will appear here when available.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: _muted)),
              ]),
            )
          else
            ..._visible.map((alert) => Padding(
              key: ValueKey('alert-${alert.id}'),
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(color: Colors.white, borderRadius: BorderRadius.circular(15),
                child: InkWell(borderRadius: BorderRadius.circular(15),
                  onTap: () => _open(alert),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(15)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 39, height: 39,
                        decoration: BoxDecoration(color: const Color(0xFFFFEDF3),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(alert.icon, color: _pink, size: 21)),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(alert.title,
                                style: const TextStyle(color: _deep, fontSize: 13,
                                    fontWeight: FontWeight.w800))),
                            if (!_readIds.contains(alert.id)) Container(
                              width: 7, height: 7,
                              decoration: const BoxDecoration(
                                  color: _pink, shape: BoxShape.circle)),
                          ]),
                          const SizedBox(height: 4),
                          Text(alert.message, style: const TextStyle(
                              fontSize: 12, color: _muted, height: 1.35)),
                          const SizedBox(height: 7),
                          Text('Booking ${alert.order.id}  ·  ${alert.group}',
                            style: const TextStyle(fontSize: 10,
                                color: _pink, fontWeight: FontWeight.w700)),
                        ],
                      )),
                      const SizedBox(width: 5),
                      const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
                    ]),
                  ),
                ),
              ),
            )),
        ]),
      ))),
    );
  }
}

class _BookingAlert {
  const _BookingAlert({required this.order, required this.title,
    required this.message, required this.group, required this.icon});
  final WorkerDashboardOrder order;
  final String title;
  final String message;
  final String group;
  final IconData icon;
  String get id => '${order.id}:${order.status}';

  factory _BookingAlert.fromOrder(WorkerDashboardOrder order) {
    final status = order.status.trim().toLowerCase();
    if (status == 'completed' || status == 'demo completed') {
      return _BookingAlert(order: order, title: 'Service completed',
        message: '${order.service} for ${order.customer} is marked completed.',
        group: 'Updates', icon: Icons.task_alt_rounded);
    }
    if (status == 'cancelled' || status == 'canceled' || status == 'rejected') {
      return _BookingAlert(order: order, title: 'Booking cancelled',
        message: '${order.service} for ${order.customer} is marked $status.',
        group: 'Updates', icon: Icons.event_busy_rounded);
    }
    if (status == 'in progress' || status == 'ongoing' || status == 'payment pending') {
      return _BookingAlert(order: order,
        title: status == 'payment pending' ? 'Payment pending' : 'Service in progress',
        message: '${order.service} for ${order.customer} · ${order.time}.',
        group: 'Updates', icon: Icons.access_time_rounded);
    }
    return _BookingAlert(order: order, title: 'Booking ${order.status}',
      message: '${order.service} for ${order.customer} · ${order.time}.',
      group: 'Bookings', icon: Icons.calendar_today_rounded);
  }
}
