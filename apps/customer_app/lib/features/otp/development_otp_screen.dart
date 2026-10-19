import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/route_names.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';

/// Exists only in the navigation stack while exercising the debug UI flow.
class DevelopmentRegistration {
  const DevelopmentRegistration({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// Local UI exercise only. This code never calls an auth service or creates a session.
class DevelopmentOtpScreen extends StatefulWidget {
  const DevelopmentOtpScreen({
    super.key,
    required this.phone,
    this.registration,
  });

  final String phone;
  final DevelopmentRegistration? registration;

  @override
  State<DevelopmentOtpScreen> createState() => _DevelopmentOtpScreenState();
}

class _DevelopmentOtpScreenState extends State<DevelopmentOtpScreen> {
  final _code = TextEditingController();
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

  void _verify() {
    if (_code.text != '123456') {
      setState(() => _error = 'Incorrect development code. Use 123456.');
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
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
              child: Semantics(
                label: '6-digit verification code',
                child: TextField(
                  key: const ValueKey('otp-input'),
                  controller: _code,
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
          ],
        ),
      );
    },
  );

  @override
  void dispose() {
    _cooldown?.cancel();
    _code.dispose();
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
              'Enter the 6-digit development code for\n+91 ${widget.phone}',
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
              onPressed: _remaining == 0
                  ? () {
                      _code.clear();
                      _startCooldown();
                    }
                  : null,
              child: const Text(
                'Restart demo timer',
                style: TextStyle(
                  color: Color(0xFFB00045),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: PinkoraBrand.line),
            const SizedBox(height: 8),
            Text(
              'DEVELOPMENT PREVIEW · CODE: 123456${_remaining > 0 ? ' · ${_remaining}s' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PinkoraBrand.muted,
                fontSize: 8,
                letterSpacing: .35,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No SMS is sent and no worker session is created.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PinkoraBrand.muted, fontSize: 8),
            ),
          ],
        ),
      ),
    ),
  );
}
