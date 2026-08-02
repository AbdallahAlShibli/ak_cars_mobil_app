import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';

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
];

/// First-launch guide — step 2 of 3, shown once per install.
///
/// The slides parallax against each other rather than moving as one flat
/// page: the icon, the headline and the body travel at different rates, which
/// is what makes a three-card tour feel like an app rather than a slideshow.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  /// Live fractional position, so the parallax follows the finger during a
  /// drag instead of only snapping between pages.
  double get _scrollPosition {
    if (_controller.hasClients && _controller.position.haveDimensions) {
      return _controller.page ?? _page.toDouble();
    }
    return _page.toDouble();
  }

  void _finish() {
    ref.read(authProvider.notifier).markOnboardingSeen();
    context.go('/start-choice');
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
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
    final last = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Same progress language as the start-choice screen, so the
              // three first-launch screens read as one flow rather than three
              // unrelated pages.
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('الخطوة ٢ من ٣', 'Step 2 of 3'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: ak.inkSub,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 1; i <= 3; i++) ...[
                              if (i > 1) const SizedBox(width: 5),
                              Expanded(
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: i <= 2 ? ak.ink : ak.surfaceDim,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      s.t('تخطّي', 'Skip'),
                      style: TextStyle(
                        color: ak.inkSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _page = i);
                  },
                  itemBuilder: (context, i) => AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) =>
                        _SlideView(slide: _slides[i], delta: i - _scrollPosition),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
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
                onPressed: _next,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      axis: Axis.horizontal,
                      sizeFactor: animation,
                      alignment: Alignment.center,
                      child: child,
                    ),
                  ),
                  child: Row(
                    // Keyed so the switcher animates the label change instead
                    // of swapping it on a frame boundary.
                    key: ValueKey(last),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(last
                          ? s.t('ابدأ الآن', 'Get started')
                          : s.t('التالي', 'Next')),
                      const SizedBox(width: 8),
                      Icon(
                        last
                            ? LucideIcons.check
                            // Mirrors in Arabic — a fixed right arrow points
                            // back up the slide order in RTL.
                            : (Directionality.of(context) == TextDirection.rtl
                                ? LucideIcons.arrowLeft
                                : LucideIcons.arrowRight),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One slide, offset by how far it is from the viewport centre.
///
/// [delta] is 0 for the slide on screen, ±1 for its neighbours, and anything
/// in between mid-drag.
class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.delta});

  final _Slide slide;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final distance = delta.abs().clamp(0.0, 1.0);
    // Everything fades out well before the neighbour arrives, so two slides
    // are never both legible at once.
    final opacity = (1 - distance * 1.6).clamp(0.0, 1.0);

    Widget layer(double rate, Widget child) => Transform.translate(
          offset: Offset(delta * rate, 0),
          child: child,
        );

    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          layer(
            40,
            Transform.rotate(
              // A few degrees of tilt as it travels — reads as depth, not as
              // a spin.
              angle: delta * 0.06 * math.pi / 4,
              child: Transform.scale(
                scale: 1 - distance * 0.16,
                child: _IconTile(icon: slide.icon),
              ),
            ),
          ),
          const SizedBox(height: 28),
          layer(
            110,
            Text(
              slide.title.of(s),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: ak.ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          layer(
            170,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                slide.body.of(s),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: ak.inkSub, height: 1.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The slide's icon on a card, with the amber accent ring the rest of the app
/// uses for "this is the thing to look at".
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: ak.border),
        boxShadow: [
          BoxShadow(
            color: ak.ink.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: ak.amberBgSoft,
              shape: BoxShape.circle,
            ),
          ),
          Icon(icon, size: 60, color: ak.ink),
        ],
      ),
    );
  }
}
