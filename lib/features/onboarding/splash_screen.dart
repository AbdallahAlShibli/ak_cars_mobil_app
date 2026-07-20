import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/car_media.dart';

/// Splash (handoff #3a) — calm cream screen with soft decorative circles,
/// the AK mark in an ink square, a car photo, page dots and the
/// "Start the journey" ink pill. Quiet fade/slide entrance, no neon.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      body: Stack(
        children: [
          // Soft decorative circles.
          PositionedDirectional(
            top: 130,
            end: -70,
            child: Container(
              width: 230,
              height: 230,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF3E3C6),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 180,
            start: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEFE9DE),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(fade),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1B17),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x381D1B17),
                            blurRadius: 40,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'AK',
                          style: GoogleFonts.chakraPetch(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF6F3EE),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AK Cars',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFF1D1B17),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.t('كل ما تحتاجه سيارتك… في مكان واحد',
                          'Everything your car needs… in one place'),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF8B857A)),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      width: 230,
                      height: 120,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7DC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const CarImage(
                          make: 'Toyota', model: 'Land Cruiser', height: 120),
                    ),
                    const Spacer(flex: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1B17),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 7),
                        _dot(),
                        const SizedBox(width: 7),
                        _dot(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => context.go('/onboarding'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 52, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1B17),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x401D1B17),
                              blurRadius: 30,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Text(
                          s.t('ابدأ الرحلة', 'Start the journey'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF6F3EE),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: s.t('لديك حساب؟ ', 'Have an account? ')),
                          TextSpan(
                            text: s.t('تسجيل الدخول', 'Sign in'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D1B17),
                            ),
                          ),
                        ]),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8B857A)),
                      ),
                    ),
                    const SizedBox(height: 34),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFD8D1C4),
        ),
      );
}
