import 'dart:async';
import 'package:flutter/material.dart';

import '../../integration/worker_mobile_operations_api.dart';
import 'worker_booking_data.dart';
import '../widgets/worker_design.dart';

class WorkerPaymentQrScreen extends StatefulWidget {
  const WorkerPaymentQrScreen({
    super.key,
    required this.order,
    required this.operationsApi,
  });

  final WorkerDashboardOrder order;
  final WorkerMobileOperationsApi operationsApi;

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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WorkerDesign.cream,
    appBar: AppBar(
      title: const Text('Customer Payment'),
      centerTitle: true,
      backgroundColor: WorkerDesign.cream,
      foregroundColor: WorkerDesign.deep,
      surfaceTintColor: WorkerDesign.cream,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: WorkerDesign.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      _paid
                          ? Icons.check_circle_rounded
                          : Icons.qr_code_2_rounded,
                      color: WorkerDesign.pink,
                      size: 44,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _paid
                          ? 'Payment received · Service completed'
                          : _paymentVerified
                          ? 'Payment verified · Enter admin OTP'
                          : _imageUrl == null
                          ? 'Generate a secure payment QR'
                          : 'Scan to pay the final bill',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: WorkerDesign.deep,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Booking ${widget.order.id}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: WorkerDesign.muted),
                    ),
                    if (_amountPaise != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '₹${(_amountPaise! / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: WorkerDesign.pink,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    if (_imageUrl != null && !_paymentVerified) ...[
                      const SizedBox(height: 18),
                      Image.network(
                        _imageUrl!,
                        width: 250,
                        height: 250,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Text(
                              'The QR image could not be loaded. Try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: WorkerDesign.muted),
                            ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Payment is marked complete only after Razorpay verifies it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: WorkerDesign.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      _paymentMessage ??
                          'The final amount is calculated by the server, including approved extras.',
                      textAlign: TextAlign.center,
                    ),
                    if (_paymentVerified && !_paid) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _completionOtp,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Service-completion OTP',
                          hintText: 'Ask your administrator',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (!_paymentVerified)
                      TextButton(
                        onPressed: _checkPayment,
                        child: const Text('Check payment status'),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _paid
                            ? () => Navigator.of(context).pop()
                            : _paymentVerified
                            ? _completing
                                  ? null
                                  : _completeWithOtp
                            : _loading
                            ? null
                            : _generateQr,
                        icon: _loading || _completing
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
                          _paid
                              ? 'Back to booking'
                              : _paymentVerified
                              ? _completing
                                    ? 'Verifying OTP…'
                                    : 'Verify OTP & complete service'
                              : _loading
                              ? 'Generating…'
                              : _imageUrl == null
                              ? 'Generate QR Code'
                              : 'Refresh QR Code',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: WorkerDesign.pink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
