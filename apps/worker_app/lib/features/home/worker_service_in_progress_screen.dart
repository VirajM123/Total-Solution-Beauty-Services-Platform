import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'worker_booking_data.dart';
import 'worker_booking_session.dart';
import 'worker_booking_state_repository.dart';
import 'worker_demo_booking_store.dart';
import 'worker_extra_service_item.dart';
import 'worker_add_extra_service_screen.dart';
import 'worker_finish_service_screen.dart';
import '../../app/slide_page_route.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

/// Development-only service-workspace preview.
/// Does not alter bookings, approve extras, or complete services remotely.
class WorkerServiceInProgressScreen extends StatefulWidget {
  const WorkerServiceInProgressScreen({
    super.key,
    required this.order,
    required this.demoStartedAt,
    this.demoMode = true,
  });

  final WorkerDashboardOrder order;
  final DateTime demoStartedAt;
  final bool demoMode;

  @override
  State<WorkerServiceInProgressScreen> createState() =>
      _WorkerServiceInProgressScreenState();
}

class _WorkerServiceInProgressScreenState
    extends State<WorkerServiceInProgressScreen> {
  Timer? _ticker;
  bool _busy = false;
  Duration _elapsed = Duration.zero;
  List<WorkerExtraServiceItem> _extras = const <WorkerExtraServiceItem>[];

  int get _extrasTotal => _extras.fold<int>(0, (sum, item) => sum + item.customerPrice);

  Future<void> _openExtraServices() async {
    if (!_previewAllowed || _busy) return;
    final updated = await Navigator.of(context).push<List<WorkerExtraServiceItem>>(
      SlidePageRoute<List<WorkerExtraServiceItem>>(
        page: WorkerAddExtraServiceScreen(
          order: widget.order,
          initialExtras: _extras,
          demoMode: widget.demoMode,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _busy = true);
    try {
      await WorkerDemoBookingStore.repository.updateExtras(
        bookingId: widget.order.id,
        extras: updated.map((e) => WorkerExtraSnapshot(
          id: e.id, name: e.name, customerPrice: e.customerPrice,
          durationMinutes: e.durationMinutes,
        )).toList(growable: false),
      );
      if (mounted) {
        setState(() => _extras = List.unmodifiable(updated));
        _notice('Demo extras saved locally · customer has not approved charges.');
      }
    } on WorkerBookingStateException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice('Unable to save extra services. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFinishServicePreview() async {
    if (!_previewAllowed || _busy) return;
    final session = WorkerDemoBookingStore.session(widget.order.id);
    if (session?.serviceStage != WorkerServiceStage.inProgress) {
      _notice('This service is no longer active. Reopen the booking to view its status.');
      return;
    }
    await Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerFinishServiceScreen(
          order: widget.order,
          extraServices: List.unmodifiable(_extras),
          demoStartedAt: widget.demoStartedAt,
          demoMode: widget.demoMode,
        ),
      ),
    );
  }

  bool get _previewAllowed => kDebugMode && widget.demoMode;

  @override
  void initState() {
    super.initState();
    final saved = WorkerDemoBookingStore.session(widget.order.id);
    if (saved != null) {
      _extras = List.unmodifiable(saved.extras.map((e) => WorkerExtraServiceItem(
        id: e.id, name: e.name, customerPrice: e.customerPrice,
        durationMinutes: e.durationMinutes,
      )));
    }
    _updateElapsed();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
  }

  void _updateElapsed() {
    if (!mounted) return;
    final diff = DateTime.now().difference(widget.demoStartedAt);
    setState(() => _elapsed = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String get _elapsedText {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes.remainder(60);
    final seconds = _elapsed.inSeconds.remainder(60);
    return hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _card(Widget child, {Color color = Colors.white}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );

  Widget _milestone(IconData icon, String title, bool reached,
      {bool current = false}) => Expanded(
        child: Column(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: current
                ? _pink
                : reached
                    ? const Color(0xFFFFDAE8)
                    : const Color(0xFFF4EFF1),
            child: Icon(icon,
                size: 19,
                color: current
                    ? Colors.white
                    : reached
                        ? _pink
                        : _muted),
          ),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: current ? _pink : _deep,
                  fontSize: 10.5,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        foregroundColor: _deep,
        centerTitle: true,
        title: const Text('Service In Progress',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_outlined, color: _pink),
            tooltip: 'Help',
            onPressed: () => _notice('Help will be connected in a later step.'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(17, 8, 17, 22),
                  children: [
                    if (_previewAllowed) ...[
                      const Text(
                        'DEVELOPMENT PREVIEW · OTP simulated · No actual service started',
                        style: TextStyle(fontSize: 10, color: _muted),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _card(Row(children: [
                      CircleAvatar(
                        radius: 27,
                        backgroundColor: const Color(0xFFFFE2EC),
                        child: Text(
                          order.customer.isEmpty ? 'C' : order.customer[0],
                          style: const TextStyle(
                              color: _pink, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.customer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _deep,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('Booking ${order.id}',
                                  style: const TextStyle(
                                      color: _muted, fontSize: 11.5)),
                            ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFE4EE),
                              borderRadius: BorderRadius.circular(16)),
                          child: const Text('Demo In Progress',
                              style: TextStyle(
                                  color: _pink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5)),
                        ),
                        const SizedBox(height: 7),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.timer_outlined,
                              color: _muted, size: 15),
                          const SizedBox(width: 4),
                          Text(_elapsedText,
                              style: const TextStyle(
                                  color: _deep,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ]),
                    ]), color: const Color(0xFFFFF0F5)),
                    const SizedBox(height: 14),
                    _card(Row(children: [
                      _milestone(Icons.place_outlined, 'At customer', true),
                      _milestone(Icons.verified_user_outlined, 'Demo OTP', true),
                      _milestone(Icons.spa_outlined, 'In progress', true,
                          current: true),
                      _milestone(Icons.credit_card_outlined, 'Payment later', false),
                    ])),
                    const SizedBox(height: 14),
                    _card(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Expanded(
                              child: Text('Included Service',
                                  style: TextStyle(
                                      color: _deep,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                            ),
                            Text(order.duration,
                                style: const TextStyle(
                                    color: _muted, fontSize: 12)),
                          ]),
                          const SizedBox(height: 14),
                          Row(children: [
                            Container(
                              width: 66,
                              height: 67,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFFE4EE),
                                  borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.spa_rounded,
                                  color: _pink, size: 29),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(order.service,
                                  style: const TextStyle(
                                      color: _deep,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                            ),
                            Text(formatCustomerRupees(order.customerPayable),
                                style: const TextStyle(
                                    color: _deep,
                                    fontWeight: FontWeight.w800)),
                          ]),
                          const SizedBox(height: 9),
                          const Text('Amount shown is customer payable, not worker payout.',
                              style: TextStyle(color: _muted, fontSize: 11)),
                        ])),
                    const SizedBox(height: 14),
                    _card(const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer Note',
                              style: TextStyle(
                                  color: _deep,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 7),
                          Text('No customer note is available in the current booking model.',
                              style: TextStyle(color: _muted, fontSize: 12.5)),
                        ])),
                    const SizedBox(height: 14),
                    _card(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Manage Extra Services',
                              style: TextStyle(
                                  color: _deep,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text(
                            'Select extra services for this preview. Real customer approval must happen in the customer app.',
                            style: TextStyle(color: _muted, fontSize: 12.5),
                          ),
                          if (_extras.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            for (final extra in _extras)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(children: [
                                  Expanded(child: Text(extra.name,
                                      style: const TextStyle(color: _deep,
                                          fontSize: 12.5, fontWeight: FontWeight.w600))),
                                  Text(formatCustomerRupees(extra.customerPrice),
                                      style: const TextStyle(color: _deep,
                                          fontWeight: FontWeight.w700, fontSize: 12.5)),
                                ]),
                              ),
                          ],
                          const SizedBox(height: 10),
                          Row(children: [
                            const Expanded(child: Text('Extra amount (demo)',
                                style: TextStyle(color: _muted, fontSize: 12))),
                            Text(formatCustomerRupees(_extrasTotal),
                                style: const TextStyle(color: _deep,
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                          ]),
                          const SizedBox(height: 7),
                          Row(children: [
                            const Expanded(child: Text('Preview customer payable',
                                style: TextStyle(color: _deep, fontWeight: FontWeight.w800,
                                    fontSize: 12.5))),
                            Text(formatCustomerRupees(order.customerPayable + _extrasTotal),
                                style: const TextStyle(color: _pink,
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                        ]),
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Text('Not actually approved or added to a real booking.',
                                style: TextStyle(color: _muted, fontSize: 10.5)),
                          ),
                          const SizedBox(height: 13),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _previewAllowed
                                  ? _openExtraServices
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add Extra Service'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _pink,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                              ),
                            ),
                          ),
                        ]), color: const Color(0xFFFFF0F5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(17, 10, 17, 15),
                decoration: const BoxDecoration(
                    color: _cream, border: Border(top: BorderSide(color: _border))),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _previewAllowed
                        ? _openFinishServicePreview
                        : null,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Finish Service'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _pink,
                        side: const BorderSide(color: _pink),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
