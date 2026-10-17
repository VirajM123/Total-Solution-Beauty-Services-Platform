import 'dart:async';
import 'package:flutter/material.dart';
import 'worker_booking_data.dart';
import 'worker_rejection_reason_screen.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

enum WorkerOfferDecisionType { accepted, rejected, expired }

class WorkerOfferDecision {
  const WorkerOfferDecision(this.type, {this.rejection});
  final WorkerOfferDecisionType type;
  final WorkerRejectionReason? rejection;
}

/// UI-only local offer preview; no push notification, ringtone, server accept or penalty.
/// The production server must own the deadline and atomically allocate offers.
class WorkerIncomingBookingScreen extends StatefulWidget {
  const WorkerIncomingBookingScreen({
    super.key,
    required this.order,
    this.ongoingService = false,
    this.travelEstimate,
    this.expiresAfter = const Duration(seconds: 60),
  });
  final WorkerDashboardOrder order;
  final bool ongoingService;
  /// Nullable until provided by a real routing / ETA service.
  final String? travelEstimate;
  final Duration expiresAfter;
  @override
  State<WorkerIncomingBookingScreen> createState() => _WorkerIncomingBookingScreenState();
}

class _WorkerIncomingBookingScreenState extends State<WorkerIncomingBookingScreen> {
  Timer? _ticker;
  late final DateTime _deadline;
  late int _secondsRemaining;
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(widget.expiresAfter);
    _secondsRemaining = widget.expiresAfter.inSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _deadline.difference(DateTime.now()).inSeconds + 1;
      if (remaining <= 0) {
        _finish(const WorkerOfferDecision(WorkerOfferDecisionType.expired));
      } else {
        setState(() => _secondsRemaining = remaining);
      }
    });
  }

  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }

  void _finish(WorkerOfferDecision result) {
    if (_deciding || !mounted) return;
    _ticker?.cancel();
    Navigator.of(context).pop(result);
  }

  void _accept() {
    if (_secondsRemaining <= 0) return;
    _finish(const WorkerOfferDecision(WorkerOfferDecisionType.accepted));
  }

  Future<void> _reject() async {
    if (_deciding || _secondsRemaining <= 0) return;
    setState(() => _deciding = true);
    final result = await Navigator.of(context).push<WorkerRejectionReason>(
      MaterialPageRoute(builder: (_) => const WorkerRejectionReasonScreen()),
    );
    if (!mounted) return;
    setState(() => _deciding = false);
    if (_deadline.isBefore(DateTime.now())) {
      _finish(const WorkerOfferDecision(WorkerOfferDecisionType.expired));
    } else if (result != null) {
      _finish(WorkerOfferDecision(WorkerOfferDecisionType.rejected, rejection: result));
    }
  }

  Widget _item(IconData icon, String label, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _pink, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(text, style: const TextStyle(color: _deep, fontWeight: FontWeight.w700)),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_deciding) _reject();
    },
    child: Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(backgroundColor: _cream, foregroundColor: _deep,
        automaticallyImplyLeading: false,
        title: const Text('New Booking Request', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(tooltip: 'Reject with reason', onPressed: _deciding ? null : _reject,
          icon: const Icon(Icons.close_rounded))]),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 22), children: [
            Container(padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: const Color(0xFFFFE8F0), borderRadius: BorderRadius.circular(14)),
              child: const Text('DEVELOPMENT PREVIEW ONLY · No real order is offered or accepted. No notification sound or backend request.',
                style: TextStyle(color: _deep, fontSize: 11, height: 1.45))),
            const SizedBox(height: 17),
            Row(children: [
              Expanded(child: Text('Booking ${widget.order.id}',
                style: const TextStyle(color: _deep, fontWeight: FontWeight.w800, fontSize: 16))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(20)),
                child: Text('${_secondsRemaining}s left', style: const TextStyle(color: _pink, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 15),
            Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white,
              border: Border.all(color: _border), borderRadius: BorderRadius.circular(19)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 65, height: 65, decoration: BoxDecoration(color: const Color(0xFFFFE9F0),
                    borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.spa_outlined, color: _pink, size: 30)),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.order.service, style: const TextStyle(color: _deep, fontWeight: FontWeight.w800, fontSize: 19)),
                    Text(widget.order.duration, style: const TextStyle(color: _muted, fontSize: 12)),
                  ])),
                  Text(formatCustomerRupees(widget.order.customerPayable), style: const TextStyle(color: _deep, fontWeight: FontWeight.w800, fontSize: 17)),
                ]),
                const SizedBox(height: 6),
                const Text('Customer payable · not worker payout', style: TextStyle(color: _muted, fontSize: 11)),
                const Divider(height: 28, color: _border),
                _item(Icons.person_outline, 'Customer', widget.order.customer),
                _item(Icons.schedule_outlined, 'Appointment', widget.order.time),
                _item(Icons.place_outlined, 'Customer area', widget.order.location),
                _item(Icons.route_outlined, 'Estimated travel', widget.travelEstimate ?? 'ETA not calculated yet'),
              ])),
            const SizedBox(height: 17),
            if (widget.ongoingService)
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
                color: const Color(0xFFFFF1DC), borderRadius: BorderRadius.circular(14)),
                child: const Row(children: [Icon(Icons.info_outline, color: Color(0xFFAC6716)),
                  SizedBox(width: 9), Expanded(child: Text('You are currently performing a service. A future booking should only be offered if the schedule and travel time are feasible.',
                    style: TextStyle(color: _deep, fontSize: 12, height: 1.4)))])),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 17), child: Row(children: [
            Expanded(child: SizedBox(height: 52, child: OutlinedButton(
              onPressed: _deciding ? null : _reject,
              style: OutlinedButton.styleFrom(foregroundColor: _pink, side: const BorderSide(color: _pink)),
              child: const Text('Reject')))),
            const SizedBox(width: 12),
            Expanded(child: SizedBox(height: 52, child: FilledButton(
              onPressed: _deciding ? null : _accept,
              style: FilledButton.styleFrom(backgroundColor: _pink, foregroundColor: Colors.white),
              child: const Text('Accept')))),
          ])),
        ]),
      ))),
    ),
  );
}
