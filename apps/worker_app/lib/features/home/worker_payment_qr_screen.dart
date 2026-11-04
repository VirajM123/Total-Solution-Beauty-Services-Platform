import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../integration/worker_mobile_operations_api.dart';
import 'worker_booking_data.dart';
import '../widgets/worker_design.dart';

class WorkerPaymentQrScreen extends StatefulWidget {
  const WorkerPaymentQrScreen({
    super.key,
    required this.order,
    required this.operationsApi,
    this.onCashCollection,
  });

  final WorkerDashboardOrder order;
  final WorkerMobileOperationsApi operationsApi;
  final Future<void> Function()? onCashCollection;

  @override
  State<WorkerPaymentQrScreen> createState() => _WorkerPaymentQrScreenState();
}

class _WorkerPaymentQrScreenState extends State<WorkerPaymentQrScreen>
    with WidgetsBindingObserver {
  String _activeTab = 'upi'; // 'upi', 'cash'
  bool _loading = false;
  String? _error;
  String? _imageUrl;
  int? _amountPaise;
  Timer? _paymentTimer;
  bool _checkingPayment = false;
  bool _paymentVerified = false;
  bool _paid = false;
  bool _completing = false;
  final _completionOtp = TextEditingController();
  String? _paymentMessage;
  bool _appActive = true;
  bool _cashReported = false;
  bool _qrLocked = false;
  Uint8List? _imageBytes;
  bool _submittingCash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cashReported = widget.order.cashCollectionReportedAt != null;
    _qrLocked =
        widget.order.paymentMethod == 'razorpay_qr' &&
        widget.order.serviceFinishedAt != null;
    _paid =
        widget.order.paymentStatus == 'paid' &&
        widget.order.status.toLowerCase() == 'completed';
    _paymentVerified = widget.order.paymentStatus == 'paid';
    _checkPayment();
    _paymentTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_appActive && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _checkPayment();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentTimer?.cancel();
    _completionOtp.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive) unawaited(_checkPayment());
  }

  Future<void> _checkPayment() async {
    if (_checkingPayment || _paid) return;
    _checkingPayment = true;
    try {
      final booking = await widget.operationsApi.fetchBookingDetails(
        widget.order.id,
      );
      if (!mounted) return;
      setState(() {
        _cashReported = booking?.cashCollectionReportedAt != null;
        _qrLocked =
            booking?.paymentMethod == 'razorpay_qr' &&
            booking?.serviceFinishedAt != null;
        _paymentVerified = booking?.paymentStatus == 'paid';
        _paid =
            booking?.paymentStatus == 'paid' &&
            booking?.status.toLowerCase() == 'completed';
        _paymentMessage = booking == null
            ? 'Unable to check payment. Keep this screen open or retry when connected.'
            : _paid
            ? 'Payment received. Service completed.'
            : _paymentVerified
            ? 'Payment verified. Ask your administrator for the completion OTP.'
            : 'Awaiting verified payment from Razorpay.';
      });
      if (_paid) _paymentTimer?.cancel();
    } catch (_) {
      if (mounted) {
        setState(
          () => _paymentMessage =
              'Unable to check payment. Keep this screen open or retry when connected.',
        );
      }
    } finally {
      if (mounted) setState(() => _checkingPayment = false);
    }
  }

  Future<void> _generateQr() async {
    if (_loading || _paid || _paymentVerified) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate final payment QR?'),
        content: const Text(
          'This locks the final bill. Resolve any extra services or time extension before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate QR'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.operationsApi.createBookingPaymentQr(
        widget.order.id,
      );
      final imageUrl = result['imageUrl'];
      final amount = int.tryParse('${result['amountPaise']}');
      final uri = Uri.tryParse('$imageUrl');
      if (imageUrl is! String ||
          uri == null ||
          uri.scheme != 'https' ||
          amount == null ||
          amount <= 0) {
        throw const FormatException(
          'The payment provider returned an invalid QR.',
        );
      }
      if (!mounted) return;
      setState(() {
        _imageUrl = imageUrl;
        _qrLocked = true;
        _amountPaise = amount;
      });
      unawaited(_loadQrImage());
      await _checkPayment();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadQrImage() async {
    try {
      final bytes = await widget.operationsApi.fetchBookingPaymentQrImage(
        widget.order.id,
      );
      if (mounted) setState(() => _imageBytes = bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load the payment QR. Retry when connected.');
      }
    }
  }

  Future<void> _reportCashCollection() async {
    if (_submittingCash || _paid || _paymentVerified || _qrLocked) return;
    if (widget.onCashCollection == null) {
      setState(
        () => _error = 'Return to booking details to report cash collection.',
      );
      return;
    }
    setState(() => _submittingCash = true);
    try {
      await widget.onCashCollection!();
      await _checkPayment();
    } finally {
      if (mounted) setState(() => _submittingCash = false);
    }
  }

  Future<void> _completeWithOtp() async {
    final otp = _completionOtp.text.trim();
    if (_completing || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Enter the 6-digit OTP from your administrator.');
      return;
    }
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      await widget.operationsApi.updateBookingProgress(
        bookingId: widget.order.id,
        action: 'complete',
        otp: otp,
      );
      if (!mounted) return;
      setState(() {
        _paid = true;
        _paymentVerified = true;
      });
      _paymentTimer?.cancel();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WorkerDesign.cream,
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
      ),
      title: const Text(
        'Payment Collection',
        style: TextStyle(
          color: WorkerDesign.deep,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Image.asset(
            'assets/images/logo/logo.png',
            height: 38,
            fit: BoxFit.contain,
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: _paid ? _completedContent(context) : _mainContent(context),
    ),
  );

  Widget _mainContent(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
    children: [
      _customerCard(),
      const SizedBox(height: 9),
      _amountCard(),
      const SizedBox(height: 12),
      _paymentMethods(context),
      const SizedBox(height: 12),
      if (_activeTab == 'upi') _qrCard() else _cashPaymentCard(),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ],
      if (_paymentVerified && !_paid) ...[
        const SizedBox(height: 12),
        _completionOtpCard(),
      ],
      if (_activeTab == 'cash' && _cashReported)
        const Text(
          'Cash report sent. Waiting for administrator reconciliation.',
        ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDF4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: WorkerDesign.pink, size: 20),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Payment verification is followed by administrator OTP confirmation to complete the service.',
                style: TextStyle(
                  color: WorkerDesign.muted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _customerCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEFF5),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: WorkerDesign.border),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFFFFDCE9),
          backgroundImage: widget.order.customerPhotoUrl?.isNotEmpty == true
              ? NetworkImage(widget.order.customerPhotoUrl!)
              : null,
          child: widget.order.customerPhotoUrl?.isNotEmpty == true
              ? null
              : const Icon(
                  Icons.person_rounded,
                  color: WorkerDesign.pink,
                  size: 30,
                ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer',
                style: TextStyle(color: WorkerDesign.muted, fontSize: 11),
              ),
              Text(
                widget.order.customer,
                style: const TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((widget.order.customerPhone ?? '').isNotEmpty)
                Text(
                  widget.order.customerPhone ?? '',
                  style: const TextStyle(
                    color: WorkerDesign.muted,
                    fontSize: 11.5,
                  ),
                ),
              Text(
                widget.order.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WorkerDesign.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _amountCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: WorkerDesign.surface(radius: 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Amount to collect',
                style: TextStyle(color: WorkerDesign.muted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                formatCustomerPaise(
                  _amountPaise ?? widget.order.exactCustomerPayablePaise,
                ),
                style: const TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Final bill confirmed for this booking',
                style: TextStyle(color: WorkerDesign.muted, fontSize: 10),
              ),
            ],
          ),
        ),
        Image.asset(
          'assets/images/logo/logo.png',
          height: 52,
          fit: BoxFit.contain,
        ),
      ],
    ),
  );

  Widget _paymentMethods(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: WorkerDesign.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: _methodButton(
            icon: Icons.qr_code_2_rounded,
            label: 'UPI (QR)',
            selected: _activeTab == 'upi',
            onPressed: () => setState(() => _activeTab = 'upi'),
          ),
        ),
        Expanded(
          child: _methodButton(
            icon: Icons.payments_outlined,
            label: 'Cash',
            selected: _activeTab == 'cash',
            onPressed: () => setState(() => _activeTab = 'cash'),
          ),
        ),
      ],
    ),
  );

  Widget _methodButton({
    required IconData icon,
    required String label,
    bool selected = false,
    bool enabled = true,
    VoidCallback? onPressed,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: selected ? WorkerDesign.pink : WorkerDesign.muted,
        backgroundColor: selected ? const Color(0xFFFFE3ED) : Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Flexible(child: Text(label, maxLines: 1)),
        ],
      ),
    ),
  );

  /// Problem 2 Fix: Centered, Large, High-Contrast QR Code Card
  Widget _qrCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: WorkerDesign.surface(radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Scan & Pay using any UPI app',
                style: TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_imageUrl != null && !_paymentVerified)
              TextButton.icon(
                key: const Key('refresh-payment-qr'),
                onPressed: _loading ? null : _generateQr,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: WorkerDesign.pink,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_paymentVerified)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FAF2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF14965F).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF14965F),
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Payment verified. Ask your administrator for the completion OTP.',
                    style: TextStyle(
                      color: Color(0xFF0F5A38),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Use the available square without cropping the scannable image.
          Center(
            child: Container(
              width: 320,
              constraints: const BoxConstraints(maxWidth: 320),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: WorkerDesign.border, width: 2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10C74776),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: _imageUrl == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            color: Color(0xFFB8B3C5),
                            size: 100,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap below to generate QR',
                            style: TextStyle(
                              color: WorkerDesign.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _imageBytes == null
                            ? TextButton(
                                onPressed: _loadQrImage,
                                child: const Text('Retry QR image'),
                              )
                            : Image.memory(
                                _imageBytes!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => TextButton(
                                  onPressed: _loadQrImage,
                                  child: const Text('Retry QR image'),
                                ),
                              ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0D8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 12, color: Color(0xFFB85E00)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _imageUrl == null
                        ? 'Ready to generate payment'
                        : 'Waiting for payment (${formatCustomerPaise(_amountPaise ?? widget.order.exactCustomerPayablePaise)})',
                    style: const TextStyle(
                      color: Color(0xFFB85E00),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask customer to scan using Google Pay, PhonePe, Paytm, or BHIM UPI.',
            textAlign: TextAlign.center,
            style: TextStyle(color: WorkerDesign.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          if (_imageUrl == null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('generate-payment-qr-action'),
                onPressed: _loading ? null : _generateQr,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.qr_code_2_rounded),
                label: Text(_loading ? 'Generating…' : 'Generate QR Code'),
                style: FilledButton.styleFrom(
                  backgroundColor: WorkerDesign.pink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: _checkingPayment ? null : _checkPayment,
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Check payment status'),
            ),
          ),
          if (_paymentMessage != null)
            Text(
              _paymentMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: WorkerDesign.muted, fontSize: 11),
            ),
        ],
      ],
    ),
  );

  Widget _cashPaymentCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: WorkerDesign.surface(radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.payments_outlined, color: Color(0xFF14965F), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cash Payment Collection',
                style: TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE9FAF2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF14965F).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exact Cash Amount to Collect:',
                style: TextStyle(color: Color(0xFF0F5A38), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                formatCustomerPaise(
                  _amountPaise ?? widget.order.exactCustomerPayablePaise,
                ),
                style: const TextStyle(
                  color: Color(0xFF14965F),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_paymentVerified)
          const Text(
            '✅ Cash collected and verified.',
            style: TextStyle(
              color: Color(0xFF14965F),
              fontWeight: FontWeight.w700,
            ),
          )
        else ...[
          const Text(
            'Cash collection requires administrator reconciliation.',
            style: TextStyle(
              color: WorkerDesign.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submittingCash || _cashReported || _qrLocked
                  ? null
                  : _reportCashCollection,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                _cashReported
                    ? 'Awaiting Admin Cash Reconciliation'
                    : 'Report cash collection',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF14965F),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _completionOtpCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: WorkerDesign.surface(radius: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complete this appointment',
          style: TextStyle(
            color: WorkerDesign.deep,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          key: const Key('service-completion-otp'),
          controller: _completionOtp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: '6-digit administrator OTP',
            hintText: 'Ask your administrator',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _completing ? null : _completeWithOtp,
            icon: _completing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _completing ? 'Verifying OTP…' : 'Verify OTP & complete service',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: WorkerDesign.pink,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    ),
  );

  Widget _completedContent(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(15, 20, 15, 24),
    children: [
      const SizedBox(height: 25),
      const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF19B974),
        size: 96,
      ),
      const SizedBox(height: 18),
      const Text(
        'Service completed!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: WorkerDesign.deep,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Payment received and appointment completed.',
        textAlign: TextAlign.center,
        style: TextStyle(color: WorkerDesign.muted, fontSize: 14),
      ),
      const SizedBox(height: 8),
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFD8F9E9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Payment received · Service completed',
          style: TextStyle(
            color: Color(0xFF078B53),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFF5),
          border: Border.all(color: WorkerDesign.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.order.service,
              style: const TextStyle(
                color: WorkerDesign.deep,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _completedDetail(
              Icons.person_outline_rounded,
              widget.order.customer,
            ),
            _completedDetail(Icons.schedule_rounded, widget.order.duration),
            _completedDetail(Icons.location_on_outlined, widget.order.location),
            const Divider(color: WorkerDesign.border, height: 22),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total amount',
                        style: TextStyle(color: WorkerDesign.muted),
                      ),
                      Text(
                        formatCustomerPaise(
                          _amountPaise ??
                              widget.order.exactCustomerPayablePaise,
                        ),
                        style: const TextStyle(
                          color: WorkerDesign.deep,
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8F9E9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF078B53),
                        size: 19,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Paid',
                        style: TextStyle(
                          color: Color(0xFF078B53),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Back to booking'),
        style: OutlinedButton.styleFrom(
          foregroundColor: WorkerDesign.pink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: WorkerDesign.pink),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        icon: const Icon(Icons.home_rounded),
        label: const Text('Go to Home'),
        style: FilledButton.styleFrom(
          backgroundColor: WorkerDesign.pink,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ],
  );

  Widget _completedDetail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, color: WorkerDesign.deep, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: WorkerDesign.muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
