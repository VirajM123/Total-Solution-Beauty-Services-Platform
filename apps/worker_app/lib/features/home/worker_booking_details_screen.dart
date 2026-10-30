import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/slide_page_route.dart';
import '../../integration/worker_api.dart';
import '../../integration/worker_mobile_operations_api.dart';
import 'worker_booking_data.dart';
import 'worker_booking_session.dart';
import 'worker_demo_booking_store.dart';
import 'worker_booking_state_repository.dart';
import 'worker_start_service_otp_screen.dart';
import 'worker_service_in_progress_screen.dart';
import 'worker_add_extra_service_screen.dart';
import 'worker_payment_qr_screen.dart';
import '../widgets/worker_design.dart';

const _pink = WorkerDesign.pink;
const _deep = WorkerDesign.deep;
const _muted = WorkerDesign.muted;
const _cream = WorkerDesign.cream;
const _border = WorkerDesign.border;

/// Booking details, with a DEBUG-ONLY start-service OTP preview.
/// Neither verification nor booking status is updated on a backend.
class WorkerBookingDetailsScreen extends StatefulWidget {
  const WorkerBookingDetailsScreen({
    super.key,
    required this.order,
    this.demoMode = true,
    this.operationsApi,
  });

  final WorkerDashboardOrder order;
  final bool demoMode;
  final WorkerOperationsApi? operationsApi;

  @override
  State<WorkerBookingDetailsScreen> createState() =>
      _WorkerBookingDetailsScreenState();
}

