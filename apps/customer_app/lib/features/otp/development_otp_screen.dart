import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/route_names.dart';
import '../../core/api/mobile_api.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';
import '../../integration/customer_auth_api.dart';

class CustomerRegistrationDraft {
  const CustomerRegistrationDraft({
    required this.name,
    required this.phone,
    this.email,
  });

  final String name;
  final String phone;
  final String? email;
}

class CustomerOtpRouteArgs {
  const CustomerOtpRouteArgs({
    required this.phone,
    required this.challengeId,
    this.registration,
  });
  final String phone;
  final String challengeId;
  final CustomerRegistrationDraft? registration;
}

class CustomerRegistrationArgs {
  const CustomerRegistrationArgs({this.phone = '', this.registrationToken});
  final String phone;
  final String? registrationToken;
}

class CustomerOtpScreen extends StatefulWidget {
  const CustomerOtpScreen({
    super.key,
    required this.args,
    required this.auth,
  });

  final CustomerOtpRouteArgs args;
  final CustomerAuthApi auth;

  @override
  State<CustomerOtpScreen> createState() => _CustomerOtpScreenState();
}

class _CustomerOtpScreenState extends State<CustomerOtpScreen> {
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _cooldown;
  int _remaining = 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _cooldown?.cancel();
    setState(() => _remaining = 30);
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        timer.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Enter the complete 6-digit code.');
      return;
    }
    setState(() {
      _error = null;
    });
    try {
      final result = await widget.auth.verifyOtp(
        widget.args.challengeId,
        _code.text,
        fullName: widget.args.registration?.name ?? 'Customer',
      );
      if (!mounted) return;
      if (result.registrationRequired) {
        final registration = widget.args.registration;
        if (registration != null) {
          await widget.auth.register(
            registrationToken: result.registrationToken!,
            name: registration.name,
            email: registration.email,
          );
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              RouteNames.home,
              (route) => false,
            );
          }
        } else {
          await Navigator.of(context).pushNamed(
            RouteNames.register,
            arguments: CustomerRegistrationArgs(
              phone: widget.args.phone,
              registrationToken: result.registrationToken,
            ),
          );
        }
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.home,
        (route) => false,
      );
    } on MobileApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to verify the code: $error');
    }
  }

  Future<void> _resend() async {
    if (_remaining != 0) return;
    try {
      await widget.auth.resendOtp(widget.args.challengeId);
      if (!mounted) return;
      _code.clear();
      setState(() => _error = null);
      _startCooldown();
    } on MobileApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to resend the code: $error');
    }
  }

  Widget _codeBoxes() => LayoutBuilder(
    builder: (context, constraints) {
      final code = _code.text;
      return SizedBox(
        height: 48,
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final value = index < code.length ? code[index] : '';
                final isActive = index == code.length && code.length < 6;
                return Container(
                  width: (constraints.maxWidth - 35) / 6,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: isActive ? PinkoraBrand.rose : PinkoraBrand.line,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: PinkoraBrand.charcoal,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _codeFocus.requestFocus,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: Semantics(
                  label: '6-digit verification code',
                  child: TextField(
                    key: const ValueKey('otp-input'),
                    controller: _code,
                    focusNode: _codeFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    showCursor: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      counterText: '',
                      isCollapsed: true,
                    ),
                    onSubmitted: (_) => _verify(),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  @override
  void dispose() {
    _cooldown?.cancel();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PinkoraBrand.ivory,
    appBar: AppBar(
      backgroundColor: PinkoraBrand.ivory,
      elevation: 0,
      title: const Text(
        'Verify mobile number',
        style: TextStyle(
          color: PinkoraBrand.charcoal,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Center(
              child: Image.asset(
                AppAssets.customerOtpHero,
                width: 190,
                height: 158,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'One step closer',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF5B092D),
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Enter the 6-digit code sent to\n+91 ${widget.args.phone}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PinkoraBrand.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'VERIFICATION CODE',
              style: TextStyle(
                color: Color(0xFF5B092D),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _codeBoxes(),
            if (_error != null) ...[
              const SizedBox(height: 7),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [PinkoraBrand.rose, PinkoraBrand.berry],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x338D214D),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Verify & Continue',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 17),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _remaining == 0 ? _resend : null,
              child: const Text(
                'Resend code',
                style: TextStyle(
                  color: Color(0xFFB00045),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _remaining > 0 ? 'Resend available in ${_remaining}s' : '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PinkoraBrand.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );
}
