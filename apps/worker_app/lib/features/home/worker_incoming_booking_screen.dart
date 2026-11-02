import '../widgets/worker_reference_widgets.dart';
import '../widgets/worker_images.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'worker_booking_data.dart';
import 'worker_rejection_reason_screen.dart';

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
    this.distanceKm,
    this.expiresAfter = const Duration(seconds: 60),
    this.isLiveOffer = false,
  });
  final WorkerDashboardOrder order;
  final bool ongoingService;

  /// Nullable until provided by a real routing / ETA service.
  final String? travelEstimate;
  final String? distanceKm;
  final Duration expiresAfter;
  final bool isLiveOffer;
  @override
  State<WorkerIncomingBookingScreen> createState() =>
      _WorkerIncomingBookingScreenState();
}

class _WorkerIncomingBookingScreenState
    extends State<WorkerIncomingBookingScreen> {
  Timer? _ticker;
  late final DateTime _deadline;
  late int _secondsRemaining;
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(widget.expiresAfter);
    _secondsRemaining = widget.expiresAfter.inSeconds;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _deadline.difference(DateTime.now()).inSeconds + 1;
      if (remaining <= 0) {
        _finish(const WorkerOfferDecision(WorkerOfferDecisionType.expired));
      } else {
        setState(() => _secondsRemaining = remaining);
        if (remaining % 4 == 0) {
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.heavyImpact();
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

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
      _finish(
        WorkerOfferDecision(
          WorkerOfferDecisionType.rejected,
          rejection: result,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_deciding) _reject();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                WorkerReferenceHeader(location: widget.order.location),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: workerReferenceSurface(tinted: true),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFFE0ED),
                                  ),
                                  child: const Icon(
                                    Icons.bolt,
                                    color: workerPink,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'New Booking Request',
                                        style: TextStyle(
                                          color: workerInk,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Respond before the timer ends',
                                        style: TextStyle(
                                          color: workerMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox.square(
                                  dimension: 66,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox.expand(
                                        child: CircularProgressIndicator(
                                          value:
                                              widget.expiresAfter.inSeconds <= 0
                                              ? 0
                                              : (_secondsRemaining /
                                                        widget
                                                            .expiresAfter
                                                            .inSeconds)
                                                    .clamp(0.0, 1.0),
                                          strokeWidth: 5,
                                          strokeCap: StrokeCap.round,
                                          color: workerPink,
                                          backgroundColor: const Color(
                                            0xFFFFC7DD,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          fontSize: 19,
                                          color: workerPink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: workerReferenceSurface(),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  WorkerProfilePhoto(
                                    path: widget.order.customerPhotoUrl,
                                    size: MediaQuery.sizeOf(context).width < 350
                                        ? 74
                                        : 104,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.order.customer,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            height: 1.2,
                                            fontWeight: FontWeight.w800,
                                            color: workerInk,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (widget.order.appointmentDate !=
                                            null)
                                          WorkerReferenceLine(
                                            icon: Icons.calendar_month_outlined,
                                            text:
                                                MaterialLocalizations.of(
                                                  context,
                                                ).formatMediumDate(
                                                  widget.order.appointmentDate!
                                                      .toLocal(),
                                                ),
                                          ),
                                        WorkerReferenceLine(
                                          icon: Icons.access_time,
                                          text: widget.order.time,
                                        ),
                                        WorkerReferenceLine(
                                          icon: Icons.location_on_outlined,
                                          text: widget.order.location.isEmpty
                                              ? 'Service area unavailable'
                                              : widget.order.location,
                                        ),
                                        if (widget.distanceKm != null &&
                                            widget.distanceKm !=
                                                'Distance unavailable')
                                          WorkerReferenceLine(
                                            icon: Icons.near_me_outlined,
                                            text: widget.distanceKm!,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: workerReferenceSurface(tinted: true),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WorkerServiceImage(
                              service: widget.order.service,
                              serviceId: widget.order.serviceId,
                              imageUrl: widget.order.serviceImageUrl,
                              demoMode: !widget.isLiveOffer,
                              width: MediaQuery.sizeOf(context).width < 350
                                  ? 90
                                  : 126,
                              height: 132,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.order.service,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color: workerInk,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  WorkerReferenceLine(
                                    icon: Icons.access_time,
                                    text: widget.order.duration,
                                  ),
                                  WorkerReferenceLine(
                                    icon: Icons.currency_rupee,
                                    text: widget.order.formattedCustomerPayable
                                        .replaceFirst('\u20b9', ''),
                                    strong: true,
                                  ),
                                  const Text(
                                    'Customer payable',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: workerMuted,
                                    ),
                                  ),
                                  if (widget
                                          .order
                                          .itemsDescription
                                          ?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.order.itemsDescription!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: workerMuted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: workerReferenceSurface(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: workerPink,
                              size: 25,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Customer Note',
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: workerInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F7),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      widget.order.customerNote
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? widget.order.customerNote!
                                          : 'No special instructions provided.',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.55,
                                        color: workerMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'Complete customer address and phone number unlocked on Accept',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: workerMuted,
                          ),
                        ),
                      ),
                      if (widget.ongoingService)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: workerReferenceSurface(tinted: true),
                            child: const Text(
                              'You are currently performing a service. A future booking should only be offered if the schedule and travel time are feasible.',
                              style: TextStyle(
                                fontSize: 12,
                                color: workerInk,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Order #${widget.order.id}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: workerMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _deciding ? null : _reject,
                          icon: const Icon(Icons.close, size: 23),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: workerPink,
                            minimumSize: const Size.fromHeight(54),
                            side: const BorderSide(color: workerPink),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _deciding ? null : _accept,
                          icon: const Icon(Icons.check, size: 23),
                          label: const Text(
                            'Accept Booking',
                            textAlign: TextAlign.center,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: workerPink,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