class _WorkerBookingDetailsScreenState extends State<WorkerBookingDetailsScreen>
    with WidgetsBindingObserver {
  final _clock = ValueNotifier<DateTime>(DateTime.now());
  bool _appActive = true;
  bool _refreshing = false;
  String? _refreshError;
  DateTime? _lastRefresh;
  late final WorkerMobileOperationsApi _liveApi =
      widget.operationsApi is WorkerMobileOperationsApi
      ? widget.operationsApi as WorkerMobileOperationsApi
      : WorkerMobileOperationsApi();
  bool _startingService = false;
  bool _storeLoading = true;
  Object? _storeError;
  String? _localStatus;
  bool _updatingProgress = false;
  WorkerDashboardOrder? _liveOrder;
  Timer? _serverTimeTimer;

  bool get _isLiveMode =>
      (widget.operationsApi is WorkerMobileOperationsApi) ||
      widget.order.id.length >= 24;
  Timer? _serverSyncTimer;

  String _progressButtonText(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'assigned' || s == 'accepted') {
      return 'Start Travel to Customer 🚗';
    }
    if (s == 'travelling') return 'I Have Arrived at Location 📍';
    if (s == 'arrived') return 'Upload Product Photo & Enter Customer OTP';
    if (s == 'in_progress' || s == 'in progress') {
      if (_currentOrder.paymentMethod == 'cash') {
        if (_currentOrder.paymentStatus == 'paid') {
          return 'Enter Admin Completion OTP';
        }
        if (_currentOrder.serviceFinishedAt != null) {
          return _currentOrder.cashCollectionReportedAt == null
              ? 'Report Cash Collection'
              : 'Awaiting Admin Cash Reconciliation';
        }
        return 'Finish & Report Cash Collection';
      }
      if (_currentOrder.paymentStatus == 'paid') {
        return 'Enter Admin Completion OTP';
      }
      final extension = _currentOrder.durationExtension;
      if (extension != null &&
          <String>{'pending', 'approved'}.contains(extension['status']) &&
          extension['adminOtpVerifiedAt'] == null) {
        return 'Enter Admin Continuation OTP';
      }
      return 'Finish & Generate Payment QR';
    }
    if (s == 'payment pending') {
      if (_currentOrder.paymentMethod == 'cash' &&
          _currentOrder.paymentStatus != 'paid') {
        return _currentOrder.cashCollectionReportedAt == null
            ? 'Report Cash Collection'
            : 'Awaiting Admin Cash Reconciliation';
      }
      return 'View Payment QR';
    }
    if (s == 'completed') return 'Service Completed 🎉 (Back)';
    if (s == 'cancelled' || s == 'canceled') return 'Booking Cancelled (Back)';
    return 'Back to Bookings';
  }

  bool get _showPaymentChoices {
    final order = _currentOrder;
    final status = order.status.toLowerCase().trim();
    final extension = order.durationExtension;
    return _isLiveMode &&
        (status == 'in_progress' || status == 'in progress') &&
        order.paymentStatus != 'paid' &&
        order.serviceFinishedAt == null &&
        !(extension != null &&
            <String>{'pending', 'approved'}.contains(extension['status']) &&
            extension['adminOtpVerifiedAt'] == null);
  }

  bool _canAct(String status) {
    if (_updatingProgress) return false;
    final s = status.toLowerCase().trim();
    return <String>{
      'assigned',
      'accepted',
      'travelling',
      'arrived',
      'in_progress',
      'in progress',
      'payment pending',
    }.contains(s);
  }

  Future<void> _handleProgressAction() async {
    if (!_isLiveMode) {
      await _startServicePreview();
      return;
    }
    final api = _liveApi;
    final s = _currentOrder.status.toLowerCase().trim();
    final extension = _currentOrder.durationExtension;
    if ((s == 'in_progress' || s == 'in progress') &&
        extension != null &&
        <String>{'pending', 'approved'}.contains(extension['status']) &&
        extension['adminOtpVerifiedAt'] == null) {
      final otp = await _askForAdminOtp(
        title: 'Continue the service',
        message:
            'Call your administrator and enter the continuation OTP they issue.',
      );
      if (!mounted || otp == null) return;
      setState(() => _updatingProgress = true);
      try {
        await api.updateBookingProgress(
          bookingId: widget.order.id,
          action: 'continue',
          otp: otp,
        );
        final updated = await api.fetchBookingDetails(widget.order.id);
        if (mounted) {
          setState(() => _liveOrder = updated ?? _liveOrder);
          _startServerTimeRefresh();
          _notice('Administrator OTP verified. The service can continue.');
        }
      } catch (error) {
        if (mounted) _notice('Continuation OTP verification failed: $error');
      } finally {
        if (mounted) setState(() => _updatingProgress = false);
      }
      return;
    }

    if (s == 'payment pending' && _currentOrder.paymentMethod == 'cash') {
      if (_currentOrder.paymentStatus == 'paid') {
        await _completePaidCashService();
      } else if (_currentOrder.cashCollectionReportedAt == null) {
        await _completeCashService();
      } else {
        _notice('Cash report sent. Waiting for administrator reconciliation.');
      }
      return;
    }
    if (s == 'payment pending') {
      await _openPaymentQr();
      return;
    }
    if ((s == 'in_progress' || s == 'in progress') &&
        _currentOrder.paymentStatus == 'paid') {
      if (_currentOrder.paymentMethod == 'cash') {
        await _completePaidCashService();
      } else {
        await _openPaymentQr();
      }
      return;
    }
    if (s == 'assigned' || s == 'accepted') {
      setState(() => _updatingProgress = true);
      try {
        await api.updateBookingProgress(
          bookingId: widget.order.id,
          action: 'travel',
        );
        if (mounted) {
          setState(() => _localStatus = 'Travelling');
          _notice('🚗 Status: Travelling. Heading to customer location.');
        }
      } catch (e) {
        if (mounted) _notice('Failed to start travel: $e');
      } finally {
        if (mounted) setState(() => _updatingProgress = false);
      }
    } else if (s == 'travelling') {
      setState(() => _updatingProgress = true);
      try {
        await api.updateBookingProgress(
          bookingId: widget.order.id,
          action: 'arrive',
        );
        if (mounted) {
          setState(() => _localStatus = 'Arrived');
          _notice(
            '📍 Status: Arrived at doorstep. Please request customer OTP.',
          );
        }
      } catch (e) {
        if (mounted) _notice('Failed to confirm arrival: $e');
      } finally {
        if (mounted) setState(() => _updatingProgress = false);
      }
    } else if (s == 'arrived') {
      final startInput = await Navigator.of(context)
          .push<WorkerStartServiceInput?>(
            SlidePageRoute<WorkerStartServiceInput?>(
              page: WorkerStartServiceOtpScreen(
                order: _currentOrder,
                demoMode: false,
                operationsApi: api,
              ),
            ),
          );
      if (!mounted || startInput == null || startInput.otp.isEmpty) return;

      setState(() => _updatingProgress = true);
      try {
        await api.updateBookingProgress(
          bookingId: widget.order.id,
          action: 'start',
          otp: startInput.otp,
          evidenceIds: startInput.evidenceIds,
        );
        final updated = await api.fetchBookingDetails(widget.order.id);
        if (mounted) {
          setState(() {
            _localStatus = 'In Progress';
            _liveOrder = updated ?? _liveOrder;
          });
          _startServerTimeRefresh();
          _notice('🎉 Customer OTP verified! Service is now In Progress.');
        }
      } catch (e) {
        if (mounted) _notice('OTP verification failed: $e');
      } finally {
        if (mounted) setState(() => _updatingProgress = false);
      }
    } else if (s == 'in_progress' || s == 'in progress') {
      if (_currentOrder.paymentMethod == 'cash') {
        await _completeCashService();
      } else {
        await _openPaymentQr();
      }
    }
  }

  Future<String?> _askForAdminOtp({
    required String title,
    required String message,
  }) async {
    var code = '';
    final otp = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 14),
            TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => code = value,
              decoration: const InputDecoration(
                labelText: '6-digit administrator OTP',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (RegExp(r'^\d{6}$').hasMatch(code.trim())) {
                Navigator.pop(context, code.trim());
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    return otp;
  }

  Future<void> _completeCashService() async {
    final api = _liveApi;
    var referenceValue = '';
    final reference = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report cash collection'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => referenceValue = value,
          decoration: const InputDecoration(
            labelText: 'Cash receipt or collection reference',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = referenceValue.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || reference == null) return;
    setState(() => _updatingProgress = true);
    try {
      var booking = _currentOrder;
      if (booking.serviceFinishedAt == null) {
        await api.updateBookingProgress(
          bookingId: widget.order.id,
          action: 'finish',
        );
        booking = await api.fetchBookingDetails(widget.order.id) ?? booking;
        if (mounted) setState(() => _liveOrder = booking);
      }
      if (booking.cashCollectionReportedAt != null) {
        if (mounted) {
          _notice(
            'Cash report sent. Waiting for administrator reconciliation.',
          );
        }
        return;
      }
      final amountPaise =
          booking.customerPayablePaise ?? booking.customerPayable * 100;
      await api.reportCashCollection(
        bookingId: widget.order.id,
        amountPaise: amountPaise,
        reference: reference,
        idempotencyKey:
            'cash_${widget.order.id}_${DateTime.now().microsecondsSinceEpoch}',
      );
      final updated = await api.fetchBookingDetails(widget.order.id);
      if (mounted) {
        setState(() {
          _liveOrder = updated ?? booking;
          _localStatus = null;
        });
        _notice(
          'Cash collection reported. Waiting for administrator reconciliation.',
        );
      }
    } catch (error) {
      if (mounted) {
        final updated = await api.fetchBookingDetails(widget.order.id);
        if (mounted && updated != null) setState(() => _liveOrder = updated);
        if (mounted) _notice('Failed to report cash collection: $error');
      }
    } finally {
      if (mounted) setState(() => _updatingProgress = false);
    }
  }

  Future<void> _completePaidCashService() async {
    final otp = await _askForAdminOtp(
      title: 'Complete the service',
      message:
          'Payment is reconciled. Call your administrator and enter the service-completion OTP.',
    );
    if (!mounted || otp == null) return;
    final api = _liveApi;
    setState(() => _updatingProgress = true);
    try {
      await api.updateBookingProgress(
        bookingId: widget.order.id,
        action: 'complete',
        otp: otp,
      );
      final updated = await api.fetchBookingDetails(widget.order.id);
      if (mounted) {
        setState(() {
          _liveOrder = updated ?? _liveOrder;
          _localStatus = null;
        });
        _notice('Administrator OTP verified. Service completed.');
      }
    } catch (error) {
      if (mounted) {
        _notice('Service-completion OTP verification failed: $error');
      }
    } finally {
      if (mounted) setState(() => _updatingProgress = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.demoMode && widget.order.id.length < 24) {
      WorkerDemoBookingStore.repository.addListener(_onStoreUpdated);
      _loadStore();
    } else {
      _storeLoading = false;
    }
    if (_isLiveMode && widget.order.id.length >= 24) {
      unawaited(_refreshLiveBooking());
      _startServerTimeRefresh();
    }
  }

  Future<void> _loadStore() async {
    try {
      await WorkerDemoBookingStore.initialize();
      if (mounted) {
        setState(() {
          _storeLoading = false;
          _storeError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _storeLoading = false;
          _storeError = error;
        });
      }
    }
  }

  void _onStoreUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive && mounted && _isLiveMode) unawaited(_refreshLiveBooking());
  }

  Future<void> _refreshLiveBooking() async {
    if (_refreshing || !mounted || !_appActive) return;
    _refreshing = true;
    try {
      final refreshed = await _liveApi.fetchBookingDetails(widget.order.id);
      if (refreshed == null) throw StateError('Booking refresh unavailable');
      if (mounted)
        setState(() {
          _liveOrder = refreshed;
          _localStatus = null;
          _refreshError = null;
          _lastRefresh = DateTime.now();
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _refreshError =
              'Booking updates are unavailable. Showing the last received status. Reconnect and retry.',
        );
    } finally {
      _refreshing = false;
    }
  }

  void _startServerTimeRefresh() {
    _serverSyncTimer?.cancel();
    _serverSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_appActive && (ModalRoute.of(context)?.isCurrent ?? true))
        unawaited(_refreshLiveBooking());
    });
    _serverTimeTimer?.cancel();
    _serverTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_appActive && (ModalRoute.of(context)?.isCurrent ?? true))
        _clock.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    if (widget.operationsApi is! WorkerMobileOperationsApi) _liveApi.close();
    _serverSyncTimer?.cancel();
    _serverTimeTimer?.cancel();
    if (widget.demoMode && widget.order.id.length < 24) {
      WorkerDemoBookingStore.repository.removeListener(_onStoreUpdated);
    }
    super.dispose();
  }

  WorkerBookingSession? get _savedSession =>
      widget.demoMode &&
          widget.order.id.length < 24 &&
          !_storeLoading &&
          _storeError == null
      ? WorkerDemoBookingStore.session(widget.order.id)
      : null;

  WorkerDashboardOrder get _currentOrder {
    var order =
        _liveOrder ??
        ((!widget.demoMode || widget.order.id.length >= 24)
            ? widget.order
            : (!_storeLoading && _storeError == null
                  ? WorkerDemoBookingStore.resolve(widget.order)
                  : widget.order));
    if (_localStatus != null) {
      order = order.copyWith(status: _localStatus);
    }
    return order;
  }

  bool get _previewAllowed => kDebugMode && widget.demoMode;

  bool get _canStartPreview {
    final status = widget.order.status.toLowerCase().trim();
    return _previewAllowed &&
        !_storeLoading &&
        _storeError == null &&
        _savedSession == null &&
        !_startingService &&
        <String>{
          'accepted',
          'arrived',
          'confirmed',
          'assigned',
        }.contains(status);
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLiveExtraServices() async {
    final api = _liveApi;
    await Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerAddExtraServiceScreen(
          order: _currentOrder,
          demoMode: false,
          operationsApi: api,
        ),
      ),
    );
  }

  Future<void> _openPaymentQr() async {
    final api = _liveApi;
    await Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerPaymentQrScreen(order: _currentOrder, operationsApi: api),
      ),
    );
    final updated = await api.fetchBookingDetails(widget.order.id);
    if (mounted && updated != null) {
      setState(() {
        _liveOrder = updated;
        _localStatus = null;
      });
    }
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
    decoration: WorkerDesign.surface(radius: 18),
    child: child,
  );

  Widget _info(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _pink),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.3),
          ),
        ),
      ],
    ),
  );

  String _formatSavedTime(BuildContext context, DateTime? value) {
    if (value == null) return 'Not recorded';
    final local = value.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
    return '$date · ${TimeOfDay.fromDateTime(local).format(context)}';
  }

  String _remainingServiceTime(DateTime? end) {
    if (end == null) return 'Waiting for the server start time';
    final seconds = end.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) return 'Booked service time has ended';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')} remaining';
  }

  Widget _serviceTimingCard() {
    final order = _currentOrder;
    final extension = order.durationExtension;
    final extensionStatus = extension?['status'];
    final extensionMessage = switch (extensionStatus) {
      'pending' =>
        'The customer has 5 minutes to decide. Do not continue extension work until approved. No duration charge is added.',
      'approved' =>
        '${extension?['minutes'] ?? 15} additional minutes approved. No duration charge was added.',
      'declined' || 'expired' =>
        'No extension was approved. Finish the service; no extra-time charge was added.',
      _ => null,
    };
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booked service time',
            style: TextStyle(
              color: _deep,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          ValueListenableBuilder<DateTime>(
            valueListenable: _clock,
            builder: (context, _, child) =>
                Text(_remainingServiceTime(order.serviceEndsAt)),
          ),
          if (order.serviceEndsAt != null)
            Text(
              'Server end: ${_formatSavedTime(context, order.serviceEndsAt)}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          if (extensionMessage != null) ...[
            const SizedBox(height: 7),
            Text(extensionMessage, style: const TextStyle(color: _muted)),
          ],
        ],
      ),
    );
  }

  Widget _billRow(String label, int amount, {bool total = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: total ? _deep : _muted,
              fontSize: total ? 14 : 12.5,
              fontWeight: total ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatCustomerRupees(amount),
          style: TextStyle(
            color: total ? _pink : _deep,
            fontSize: total ? 17 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _savedServiceSummary(
    BuildContext context,
    WorkerBookingSession session,
  ) {
    final isFinished = session.serviceStage == WorkerServiceStage.finished;
    final demoPaid = session.demoPaidAt != null;
    return Column(
      children: [
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isFinished
                        ? Icons.task_alt_rounded
                        : Icons.timelapse_rounded,
                    color: isFinished ? const Color(0xFF12875A) : _pink,
                    size: 23,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      isFinished
                          ? 'Service History · Demo'
                          : 'Saved Service Session · Demo',
                      style: const TextStyle(
                        color: _deep,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _info(
                Icons.play_circle_outline_rounded,
                'Started: ${_formatSavedTime(context, session.startedAt)}',
              ),
              _info(
                Icons.flag_outlined,
                'Finished: ${_formatSavedTime(context, session.finishedAt)}',
              ),
              _info(
                Icons.credit_card_outlined,
                demoPaid
                    ? 'Payment simulation: ${_formatSavedTime(context, session.demoPaidAt)}'
                    : isFinished
                    ? 'Payment pending · No request sent'
                    : 'Payment not requested',
              ),
              const Divider(color: _border),
              Row(
                children: [
                  Icon(
                    demoPaid ? Icons.check_circle_outline : Icons.info_outline,
                    size: 18,
                    color: demoPaid ? const Color(0xFF12875A) : _pink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      demoPaid
                          ? 'Demo payment completed · NOT VERIFIED'
                          : isFinished
                          ? 'Service finished · Payment pending'
                          : 'Service in progress',
                      style: const TextStyle(
                        color: _deep,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saved Customer Bill · Preview',
                style: TextStyle(
                  color: _deep,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              _billRow('Original service', session.baseCustomerPayable),
              if (session.extras.isNotEmpty) ...[
                const Divider(color: _border),
                const Text(
                  'Selected extra services · demo only',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                for (final extra in session.extras)
                  _billRow(
                    '${extra.name} (${extra.approval.name})',
                    extra.approval == WorkerExtraApprovalStage.rejected
                        ? 0
                        : extra.customerPrice,
                  ),
              ],
              const Divider(color: _border),
              _billRow(
                'Total customer payable',
                session.demoCustomerTotal,
                total: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'Amounts and extra-service approvals are local previews. '
                'No customer approval, payment receipt or backend verification is implied.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder;
    final canStart = _canStartPreview;
    final session = _savedSession;
    final canResume =
        _previewAllowed &&
        session?.serviceStage == WorkerServiceStage.inProgress &&
        session?.startedAt != null;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        foregroundColor: _deep,
        centerTitle: true,
        title: const Text(
          'Booking Details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: widget.demoMode && (_storeLoading || _storeError != null)
          ? SafeArea(
              child: Center(
                child: _storeLoading
                    ? const CircularProgressIndicator(color: _pink)
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Could not load saved booking status.'),
                            Text('$_storeError', textAlign: TextAlign.center),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _storeLoading = true;
                                  _storeError = null;
                                });
                                _loadStore();
                              },
                              child: const Text('Retry loading'),
                            ),
                          ],
                        ),
                      ),
              ),
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(17, 10, 17, 24),
                          children: [
                            const WorkerPageBanner(
                              eyebrow: 'Appointment',
                              title: 'Booking Details',
                              subtitle:
                                  'Everything you need before the service.',
                              icon: Icons.spa_outlined,
                              photo: true,
                            ),
                            const SizedBox(height: 16),
                            if (widget.demoMode && !_isLiveMode)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 14),
                                child: Text(
                                  'DEVELOPMENT PREVIEW · No live service actions',
                                  style: TextStyle(fontSize: 10, color: _muted),
                                ),
                              ),
                            _card(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 27,
                                    backgroundColor: const Color(0xFFFFE2EC),
                                    child: Text(
                                      order.customer.isNotEmpty
                                          ? order.customer[0]
                                          : 'C',
                                      style: const TextStyle(
                                        color: _pink,
                                        fontSize: 23,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.customer,
                                          style: const TextStyle(
                                            color: _deep,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          order.customerPhone != null &&
                                                  order
                                                      .customerPhone!
                                                      .isNotEmpty
                                              ? '${order.customerPhone} · Booking ${order.id}'
                                              : 'Booking ${order.id}',
                                          style: const TextStyle(
                                            color: _muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    color: _pink,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _card(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 65,
                                        height: 65,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFE8EF),
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                        ),
                                        child:
                                            order.service
                                                .toLowerCase()
                                                .contains('bridal')
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                                child: Image.asset(
                                                  'assets/images/dashboard/bridal_portrait.jpg',
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.spa_rounded,
                                                color: _pink,
                                                size: 32,
                                              ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order.service,
                                              style: const TextStyle(
                                                color: _deep,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              order.status,
                                              style: const TextStyle(
                                                color: _pink,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        formatCustomerPaise(
                                          order.customerPayablePaise ??
                                              order.customerPayable * 100,
                                        ),
                                        style: const TextStyle(
                                          color: _deep,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 13),
                                  const Divider(color: _border),
                                  const SizedBox(height: 12),
                                  _info(
                                    Icons.access_time_rounded,
                                    '${order.time} · ${order.duration}',
                                  ),
                                  _info(Icons.place_outlined, order.location),
                                  _info(
                                    Icons.payments_outlined,
                                    'Customer payable: ${formatCustomerPaise(order.customerPayablePaise ?? order.customerPayable * 100)}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _card(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Service Details',
                                    style: TextStyle(
                                      color: _deep,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    order.itemsDescription ??
                                        (order.service.isNotEmpty
                                            ? order.service
                                            : 'The full service description will be shown once booking details are available from the backend.'),
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12.5,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (order.compensationRupees != null) ...[
                                    const SizedBox(height: 10),
                                    const Divider(color: _border),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 18,
                                          color: Color(0xFF14865E),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Worker Compensation: ₹${order.compensationRupees}',
                                            style: const TextStyle(
                                              color: Color(0xFF14865E),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (order.paymentMethod != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.receipt_outlined,
                                          size: 18,
                                          color: _muted,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Payment: ${order.paymentMethod?.toUpperCase()} (${order.paymentStatus?.toUpperCase() ?? 'PENDING'})',
                                            style: const TextStyle(
                                              color: _muted,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Customer Note',
                                    style: TextStyle(
                                      color: _deep,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No special requests noted for this appointment.',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isLiveMode &&
                                order.status.toLowerCase() ==
                                    'in progress') ...[
                              const SizedBox(height: 14),
                              if (_refreshError != null) ...[
                                Text(
                                  _refreshError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                if (_lastRefresh != null)
                                  Text(
                                    'Last updated: ' +
                                        _lastRefresh!.toLocal().toString(),
                                  ),
                                TextButton(
                                  onPressed: _refreshLiveBooking,
                                  child: const Text('Retry booking update'),
                                ),
                              ],
                              _serviceTimingCard(),
                            ],
                            if (session != null) ...[
                              const SizedBox(height: 14),
                              _savedServiceSummary(context, session),
                            ],
                            const SizedBox(height: 14),
                            _card(
                              Row(
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
                                        color: _muted,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(17, 10, 17, 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isLiveMode &&
                                order.status.toLowerCase() == 'in progress')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: OutlinedButton.icon(
                                  onPressed: _openLiveExtraServices,
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('Request Extra Service'),
                                ),
                              ),
                            if (_showPaymentChoices)
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      key: Key(
                                        order.paymentMethod == 'cash'
                                            ? 'generate-payment-qr'
                                            : 'start-service-entry',
                                      ),
                                      onPressed: _updatingProgress
                                          ? null
                                          : _openPaymentQr,
                                      icon: const Icon(Icons.qr_code),
                                      label: const Text('Generate QR'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _pink,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 50),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      key: Key(
                                        order.paymentMethod == 'cash'
                                            ? 'start-service-entry'
                                            : 'cash-collection',
                                      ),
                                      onPressed: _updatingProgress
                                          ? null
                                          : _completeCashService,
                                      icon: const Icon(Icons.payments_outlined),
                                      label: const Text('Cash Collection'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _pink,
                                        minimumSize: const Size(0, 50),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              SizedBox(
                                height: 50,
                                child: FilledButton(
                                  key: const Key('start-service-entry'),
                                  onPressed: _isLiveMode
                                      ? order.status.toLowerCase() ==
                                                'completed'
                                            ? order.paymentStatus == 'paid'
                                                  ? () => Navigator.of(
                                                      context,
                                                    ).maybePop()
                                                  : _openPaymentQr
                                            : _canAct(order.status)
                                            ? _handleProgressAction
                                            : () => Navigator.of(
                                                context,
                                              ).maybePop()
                                      : (session?.serviceStage ==
                                                WorkerServiceStage.finished
                                            ? () => Navigator.of(
                                                context,
                                              ).maybePop()
                                            : _startingService
                                            ? null
                                            : canResume
                                            ? _openProgressPreview
                                            : canStart
                                            ? _startServicePreview
                                            : null),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _pink,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(
                                      0xFFF5CBD9,
                                    ),
                                    disabledForegroundColor: _deep,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    _updatingProgress
                                        ? 'Updating status…'
                                        : _isLiveMode
                                        ? order.status.toLowerCase() ==
                                                  'completed'
                                              ? order.paymentStatus == 'paid'
                                                    ? 'Service Completed - Payment Received'
                                                    : 'Generate Payment QR'
                                              : _progressButtonText(
                                                  order.status,
                                                )
                                        : (session?.serviceStage ==
                                                  WorkerServiceStage.finished
                                              ? 'Back to My Bookings'
                                              : _startingService
                                              ? 'Saving Demo Service…'
                                              : canResume
                                              ? 'Resume Demo Service'
                                              : canStart
                                              ? 'Start Service · Enter Customer OTP'
                                              : 'Start Service Not Available'),
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
    );
  }
}
