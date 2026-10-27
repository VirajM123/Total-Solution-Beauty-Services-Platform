import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/slide_page_route.dart';
import '../../integration/worker_api.dart';
import '../../integration/worker_mobile_auth_api.dart';
import '../registration/screens/worker_application_status_screen.dart';
import '../registration/screens/worker_account_registration_screen.dart';
import '../home/worker_home_screen.dart';
import '../registration/screens/worker_personal_details_screen.dart';

const _plum = Color(0xFF460621);
const _berry = Color(0xFFB20A50);
const _muted = Color(0xFF735A67);
const _ivory = Color(0xFFFFF9F5);
const _line = Color(0xFFE8C9CE);

class WorkerOtpScreen extends StatefulWidget {
  const WorkerOtpScreen({
    super.key,
    required this.phone,
    this.authApi,
    this.registrationName,
    this.registrationEmail,
  });

  final String phone;
  final WorkerAuthApi? authApi;
  final String? registrationName;
  final String? registrationEmail;
  WorkerAuthApi get auth => authApi ?? WorkerMobileAuthApi();

  @override
  State<WorkerOtpScreen> createState() => _WorkerOtpScreenState();
}

class _WorkerOtpScreenState extends State<WorkerOtpScreen> {
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  Timer? _resendTimer;
  int _remainingSeconds = 30;
  String _lastOtpInput = '';
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _resendTimer?.cancel();
    _remainingSeconds = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _resend() async {
    if (_remainingSeconds != 0) return;
    try {
      await widget.auth.resendOtp();
      if (!mounted) return;
      _otp.clear();
      _otpFocus.requestFocus();
      setState(() => _error = null);
      _startCountdown();
    } on WorkerAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _verify() async {
    if (_verifying) return;
    if (_otp.text.length != 6) {
      setState(() => _error = 'Enter the complete 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final identity = await widget.auth.verifyOtp(
        widget.phone,
        _otp.text,
        fullName: 'Worker',
      );
      if (!mounted) return;
      final proof = identity.registrationToken;
      if (proof != null) {
        final registrationName = widget.registrationName;
        if (registrationName != null) {
          await widget.auth.completeRegistration(
            registrationToken: proof,
            fullName: registrationName,
            email: widget.registrationEmail,
          );
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            SlidePageRoute<void>(
              page: WorkerPersonalDetailsScreen(
                initialName: registrationName,
                initialMobile: widget.phone,
                initialEmail: widget.registrationEmail ?? '',
                verifiedMobile: widget.phone,
                authApi: widget.auth,
              ),
            ),
            (_) => false,
          );
          return;
        }
        await Navigator.of(context).pushReplacement(
          SlidePageRoute<void>(
            page: WorkerAccountRegistrationScreen(
              phone: widget.phone,
              registrationToken: proof,
              authApi: widget.auth,
            ),
          ),
        );
        return;
      }
      if (identity.approval == WorkerApproval.approved) {
        Navigator.of(context).pushAndRemoveUntil(
          SlidePageRoute<void>(page: const WorkerHomeScreen(demoMode: false)),
          (_) => false,
        );
        return;
      }
      if (identity.approval == WorkerApproval.notRegistered) {
        Navigator.of(context).pushAndRemoveUntil(
          SlidePageRoute<void>(
            page: WorkerPersonalDetailsScreen(
              initialName: '',
              initialMobile: widget.phone,
              initialEmail: '',
              verifiedMobile: widget.phone,
              authApi: widget.auth,
            ),
          ),
          (_) => false,
        );
        return;
      }
      final stage = switch (identity.approval) {
        WorkerApproval.pending => WorkerApplicationStage.underReview,
        WorkerApproval.rejected => WorkerApplicationStage.rejected,
        WorkerApproval.suspended => WorkerApplicationStage.actionRequired,
        _ => WorkerApplicationStage.underReview,
      };
      Navigator.of(context).pushAndRemoveUntil(
        SlidePageRoute<void>(
          page: WorkerApplicationStatusScreen(
            stage: stage,
            applicationReference: identity.workerId.isEmpty
                ? null
                : identity.workerId,
            authApi: widget.auth,
            workerPhone: widget.phone,
            reviewMessage: identity.approval == WorkerApproval.pending
                ? 'Your application is currently under admin review.'
                : null,
          ),
        ),
        (_) => false,
      );
    } on WorkerAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otp.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _otp.text;
    final activeIndex = code.length.clamp(0, 5);

    return Scaffold(
      backgroundColor: _ivory,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _ivory,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to login',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _plum),
        ),
        title: const Text(
          'Verify mobile number',
          style: TextStyle(
            color: _plum,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 188,
                        child: Image.asset(
                          'assets/images/illustrations/worker_customer_otp_phone.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.mark_email_read_outlined,
                              size: 92,
                              color: _berry,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'One step closer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _plum,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Enter the 6-digit code sent to\n+91 ${widget.phone}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'VERIFICATION CODE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.3,
                          color: _plum,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // A single real TextField powers six visual boxes so
                      // typing, paste, autofill and backspace remain reliable.
                      Stack(
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.01,
                              child: TextField(
                                key: const Key('worker-otp'),
                                controller: _otp,
                                focusNode: _otpFocus,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                onChanged: (value) {
                                  if (value.length > _lastOtpInput.length ||
                                      (value.length == _lastOtpInput.length &&
                                          value != _lastOtpInput)) {
                                    HapticFeedback.lightImpact();
                                  }
                                  _lastOtpInput = value;
                                  setState(() => _error = null);
                                },
                                onSubmitted: (_) => _verify(),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                ),
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: Row(
                              children: List.generate(6, (index) {
                                final filled = index < code.length;
                                final isActive =
                                    _otpFocus.hasFocus &&
                                    index == activeIndex &&
                                    code.length < 6;
                                return Expanded(
                                  child: Container(
                                    height: 55,
                                    margin: EdgeInsets.only(
                                      right: index == 5 ? 0 : 7,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isActive ? _berry : _line,
                                        width: isActive ? 1.8 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      filled ? code[index] : '',
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w700,
                                        color: _plum,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _otpFocus.requestFocus(),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB3261E),
                          ),
                        ),
                      ],
                      const SizedBox(height: 25),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD41361), Color(0xFF750034)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x228B174A),
                              blurRadius: 14,
                              offset: Offset(0, 7),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          key: const Key('worker-verify'),
                          onPressed: _verifying ? null : _verify,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _verifying
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Verify & Continue',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(Icons.arrow_forward_rounded),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: _remainingSeconds == 0
                            ? TextButton(
                                onPressed: _resend,
                                child: const Text(
                                  'Resend code',
                                  style: TextStyle(
                                    color: _berry,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : Text(
                                'Retry available in ${_remainingSeconds}s',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                              ),
                      ),
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
