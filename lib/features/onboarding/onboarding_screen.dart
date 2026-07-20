import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/app_state.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);

  final IconData icon;
  final L title;
  final L body;
}

const _slides = [
  _Slide(
    LucideIcons.wrench,
    L('ورش موثوقة،\nبضغطة واحدة', 'Trusted workshops,\none tap away'),
    L(
      'قارن مزودي الخدمة الموثّقين القريبين منك، واعتمد عروض أسعار حقيقية، وتابع كل خطوة من العمل مباشرة.',
      'Compare verified providers near you, approve real quotes, and track every step of the work — live.',
    ),
  ),
  _Slide(
    LucideIcons.shoppingBag,
    L('قطع مناسبة،\nتوصلك حيث أنت', 'Parts that fit,\ndelivered right'),
    L(
      'تسوّق قطع الغيار لسيارتك — أو لأي سيارة — مع فلاتر للفئة والمزوّد والسعر والمنطقة.',
      'Shop parts for your car — or any car — with filters for category, provider, price, and region.',
    ),
  ),
  _Slide(
    LucideIcons.car,
    L('بِع واشترِ السيارات\nبثقة', 'Buy & sell cars\nwith confidence'),
    L(
      'تصفّح الإعلانات في كل عُمان، واحفظ المفضلة، وانشر إعلانك في دقائق.',
      'Browse listings across Oman, save favorites, and post your own ad in minutes.',
    ),
  ),
];

/// First-launch guide — Sand & Ink restyle of the original slides.
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
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    s.t('تخطّي', 'Skip'),
                    style: TextStyle(
                      color: ak.inkSub,
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
                    final slide = _slides[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            color: ak.surface,
                            borderRadius: BorderRadius.circular(48),
                            border: Border.all(color: ak.border),
                          ),
                          child: Icon(slide.icon, size: 64, color: ak.ink),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          slide.title.of(s),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            slide.body.of(s),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: ak.inkSub,
                              height: 1.7,
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
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? ak.ink : ak.inkFaint,
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
                child: Text(_page == _slides.length - 1
                    ? s.t('ابدأ الآن', 'Get started')
                    : s.t('التالي', 'Next')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
