import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/slide_page_route.dart';
import 'worker_booking_data.dart';
import 'worker_booking_session.dart';
import 'worker_demo_booking_store.dart';
import 'worker_booking_state_repository.dart';
import 'worker_start_service_otp_screen.dart';
import 'worker_service_in_progress_screen.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

/// Booking details, with a DEBUG-ONLY start-service OTP preview.
/// Neither verification nor booking status is updated on a backend.
class WorkerBookingDetailsScreen extends StatefulWidget {
  const WorkerBookingDetailsScreen({
    super.key,
    required this.order,
    this.demoMode = true,
  });

  final WorkerDashboardOrder order;
  final bool demoMode;

  @override
  State<WorkerBookingDetailsScreen> createState() =>
      _WorkerBookingDetailsScreenState();
}

class _WorkerBookingDetailsScreenState
    extends State<WorkerBookingDetailsScreen> {
  bool _startingService = false;
  bool _storeLoading = true;
  Object? _storeError;

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.addListener(_onStoreUpdated);
      _loadStore();
    } else { _storeLoading = false; }
  }

  Future<void> _loadStore() async {
    try {
      await WorkerDemoBookingStore.initialize();
      if (mounted) setState(() { _storeLoading = false; _storeError = null; });
    } catch (error) {
      if (mounted) setState(() { _storeLoading = false; _storeError = error; });
    }
  }

  void _onStoreUpdated() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    if (widget.demoMode) WorkerDemoBookingStore.repository.removeListener(_onStoreUpdated);
    super.dispose();
  }

  WorkerBookingSession? get _savedSession => widget.demoMode && !_storeLoading && _storeError == null
      ? WorkerDemoBookingStore.session(widget.order.id) : null;

  WorkerDashboardOrder get _currentOrder => widget.demoMode && !_storeLoading && _storeError == null
      ? WorkerDemoBookingStore.resolve(widget.order) : widget.order;

  bool get _previewAllowed => kDebugMode && widget.demoMode;

  bool get _canStartPreview {
    final status = widget.order.status.toLowerCase().trim();
    return _previewAllowed &&
        !_storeLoading && _storeError == null &&
        _savedSession == null &&
        !_startingService &&
        <String>{'accepted', 'arrived', 'confirmed', 'assigned'}
            .contains(status);
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openProgressPreview() async {
    if (!_previewAllowed || _storeLoading || _storeError != null) return;
    final saved = _savedSession;
    if (saved == null ||
        saved.serviceStage != WorkerServiceStage.inProgress ||
        saved.startedAt == null) {
      _notice('No active demo service to resume.');
      return;
    }
    await Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerServiceInProgressScreen(
          order: _currentOrder,
          demoStartedAt: saved.startedAt!,
          demoMode: widget.demoMode,
        ),
      ),
    );
  }

  Future<void> _startServicePreview() async {
    if (!_canStartPreview) return;
    final verified = await Navigator.of(context).push<bool>(
      SlidePageRoute<bool>(
        page: WorkerStartServiceOtpScreen(
          order: widget.order,
          demoMode: widget.demoMode,
        ),
      ),
    );
    if (!mounted || verified != true || !_canStartPreview) return;
    setState(() => _startingService = true);
    try {
      // The OTP page only returns a debug preview result. Persist the guarded
      // start BEFORE opening progress, so a route pop cannot reset it.
      await WorkerDemoBookingStore.repository.startService(
        bookingId: widget.order.id,
        baseCustomerPayable: widget.order.customerPayable,
        otpVerifiedInPreview: true,
      );
      if (!mounted) return;
      await _openProgressPreview();
    } on WorkerBookingStateException catch (error) {
      if (mounted) _notice(error.message);
    } catch (_) {
      if (mounted) _notice('Could not save demo service start. Please retry.');
    } finally {
      if (mounted) setState(() => _startingService = false);
    }
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: child,
      );

  Widget _info(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: _pink),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: _muted, fontSize: 13, height: 1.3))),
        ]),
      );

  String _formatSavedTime(BuildContext context, DateTime? value) {
    if (value == null) return 'Not recorded';
    final local = value.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
    return '$date · ${TimeOfDay.fromDateTime(local).format(context)}';
  }

  Widget _billRow(String label, int amount, {bool total = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
          color: total ? _deep : _muted,
          fontSize: total ? 14 : 12.5,
          fontWeight: total ? FontWeight.w800 : FontWeight.w500))),
      const SizedBox(width: 8),
      Text(formatCustomerRupees(amount), style: TextStyle(
          color: total ? _pink : _deep,
          fontSize: total ? 17 : 13,
          fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _savedServiceSummary(BuildContext context, WorkerBookingSession session) {
    final isFinished = session.serviceStage == WorkerServiceStage.finished;
    final demoPaid = session.demoPaidAt != null;
    return Column(children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isFinished ? Icons.task_alt_rounded : Icons.timelapse_rounded,
              color: isFinished ? const Color(0xFF12875A) : _pink, size: 23),
          const SizedBox(width: 9),
          Expanded(child: Text(isFinished ? 'Service History · Demo'
              : 'Saved Service Session · Demo',
              style: const TextStyle(color: _deep, fontSize: 15,
                  fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 13),
        _info(Icons.play_circle_outline_rounded,
            'Started: ${_formatSavedTime(context, session.startedAt)}'),
        _info(Icons.flag_outlined,
            'Finished: ${_formatSavedTime(context, session.finishedAt)}'),
        _info(Icons.credit_card_outlined,
            demoPaid ? 'Payment simulation: ${_formatSavedTime(context, session.demoPaidAt)}'
                : isFinished ? 'Payment pending · No request sent'
                    : 'Payment not requested'),
        const Divider(color: _border),
        Row(children: [
          Icon(demoPaid ? Icons.check_circle_outline : Icons.info_outline,
              size: 18, color: demoPaid ? const Color(0xFF12875A) : _pink),
          const SizedBox(width: 8),
          Expanded(child: Text(demoPaid
              ? 'Demo payment completed · NOT VERIFIED'
              : isFinished ? 'Service finished · Payment pending'
                  : 'Service in progress',
              style: const TextStyle(color: _deep, fontSize: 12.5,
                  fontWeight: FontWeight.w700))),
        ]),
      ])),
      const SizedBox(height: 14),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Saved Customer Bill · Preview',
            style: TextStyle(color: _deep, fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        _billRow('Original service', session.baseCustomerPayable),
        if (session.extras.isNotEmpty) ...[
          const Divider(color: _border),
          const Text('Selected extra services · demo only',
              style: TextStyle(color: _muted, fontSize: 11)),
          for (final extra in session.extras)
            _billRow('${extra.name} (${extra.approval.name})',
                extra.approval == WorkerExtraApprovalStage.rejected
                    ? 0 : extra.customerPrice),
        ],
        const Divider(color: _border),
        _billRow('Total customer payable', session.demoCustomerTotal,
            total: true),
        const SizedBox(height: 8),
        const Text('Amounts and extra-service approvals are local previews. '
            'No customer approval, payment receipt or backend verification is implied.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.45)),
      ])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder;
    final canStart = _canStartPreview;
    final session = _savedSession;
    final canResume = _previewAllowed &&
        session?.serviceStage == WorkerServiceStage.inProgress &&
        session?.startedAt != null;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        foregroundColor: _deep,
        centerTitle: true,
        title: const Text('Booking Details',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: widget.demoMode && (_storeLoading || _storeError != null)
          ? SafeArea(child: Center(child: _storeLoading
              ? const CircularProgressIndicator(color: _pink)
              : Padding(padding: const EdgeInsets.all(24), child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load saved booking status.'),
                    Text('$_storeError', textAlign: TextAlign.center),
                    TextButton(onPressed: () {setState(() {_storeLoading = true; _storeError = null;}); _loadStore();},
                        child: const Text('Retry loading')),
                  ],
                ))))
          : SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(17, 10, 17, 24),
                  children: [
                    if (widget.demoMode)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                          'DEVELOPMENT PREVIEW · No live service actions',
                          style: TextStyle(fontSize: 10, color: _muted),
                        ),
                      ),
                    _card(Row(children: [
                      CircleAvatar(
                        radius: 27,
                        backgroundColor: const Color(0xFFFFE2EC),
                        child: Text(
                          order.customer.isNotEmpty ? order.customer[0] : 'C',
                          style: const TextStyle(
                              color: _pink,
                              fontSize: 23,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.customer,
                                style: const TextStyle(
                                    color: _deep,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('Booking ${order.id}',
                                style: const TextStyle(
                                    color: _muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified_user_outlined, color: _pink),
                    ])),
                    const SizedBox(height: 14),
                    _card(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8EF),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(Icons.spa_rounded,
                                color: _pink, size: 32),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order.service,
                                    style: const TextStyle(
                                        color: _deep,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(order.status,
                                    style: const TextStyle(
                                        color: _pink,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Text(formatCustomerRupees(order.customerPayable),
                              style: const TextStyle(
                                  color: _deep,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 13),
                        const Divider(color: _border),
                        const SizedBox(height: 12),
                        _info(Icons.access_time_rounded,
                            '${order.time} · ${order.duration}'),
                        _info(Icons.place_outlined, order.location),
                        _info(Icons.payments_outlined,
                            'Customer payable: ${formatCustomerRupees(order.customerPayable)}'),
                      ],
                    )),
                    const SizedBox(height: 14),
                    _card(const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Service Details',
                            style: TextStyle(
                                color: _deep,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 8),
                        Text(
                          'The full service description will be shown once booking details are available from the backend.',
                          style: TextStyle(
                              color: _muted, fontSize: 12.5, height: 1.5),
                        ),
                        SizedBox(height: 18),
                        Text('Customer Note',
                            style: TextStyle(
                                color: _deep,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 8),
                        Text('No customer note available in this preview.',
                            style: TextStyle(color: _muted, fontSize: 12.5)),
                      ],
                    )),
                    if (session != null) ...[
                      const SizedBox(height: 14),
                      _savedServiceSummary(context, session),
                    ],
                    const SizedBox(height: 14),
                    _card(Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          session != null
                              ? Icons.check_circle_outline
                              : Icons.lock_outline_rounded,
                          color: _pink,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            canResume
                                ? 'Demo service start is saved locally. Resume the service with its original start time. No backend booking was changed.'
                                : session != null
                                    ? 'This demo service was already started. It cannot be started again, even after reopening the booking.'
                                    : 'Start-service OTP can be previewed only for eligible accepted bookings. Real verification, service completion and payments require backend integration.',
                            style: const TextStyle(
                                color: _muted, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    )),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 10, 17, 15),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    key: const Key('start-service-entry'),
                    onPressed: session?.serviceStage == WorkerServiceStage.finished
                        ? () => Navigator.of(context).maybePop()
                        : _startingService
                        ? null
                        : canResume
                            ? _openProgressPreview
                            : canStart ? _startServicePreview : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _pink,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFF5CBD9),
                      disabledForegroundColor: _deep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      session?.serviceStage == WorkerServiceStage.finished
                          ? 'Back to My Bookings'
                          : _startingService
                          ? 'Saving Demo Service…'
                          : canResume
                              ? 'Resume Demo Service'
                              : canStart
                                  ? 'Start Service · Enter Customer OTP'
                                  : 'Start Service Not Available',
                    ),
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
