import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_state.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body, this.badge);
  final IconData icon;
  final String title;
  final String body;
  final IconData badge;
}

const _slides = [
  _Slide(
    Icons.build_rounded,
    'Trusted workshops,\none tap away',
    'Compare verified providers near you, approve real quotes, and track every step of the work — live.',
    Icons.verified_rounded,
  ),
  _Slide(
    Icons.settings_rounded,
    'Parts that fit,\ndelivered right',
    'Shop parts for your car — or any car — with filters for category, provider, price, and region.',
    Icons.local_shipping_rounded,
  ),
  _Slide(
    Icons.sell_rounded,
    'Buy & sell cars\nwith confidence',
    'Browse listings across Oman, save favorites, and post your own ad in minutes.',
    Icons.favorite_rounded,
  ),
];

/// First-launch guide (rule 2) — shown once, skippable.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  void _finish() {
    ref.read(authProvider.notifier).markOnboardingSeen();
    context.go('/start-choice');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.ink2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                color: AppColors.brandSoft,
                                borderRadius: BorderRadius.circular(48),
                              ),
                              child: Icon(s.icon,
                                  size: 74, color: AppColors.brand),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.goodSoft,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.bg, width: 4),
                                ),
                                child: Icon(s.badge,
                                    size: 20, color: AppColors.good),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            s.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.ink2,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.brand
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (_page == _slides.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Text(
                    _page == _slides.length - 1 ? 'Get started' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
