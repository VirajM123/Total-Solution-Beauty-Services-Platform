import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/route_names.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';
import '../shared/auth_brand_mark.dart';

const _plum = PinkoraBrand.charcoal;
const _berry = PinkoraBrand.berry;
const _ivory = PinkoraBrand.ivory;
const _muted = PinkoraBrand.muted;
const _line = PinkoraBrand.line;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.config});
  final AppConfig config;

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
    if (!widget.config.mockAuthEnabled) {
      setState(() => _error = 'Sign in is unavailable in this build.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushNamed(RouteNames.otp, arguments: value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ivory,
    resizeToAvoidBottomInset: true,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          AppAssets.customerLoginHero,
          key: const ValueKey('customer-login-background'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
        ),
        Positioned(
          top: MediaQuery.sizeOf(context).height * .365,
          left: 12,
          right: 12,
          bottom: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFDFEF9F7), Color(0xF9FFF5F3)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x246C2940),
                  blurRadius: 30,
                  offset: Offset(0, 9),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The reference is 360 x 800. Keep its proportions on other phones;
              // when the keyboard opens, keep the original scale and scroll.
              final fullHeight =
                  constraints.maxHeight +
                  MediaQuery.viewInsetsOf(context).bottom;
              final scale = math
                  .min(constraints.maxWidth / 360, fullHeight / 800)
                  .clamp(0.78, 1.25);
              final shift = _error == null ? 0.0 : 23 * scale;
              final inset = 25 * scale;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: 800 * scale + shift,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 10 * scale,
                        left: 23 * scale,
                        child: Material(
                          color: Colors.white.withValues(alpha: .91),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              size: 21 * scale,
                            ),
                            constraints: BoxConstraints.tightFor(
                              width: 46 * scale,
                              height: 46 * scale,
                            ),
                            color: _berry,
                            tooltip: 'Back',
                          ),
                        ),
                      ),
                      Positioned(
                        top: 82 * scale,
                        left: 0,
                        right: 0,
                        child: const AuthBrandMark(),
                      ),
                      Positioned(
                        top: 319 * scale,
                        left: inset,
                        right: inset,
                        child: Text(
                          'Welcome back',
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          style: TextStyle(
                            color: _plum,
                            fontFamily: 'Montserrat',
                            fontSize: 30 * scale,
                            fontWeight: FontWeight.w700,
                            height: 1.06,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 368 * scale,
                        left: inset,
                        right: inset,
                        child: Text(
                          'Sign in to continue your beauty journey.',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 13 * scale,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 402 * scale,
                        left: inset,
                        right: inset,
                        child: SizedBox(
                          height: 54 * scale,
                          child: TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            style: TextStyle(
                              color: _plum,
                              fontSize: 14 * scale,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter mobile number',
                              hintStyle: TextStyle(
                                color: const Color(0xFF8D8084),
                                fontSize: 13 * scale,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14 * scale,
                                horizontal: 12 * scale,
                              ),
                              border: OutlineInputBorder(
                                borderSide: const BorderSide(color: _line),
                                borderRadius: BorderRadius.circular(12 * scale),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: _line),
                                borderRadius: BorderRadius.circular(12 * scale),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: _berry,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12 * scale),
                              ),
                              prefixIconConstraints: BoxConstraints(
                                minWidth: 126 * scale,
                                maxWidth: 126 * scale,
                              ),
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(
                                  left: 11 * scale,
                                  right: 5 * scale,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IndiaFlag(
                                      width: 22 * scale,
                                      height: 15 * scale,
                                    ),
                                    SizedBox(width: 8 * scale),
                                    Text(
                                      '+91',
                                      style: TextStyle(
                                        color: _plum,
                                        fontSize: 13 * scale,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 8 * scale),
                                    SizedBox(
                                      height: 20 * scale,
                                      child: const VerticalDivider(
                                        width: 1,
                                        color: _line,
                                      ),
                                    ),
                                    SizedBox(width: 8 * scale),
                                    Icon(
                                      Icons.phone_outlined,
                                      color: _muted,
                                      size: 17 * scale,
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
                        ),
                      ),
                      if (_error != null)
                        Positioned(
                          top: 457 * scale,
                          left: inset,
                          right: inset,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: const Color(0xFFB3261E),
                              fontSize: 11 * scale,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 468 * scale + shift,
                        left: inset,
                        right: inset,
                        child: SizedBox(
                          height: 51 * scale,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [PinkoraBrand.rose, PinkoraBrand.berry],
                              ),
                              borderRadius: BorderRadius.circular(30 * scale),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x268B174A),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: FilledButton(
                              onPressed: _loading ? null : _sendOtp,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    30 * scale,
                                  ),
                                ),
                              ),
                              child: _loading
                                  ? SizedBox.square(
                                      dimension: 20 * scale,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Continue',
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 19 * scale,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 12 * scale),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 22 * scale,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 542 * scale + shift,
                        left: inset,
                        right: inset,
                        child: Row(
                          children: [
                            const Expanded(child: Divider(color: _line)),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * scale,
                              ),
                              child: Text(
                                'or continue with',
                                style: TextStyle(
                                  color: _muted,
                                  fontFamily: 'Montserrat',
                                  fontSize: 13 * scale,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: _line)),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 567 * scale + shift,
                        left: inset,
                        right: inset,
                        child: _SocialSignIn(
                          scale: scale,
                          label: 'Continue with Google',
                          icon: _GoogleIcon(size: 22 * scale),
                          onPressed: null,
                        ),
                      ),
                      Positioned(
                        top: 621 * scale + shift,
                        left: inset,
                        right: inset,
                        child: _SocialSignIn(
                          scale: scale,
                          label: 'Continue with Apple',
                          icon: FaIcon(
                            FontAwesomeIcons.apple,
                            size: 23 * scale,
                            color: const Color(0xFF241329),
                          ),
                          onPressed: null,
                        ),
                      ),
                      Positioned(
                        top: 686 * scale + shift,
                        left: inset,
                        right: inset,
                        child: Text.rich(
                          const TextSpan(
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
                            fontFamily: 'Montserrat',
                            fontSize: 10 * scale,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 727 * scale + shift,
                        left: inset,
                        right: inset,
                        child: TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed(RouteNames.register),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: const [
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
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 13 * scale,
                                  ),
                                ),
                                SizedBox(width: 6 * scale),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: _berry,
                                  size: 17 * scale,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
    height: 46 * scale,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _plum,
        backgroundColor: Colors.white.withValues(alpha: 0.62),
        padding: EdgeInsets.symmetric(horizontal: 8 * scale),
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28 * scale),
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
                fontFamily: 'Montserrat',
                fontSize: 17 * scale,
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
