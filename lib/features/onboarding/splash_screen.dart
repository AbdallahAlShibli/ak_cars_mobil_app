import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) context.go('/onboarding');
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.splashTop, AppColors.brandDark],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.directions_car_filled_rounded,
                        size: 52, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'AK Cars',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Services · Parts · Cars',
                    style: TextStyle(fontSize: 14, color: Color(0xFFA9BDF3)),
                  ),
                  const Text(
                    'خدمات · قطع غيار · سيارات',
                    style: TextStyle(fontSize: 14, color: Color(0xFFA9BDF3)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
