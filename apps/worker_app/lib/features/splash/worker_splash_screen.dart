
import 'package:flutter/material.dart';

import '../../integration/worker_api.dart';
import '../../integration/worker_mobile_auth_api.dart';
import '../home/worker_home_screen.dart';
import '../login/worker_login_screen.dart';

class WorkerSplashScreen extends StatefulWidget {
  const WorkerSplashScreen({
    super.key,
    required this.demoEnabled,
  });

  final bool demoEnabled;

  @override
  State<WorkerSplashScreen> createState() =>
      _WorkerSplashScreenState();
}

class _WorkerSplashScreenState extends State<WorkerSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _imageFade;
  late final Animation<double> _imageScale;
  late final Animation<double> _brandFade;
  late final Animation<Offset> _brandSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _imageFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.0,
        0.55,
        curve: Curves.easeOut,
      ),
    );

    _imageScale = Tween<double>(
      begin: 1.08,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _brandFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.35,
        0.85,
        curve: Curves.easeOut,
      ),
    );

    _brandSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.35,
          0.85,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _startSplash();
  }

  Future<void> _startSplash() async {
    await _controller.forward();

    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) return;

    try {
      final auth = WorkerMobileAuthApi();
      final identity = await auth.currentIdentity();
      if (mounted && identity.approval == WorkerApproval.approved) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, animation, __) => FadeTransition(
              opacity: animation,
              child: const WorkerHomeScreen(demoMode: false),
            ),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }
    } catch (_) {
      // Session unavailable or unauthenticated -> proceed to login screen
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return WorkerLoginScreen(
            demoEnabled: widget.demoEnabled,
          );
        },
        transitionDuration:
            const Duration(milliseconds: 500),
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F5),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Premium splash portrait.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: reducedMotion ? 1 : _imageFade.value,
                child: Transform.scale(
                  scale: reducedMotion ? 1 : _imageScale.value,
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'assets/images/branding/'
              'worker_splash_beauty_portrait.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: Color(0xFFFFF0F4),
                );
              },
            ),
          ),

          // Soft gradient makes branding readable.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.35, 0.68, 1],
                colors: [
                  Color(0x12FFF9F5),
                  Color(0x00FFF9F5),
                  Color(0x99FFF9F5),
                  Color(0xFFFFF9F5),
                ],
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 620;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: compact ? 16 : 28,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 6),

                      FadeTransition(
                        opacity: _brandFade,
                        child: SlideTransition(
                          position: _brandSlide,
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/logo/logo.png',
                                width: compact ? 190 : 230,
                                height: compact ? 190 : 230,
                                fit: BoxFit.contain,
                                semanticLabel: 'Hi Beauty',
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.spa_rounded,
                                  color: Color(0xFFB20A50),
                                  size: 52,
                                ),
                              ),
                              const SizedBox(height: 18),

                              const Text(
                                'BEAUTY PROFESSIONALS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 2.4,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF735A67),
                                ),
                              ),

                              const SizedBox(height: 18),

                              const Text(
                                'Your services. Your success.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF735A67),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFB20A50),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'PREPARING YOUR WORKSPACE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.3,
                          color: Color(0xFF735A67),
                        ),
                      ),
                    ],
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
