import '../widgets/worker_legal_screen.dart';
import '../widgets/worker_auth_visuals.dart';
import '../../integration/worker_api.dart';
import '../../integration/worker_mobile_auth_api.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/slide_page_route.dart';
import '../registration/screens/worker_account_registration_screen.dart';
import '../otp/worker_otp_screen.dart';
import '../widgets/worker_login_footer.dart';

const _plum = Color(0xFF210B35);
const _berry = Color(0xFFFF1678);
const _muted = Color(0xFF686080);
const _line = Color(0xFFFFCEE0);
const _ivory = Color(0xFFFFF8FB);

class WorkerLoginScreen extends StatefulWidget {
  const WorkerLoginScreen({super.key, this.authApi});

  final WorkerAuthApi? authApi;

  @override
  State<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends State<WorkerLoginScreen> {
  final TextEditingController _phone = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _error;
  bool _loading = false;

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
    setState(() {
      _error = null;
      _loading = true;
    });
    final auth = widget.authApi ?? WorkerMobileAuthApi();
    try {
      await auth.requestOtp(phone);
      if (!mounted) return;
      await Navigator.of(context).push(
        SlidePageRoute<void>(
          page: WorkerOtpScreen(phone: phone, authApi: auth),
        ),
      );
    } on WorkerAuthException catch (error) {
      if (error.code == 'REGISTRATION_REQUIRED' && mounted) {
        await Navigator.of(context).push(
          SlidePageRoute<void>(
            page: WorkerAccountRegistrationScreen(phone: phone, authApi: auth),
          ),
        );
      } else if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          const ColoredBox(color: Colors.white),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.30, 0.48, 0.66, 1.0],
                colors: [
                  Color(0x00FFFFFF),
                  Color(0x00FFFFFF),
                  Color(0x22FFFFFF),
                  Color(0xF2FFF9FC),
                  Color(0xFFFFFAFC),
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

                final horizontalPadding = width < 340 ? 18.0 : 22.0;
                final heroHeight = keyboardOpen
                    ? 100.0
                    : (constraints.maxHeight * .20)
                          .clamp(110.0, 170.0)
                          .toDouble();

                return SingleChildScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                            const Center(child: WorkerAuthBrand()),
                            const SizedBox(height: 12),
                            WorkerAuthHero(height: heroHeight, phone: true),
                            const SizedBox(height: 10),
                            const Text(
                              'Welcome Back',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _plum,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Beauty Professional',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 18,
                                color: _muted,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Sign in to manage your bookings,\nearnings and grow with Hi Beauty.',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: keyboardOpen ? 12 : 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xEDFFF0F6),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14F52D7A),
                                    blurRadius: 20,
                                    offset: Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Mobile number',
                                    style: TextStyle(
                                      color: _plum,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.6,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  SizedBox(
                                    height: 64,
                                    child: TextField(
                                      key: const Key('worker-phone'),
                                      controller: _phone,
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.done,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      style: const TextStyle(
                                        color: _plum,
                                        fontSize: 16,
                                      ),
                                      onChanged: (_) {
                                        if (_error != null)
                                          setState(() => _error = null);
                                      },
                                      onSubmitted: (_) => _continue(),
                                      decoration: InputDecoration(
                                        hintText: 'Enter mobile number',
                                        hintStyle: const TextStyle(
                                          fontSize: 13,
                                        ),
                                        prefixIconConstraints:
                                            const BoxConstraints(minWidth: 100),
                                        prefixIcon: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'IN',
                                                style: TextStyle(fontSize: 18),
                                              ),
                                              SizedBox(width: 7),
                                              Text(
                                                '+91',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: _plum,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(
                                          alpha: 0.94,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 20,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _line,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _berry,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFB3261E),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 52,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF4B91),
                                            Color(0xFFFF1678),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x268B174A),
                                            blurRadius: 12,
                                            offset: Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: FilledButton(
                                        key: const Key('worker-continue'),
                                        onPressed: _loading ? null : _continue,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          disabledBackgroundColor:
                                              Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: _loading
                                            ? const SizedBox.square(
                                                dimension: 19,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Send OTP',
                                                    style: TextStyle(
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            WorkerLoginFooter(
                              onGoogle: null,
                              onApple: null,
                              onRegister: () {
                                final phone = _phone.text.trim();
                                if (phone.isEmpty) {
                                  setState(
                                    () => _error =
                                        'Enter your 10-digit mobile number to register as a partner.',
                                  );
                                  return;
                                }
                                _continue();
                              },
                              onTerms: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const WorkerLegalScreen(),
                                ),
                              ),
                              onPrivacy: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const WorkerLegalScreen(),
                                ),
                              ),
                            ),
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
