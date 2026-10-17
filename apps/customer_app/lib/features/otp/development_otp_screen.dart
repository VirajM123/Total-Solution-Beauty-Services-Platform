import 'dart:async';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/route_names.dart';
import '../../core/constants/pinkora_brand.dart';
import '../shared/brand_mark.dart';

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

  @override
  void dispose() {
    _cooldown?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Development OTP')),
    body: BeautyPage(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: BrandMark(compact: true)),
            const SizedBox(height: 28),
            Text(
              'Verify mobile number',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: PinkoraBrand.charcoal,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.registration == null
                  ? 'Development sign in for +91 ${widget.phone}'
                  : 'Development registration for ${widget.registration!.name} (+91 ${widget.phone})',
              style: const TextStyle(color: BeautyColors.muted),
            ),
            const SizedBox(height: 24),
            const BeautyCard(
              child: Text(
                'Mock code: 123456. This does not sign you in or create an account.',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(letterSpacing: 12, fontSize: 24),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: '6-digit development code',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 18),
            BeautyButton(label: 'Verify mock code', onPressed: _verify),
            TextButton(
              onPressed: _remaining == 0
                  ? () {
                      _code.clear();
                      _startCooldown();
                    }
                  : null,
              child: Text(
                _remaining == 0
                    ? 'Resend mock code'
                    : 'Resend in ${_remaining}s',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
