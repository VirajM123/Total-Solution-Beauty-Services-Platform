import '../shared/customer_refinements.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/route_names.dart';
import '../../core/api/mobile_api.dart';
import '../../core/config/app_config.dart';
import '../shared/customer_visuals.dart';
import '../../core/constants/pinkora_brand.dart';
import '../../integration/customer_auth_api.dart';
import '../shared/auth_brand_mark.dart';
import '../otp/development_otp_screen.dart';

const _plum = PinkoraBrand.charcoal;
const _berry = PinkoraBrand.berry;
const _ivory = PinkoraBrand.ivory;
const _muted = PinkoraBrand.muted;
const _line = PinkoraBrand.line;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.config, this.authApi});
  final AppConfig config;
  final CustomerAuthApi? authApi;
  CustomerAuthApi get auth =>
      authApi ?? CustomerAuthApi(api: MobileApi(baseUrl: config.apiBaseUrl));

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_loading) return;
    final value = _phone.text.trim();
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
      setState(() => _error = 'Enter a valid 10-digit Indian mobile number.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final request = await widget.auth.requestLoginOtp(value);
      if (!mounted) return;
      if (request.registrationRequired) {
        setState(() => _loading = false);
        await Navigator.of(context).pushNamed(
          RouteNames.register,
          arguments: CustomerRegistrationArgs(phone: value),
        );
        return;
      }
      final challengeId = request.challengeId;
      if (challengeId == null) {
        throw const MobileApiException(
          'INVALID_RESPONSE',
          'Missing OTP challenge.',
        );
      }
      setState(() => _loading = false);
      await Navigator.of(context).pushNamed(
        RouteNames.otp,
        arguments: CustomerOtpRouteArgs(phone: value, challengeId: challengeId),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _devBypass() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.devBypassLogin();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: CustomerRefinements.theme(Theme.of(context)),
    child: Scaffold(
      backgroundColor: _ivory,
      resizeToAvoidBottomInset: true,
      body: CustomerCanvas(
        compact: true,
        key: const ValueKey('customer-login-background'),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    minHeight: (constraints.maxHeight - 32).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            tooltip: 'Back',
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                            ),
                          ),
                        ),
                        const Center(child: AuthBrandMark()),
                        const SizedBox(height: 12),
                        const Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _berry,
                            fontSize: 34,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to continue your beauty journey.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Mobile Number',
                          style: TextStyle(
                            color: _plum,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Enter mobile number',
                            prefixIcon: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IndiaFlag(width: 22, height: 15),
                                  SizedBox(width: 10),
                                  Text(
                                    '+91',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  SizedBox(
                                    height: 20,
                                    child: VerticalDivider(
                                      width: 1,
                                      color: _line,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) => _sendOtp(),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFB3261E),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _loading ? null : _sendOtp,
                          child: _loading
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
                                    Text('Continue'),
                                    SizedBox(width: 12),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                        ),
                        if (CustomerRefinements.showDevelopmentControls) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const ValueKey('customer-dev-bypass-button'),
                            onPressed: _loading ? null : _devBypass,
                            icon: const Icon(Icons.flash_on_rounded, size: 18),
                            label: const Text(
                              'Fast Test: Dev Bypass (Omkar Bhange)',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider(color: _line)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or continue with',
                                style: TextStyle(color: _muted, fontSize: 12),
                              ),
                            ),
                            Expanded(child: Divider(color: _line)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SocialSignIn(
                          scale: 1,
                          label: 'Continue with Google',
                          icon: _GoogleIcon(size: 22),
                          onPressed: null,
                        ),
                        const SizedBox(height: 10),
                        _SocialSignIn(
                          scale: 1,
                          label: 'Continue with Apple',
                          icon: const FaIcon(
                            FontAwesomeIcons.apple,
                            size: 23,
                            color: _plum,
                          ),
                          onPressed: null,
                        ),
                        const SizedBox(height: 16),
                        const Spacer(),
                        const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'By continuing, you agree to our\n',
                              ),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: _berry,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: _berry,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(RouteNames.catalog),
                          child: const Text('Browse services'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(RouteNames.register),
                          child: const Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'New here?  ',
                                  style: TextStyle(color: _muted),
                                ),
                                TextSpan(
                                  text: 'Create an account',
                                  style: TextStyle(
                                    color: _berry,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SocialSignIn extends StatelessWidget {
  const _SocialSignIn({
    required this.scale,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final double scale;
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52 * scale,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _plum,
        backgroundColor: Colors.white.withValues(alpha: 0.62),
        padding: EdgeInsets.symmetric(horizontal: 8 * scale),
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14 * scale),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(width: 14 * scale),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF28152B),
                fontFamily: CustomerRefinements.fontFamily,
                fontSize: 16 * scale,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class IndiaFlag extends StatelessWidget {
  const IndiaFlag({super.key, required this.width, required this.height});
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, height), painter: _IndiaFlagPainter());
}

class _IndiaFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final third = size.height / 3;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, third),
      Paint()..color = const Color(0xFFFF9933),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, third, size.width, third),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, third * 2, size.width, third),
      Paint()..color = const Color(0xFF138808),
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.height * 0.12,
      Paint()
        ..color = const Color(0xFF000080)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.height * 0.045),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width * 0.39);
    final stroke = size.width * 0.22;
    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }

    arc(const Color(0xFF4285F4), -0.18, 1.15);
    arc(const Color(0xFF34A853), 0.97, 1.33);
    arc(const Color(0xFFFBBC05), 2.30, 0.75);
    arc(const Color(0xFFEA4335), 3.05, 1.87);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.43,
        size.width * 0.42,
        stroke,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
