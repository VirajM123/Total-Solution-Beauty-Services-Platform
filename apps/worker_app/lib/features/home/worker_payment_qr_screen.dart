import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../integration/worker_environment.dart';

import '../../integration/worker_mobile_operations_api.dart';
import 'worker_booking_data.dart';
import '../widgets/worker_design.dart';
import '../widgets/worker_auth_visuals.dart';

class WorkerPaymentQrScreen extends StatefulWidget {
  const WorkerPaymentQrScreen({
    super.key,
    required this.order,
    required this.operationsApi,
    this.onCashCollection,
  });

  final WorkerDashboardOrder order;
  final WorkerMobileOperationsApi operationsApi;
  final VoidCallback? onCashCollection;

  @override
  State<WorkerPaymentQrScreen> createState() => _WorkerPaymentQrScreenState();
}

class _WorkerPaymentQrScreenState extends State<WorkerPaymentQrScreen> {
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

  @override
  void initState() {
    super.initState();
    _paid =
        widget.order.paymentStatus == 'paid' &&
        widget.order.status.toLowerCase() == 'completed';
    _paymentVerified = widget.order.paymentStatus == 'paid';
    _checkPayment();
    _paymentTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkPayment(),
    );
  }

  @override
  void dispose() {
    _paymentTimer?.cancel();
    _completionOtp.dispose();
    super.dispose();
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
        _paymentVerified = booking?.paymentStatus == 'paid';
        _paid =
            booking?.paymentStatus == 'paid' &&
            booking?.status.toLowerCase() == 'completed';
        _paymentMessage = booking == null
            ? 'Unable to check payment. Keep this screen open or retry when connected.'
            : _paid
            ? 'Payment received. Service completed.'
            : _paymentVerified
            ? 'Payment verified. Contact your administrator for the service-completion OTP.'
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
      _checkingPayment = false;
    }
  }

  Future<void> _generateQr() async {
    if (_loading || _paid || _paymentVerified) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish service and collect payment?'),
        content: const Text(
          'The final bill includes customer-approved extras. Generating the QR locks the bill. After verified payment, ask your administrator for a one-time completion OTP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
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
        _amountPaise = amount;
      });
      await _checkPayment();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      await _checkPayment();
      if (mounted && !_paid) {
        setState(
          () => _paymentMessage = 'OTP submitted. Refreshing service status…',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _selectCashCollection() async {
    final onCashCollection = widget.onCashCollection;
    if (onCashCollection == null) return;
    await Navigator.of(context).maybePop();
    onCashCollection();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WorkerDesign.cream,
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
      ),
      title: WorkerAuthBrand(
        subtitle: widget.order.location.isEmpty
            ? 'Worker App'
            : widget.order.location,
      ),
      centerTitle: false,
      backgroundColor: WorkerDesign.cream,
      foregroundColor: WorkerDesign.deep,
      surfaceTintColor: WorkerDesign.cream,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _paid ? _completedContent(context) : _paymentContent(context),
        ),
      ),
    ),
  );

  Widget _paymentContent(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
    children: [
      const Text(
        'Payment Collection',
        style: TextStyle(
          color: WorkerDesign.deep,
          fontSize: 25,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
        ),
      ),
      const SizedBox(height: 10),
      _customerCard(),
      const SizedBox(height: 9),
      _amountCard(),
      const SizedBox(height: 9),
      _paymentMethods(context),
      const SizedBox(height: 9),
      _qrCard(),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
      if (_paymentVerified && !_paid) ...[
        const SizedBox(height: 9),
        _completionOtpCard(),
      ],
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDF4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: WorkerDesign.pink),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Payment is marked complete only after the provider verifies the transaction.',
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
          radius: 34,
          backgroundColor: const Color(0xFFFFDCE9),
          backgroundImage: widget.order.customerPhotoUrl?.isNotEmpty == true
              ? NetworkImage(widget.order.customerPhotoUrl!)
              : null,
          child: widget.order.customerPhotoUrl?.isNotEmpty == true
              ? null
              : const Icon(
                  Icons.person_rounded,
                  color: WorkerDesign.pink,
                  size: 34,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                widget.order.customerPhone?.isNotEmpty == true
                    ? widget.order.customerPhone!
                    : 'Phone unavailable',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: WorkerDesign.muted, fontSize: 11),
              ),
              Text(
                widget.order.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: WorkerDesign.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _amountCard() => Container(
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFEFF5), Color(0xFFFFDCE9)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: WorkerDesign.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Amount to collect',
                style: TextStyle(color: WorkerDesign.muted, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                formatCustomerPaise(
                  _amountPaise ?? widget.order.exactCustomerPayablePaise,
                ),
                key: const Key('payment-amount'),
                style: const TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (_amountPaise == null)
                const Text(
                  'Final bill confirmed when QR is created',
                  style: TextStyle(color: WorkerDesign.muted, fontSize: 10),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const SizedBox(
          width: 96,
          height: 92,
          child: Opacity(opacity: .85, child: WorkerLotusArtwork()),
        ),
      ],
    ),
  );

  Widget _paymentMethods(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: WorkerDesign.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: _methodButton(
            icon: Icons.send_rounded,
            label: 'UPI',
            selected: true,
          ),
        ),
        Expanded(
          child: _methodButton(
            icon: Icons.credit_card_outlined,
            label: 'Card · Soon',
            enabled: false,
          ),
        ),
        Expanded(
          child: _methodButton(
            icon: Icons.payments_outlined,
            label: 'Cash',
            enabled: widget.onCashCollection != null,
            onPressed: _selectCashCollection,
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
        padding: const EdgeInsets.symmetric(horizontal: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 4),
          Flexible(child: Text(label, maxLines: 1)),
        ],
      ),
    ),
  );

  Widget _qrCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: WorkerDesign.surface(radius: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Scan & Pay using any UPI app',
                style: TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_imageUrl != null && !_paymentVerified)
              TextButton.icon(
                key: const Key('refresh-payment-qr'),
                onPressed: _loading ? null : _generateQr,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: WorkerDesign.pink,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_paymentVerified)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FAF2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF14965F)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment verified. Ask your administrator for the completion OTP.',
                    style: TextStyle(color: WorkerDesign.deep, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: WorkerDesign.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _imageUrl == null
                    ? const Icon(
                        Icons.qr_code_2_rounded,
                        color: Color(0xFFB8B3C5),
                        size: 90,
                      )
                    : Image.network(
                        kIsWeb
                            ? '${WorkerEnvironment.apiBaseUrl}/mobile/payments/razorpay/qr-image?url=${Uri.encodeComponent(_imageUrl!)}'
                            : _imageUrl!,
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image_outlined,
                              color: WorkerDesign.muted,
                              size: 40,
                            ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0D8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Waiting for payment',
                        style: TextStyle(
                          color: Color(0xFFB85E00),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _imageUrl == null
                          ? 'Create a secure QR for this booking.'
                          : 'Ask the customer to scan the QR and pay ${formatCustomerPaise(_amountPaise ?? widget.order.exactCustomerPayablePaise)}.',
                      style: const TextStyle(
                        color: WorkerDesign.muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _paymentMessage ??
                          'Payment will be confirmed by the payment provider.',
                      style: const TextStyle(
                        color: WorkerDesign.muted,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (!_paymentVerified) ...[
          const SizedBox(height: 10),
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
              label: Text(
                _loading
                    ? 'Generating…'
                    : _imageUrl == null
                    ? 'Generate QR Code'
                    : 'Refresh QR Code',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: WorkerDesign.pink,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _checkingPayment ? null : _checkPayment,
              child: const Text('Check payment status'),
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
