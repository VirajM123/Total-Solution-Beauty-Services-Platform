import '../../integration/worker_api.dart';
import '../../integration/worker_environment.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../registration/screens/worker_personal_details_screen.dart';
import '../../app/slide_page_route.dart';
import '../otp/worker_otp_screen.dart';
import '../widgets/worker_login_footer.dart';

const _plum = Color(0xFF460621);
const _berry = Color(0xFFB20A50);
const _muted = Color(0xFF624352);
const _line = Color(0xFFE8C9CE);
const _ivory = Color(0xFFFFF9F5);

class WorkerLoginScreen extends StatefulWidget {
  const WorkerLoginScreen({super.key, required this.demoEnabled});

  final bool demoEnabled;

  @override
  State<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends State<WorkerLoginScreen> {
  final TextEditingController _phone = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _error;
  bool _loading = false;

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_loading) return;
    final phone = _phone.text.trim();
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit Indian mobile number.');
      return;
    }
    if (!widget.demoEnabled || !WorkerEnvironment.developmentPreview) {
      try {
        await const PendingWorkerApi().requestOtp(phone);
      } on WorkerIntegrationPending catch (error) {
        if (mounted) setState(() => _error = error.toString());
      }
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _loading = false);
    await Navigator.of(context).push(
      SlidePageRoute<void>(page: WorkerOtpScreen(phone: phone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: _ivory,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The picture is OUTSIDE the scroll view, so it stays stationary.
          Image.asset(
            'assets/images/backgrounds/worker_login_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => const ColoredBox(color: _ivory),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.30, 0.48, 0.66, 1.0],
colors: [
  Color(0x18FFF9F5),
  Color(0x35FFF9F5),
  Color(0xD9FFF9F5),
  Color(0xFAFFF9F5),
  Color(0xF5FFF9F5),
],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // All children have natural heights; none is cut off by a
                // fixed-size Stack or a disabled scroll view.
                final width = math.min(constraints.maxWidth, 420.0);
                final compact = constraints.maxHeight < 740;
                final horizontalPadding = width < 340 ? 18.0 : 22.0;
             final heroHeight = keyboardOpen
    ? 145.0
    : (constraints.maxHeight * (compact ? 0.23 : 0.25))
        .clamp(165.0, 225.0)
        .toDouble();

                return SingleChildScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: 420,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: heroHeight,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Image.asset(
                                    'assets/images/logo/logo.png',
                                    width: keyboardOpen ? 88 : 108,
                                    height: keyboardOpen ? 88 : 108,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'Hi Beauty',
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.spa_rounded,
                                      color: _berry,
                                      size: 43,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'BEAUTY PROFESSIONALS',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _muted,
                                fontSize: 11,
letterSpacing: 1.3,
fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      border: Border.all(color: _line),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Text(
                                      'PARTNER ACCESS',
                                      style: TextStyle(
                                        fontSize: 9,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.bold,
                                        color: _berry,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'Welcome, Partner',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 31,
                                fontWeight: FontWeight.bold,
                                color: _plum,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                            'Your services. Your schedule. Your success.',
textAlign: TextAlign.center,
style: TextStyle(
  fontSize: 13,
  color: _muted,
  fontWeight: FontWeight.w500,
  height: 1.4,
),
                            ),
                            SizedBox(height: compact ? 18 : 23),
                            const Text(
                              'REGISTERED MOBILE NUMBER',
                              style: TextStyle(
                                color: _plum,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 7),
                            SizedBox(
                              height: 50,
                              child: TextField(
                                key: const Key('worker-phone'),
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                style: const TextStyle(color: _plum, fontSize: 15),
                                onChanged: (_) {
                                  if (_error != null) setState(() => _error = null);
                                },
                                onSubmitted: (_) => _continue(),
                                decoration: InputDecoration(
                                  hintText: 'Enter mobile number',
                                  hintStyle: const TextStyle(fontSize: 13),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 100),
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                        SizedBox(width: 7),
                                        Text('+91', style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _plum,
                                        )),
                                      ],
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.94),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: _line),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: _berry, width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(_error!, style: const TextStyle(
                                color: Color(0xFFB3261E), fontSize: 12,
                              )),
                            ],
                            const SizedBox(height: 15),
                            SizedBox(
                              height: 49,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFFD41361), Color(0xFF750034),
                                  ]),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: const [BoxShadow(
                                    color: Color(0x268B174A),
                                    blurRadius: 12,
                                    offset: Offset(0, 5),
                                  )],
                                ),
                                child: FilledButton(
                                  key: const Key('worker-continue'),
                                  onPressed: _loading ? null : _continue,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox.square(
                                          dimension: 19,
                                          child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Continue', style: TextStyle(
                                              fontFamily: 'Georgia', fontSize: 18,
                                            )),
                                            SizedBox(width: 10),
                                            Icon(Icons.arrow_forward_rounded, size: 20),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 17),
                            WorkerLoginFooter(
                              onGoogle: () => _comingSoon('Google sign-in'),
                              onApple: () => _comingSoon('Apple sign-in'),
                           onRegister: () {
  if (!WorkerEnvironment.developmentPreview) {
    setState(() => _error = 'Registration requires worker OTP, private document upload and application APIs.');
    return;
  }
  Navigator.of(context).push(
    SlidePageRoute<void>(
      page: WorkerPersonalDetailsScreen(
        initialMobile: _phone.text.trim(),
      ),
    ),
  );
},
                              onTerms: () => _comingSoon('Terms of service'),
                              onPrivacy: () => _comingSoon('Privacy policy'),
                            ),
                            if (widget.demoEnabled) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'DEVELOPMENT PREVIEW • NO SMS IS SENT',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 0.2,
                                  color: _berry,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
}
