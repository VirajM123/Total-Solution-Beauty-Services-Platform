import 'package:flutter/material.dart';

import '../../integration/worker_api.dart';
import '../../integration/worker_mobile_auth_api.dart';
import '../home/worker_home_screen.dart';
import '../login/worker_login_screen.dart';

class WorkerSplashScreen extends StatefulWidget {
  const WorkerSplashScreen({super.key, required this.demoEnabled});

  final bool demoEnabled;

  @override
  State<WorkerSplashScreen> createState() => _WorkerSplashScreenState();
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
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _imageScale = Tween<double>(
      begin: 1.08,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _brandFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );

    _brandSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
          ),
        );

    _startSplash();
  }

  Future<void> _startSplash() async {
    await _controller.forward();

    await Future<void>.delayed(const Duration(milliseconds: 500));

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
          return WorkerLoginScreen(demoEnabled: widget.demoEnabled);
        },
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
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
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
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
              'assets/images/backgrounds/worker_auth_petals.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(color: Color(0xFFFFF0F4));
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
                  Color(0x22FFF9F5),
                  Color(0xFFFFF8FB),
                ],
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 620;

                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: constraints.maxWidth < 390
                        ? 390
                        : constraints.maxWidth,
                    height: constraints.maxHeight < 900
                        ? 900
                        : constraints.maxHeight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: compact ? 16 : 28,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),

                          FadeTransition(
                            opacity: _brandFade,
                            child: SlideTransition(
                              position: _brandSlide,
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/images/logo/logo.png',
                                    width: compact ? 210 : 245,
                                    height: compact ? 140 : 165,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'Hi Beauty',
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.spa_rounded,
                                      color: Color(0xFFF52D7A),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  const Text(
                                    'BEAUTY PROFESSIONAL APP',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      letterSpacing: 2.4,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF735A67),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  const Text(
                                    'Beauty for a Brighter You',
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

                          const SizedBox(height: 25),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: 0.55,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Skills\nCreate\nBeautiful\nLives',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 29,
                                      height: 1.08,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF210B35),
                                    ),
                                  ),
                                  SizedBox(height: 15),
                                  SizedBox(
                                    width: 32,
                                    child: Divider(
                                      color: Color(0xFFFF3989),
                                      thickness: 2,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Manage bookings, grow your business and make more women feel beautiful.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.6,
                                      color: Color(0xFF686080),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Row(
                            children: [
                              _SplashBenefit(
                                icon: Icons.calendar_month_outlined,
                                label: 'Get More\nBookings',
                              ),
                              SizedBox(width: 8),
                              _SplashBenefit(
                                icon: Icons.bar_chart_rounded,
                                label: 'Track Your\nEarnings',
                              ),
                              SizedBox(width: 8),
                              _SplashBenefit(
                                icon: Icons.person_outline_rounded,
                                label: 'Build Your\nBrand',
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF52D7A),
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

class _SplashBenefit extends StatelessWidget {
  const _SplashBenefit({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0FFF3989),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFFE6F1),
            foregroundColor: const Color(0xFFFF1680),
            child: Icon(icon, size: 24),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Color(0xFF210B35),
            ),
          ),
        ],
      ),
    ),
  );
}
