import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../state/app_state.dart';
import 'intro_content.dart';

/// First-launch guide — step 2 of 3, shown once per install.
///
/// The slides parallax against each other rather than moving as one flat
/// page: the icon, the headline, the body and the chips travel at different
/// rates, which is what makes a short tour feel like an app rather than a
/// slideshow.
///
/// The slides themselves come from [introSlides], not from a list held here,
/// so the tour can only ever promise pillars this build actually ships — see
/// `intro_content.dart` for the mis-sold parts store that forced that.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  final _slides = introSlides();
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

  /// Tapping a dot is the cheapest way back to a slide someone wants to
  /// re-read — without it the only way back is a drag most people never try
  /// on a screen they expect to run one way.
  void _goTo(int i) {
    if (i == _page) return;
    HapticFeedback.selectionClick();
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
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
          padding: const EdgeInsets.all(AppSpacing.xl - 4),
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
                        const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(width: AppSpacing.md),
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
                    builder: (context, _) => _SlideView(
                      slide: _slides[i],
                      delta: i - _scrollPosition,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return GestureDetector(
                    onTap: () => _goTo(i),
                    behavior: HitTestBehavior.opaque,
                    // A 7px dot is far below the minimum touch target, so the
                    // padding — not the dot — is what the finger hits.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3.5,
                        vertical: AppSpacing.md,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active ? ak.ink : ak.inkFaint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.xs),
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
                      Text(
                        last
                            ? s.t('ابدأ الآن', 'Get started')
                            : s.t('التالي', 'Next'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
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

  final IntroSlide slide;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final distance = delta.abs().clamp(0.0, 1.0);
    // Everything fades out well before the neighbour arrives, so two slides
    // are never both legible at once.
    final opacity = (1 - distance * 1.6).clamp(0.0, 1.0);

    Widget layer(double rate, Widget child) =>
        Transform.translate(offset: Offset(delta * rate, 0), child: child);

    // Fades are applied straight to each leaf's own colour below, rather than
    // wrapping this whole multi-widget column in an `Opacity` — no image here
    // either, just tinted shapes and text, so there's nothing a saveLayer
    // buys us.
    //
    // Scrollable because the tallest slide (three lines of Arabic body copy
    // plus a chip row that wraps) does not fit a short phone at large text
    // scales, and a tour that overflows on the way in is worse than one that
    // scrolls.
    return SingleChildScrollView(
      child: ConstrainedBox(
        // Keeps the column optically centred on a roomy screen while still
        // letting it grow past the viewport on a cramped one.
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            layer(
              40,
              Transform.rotate(
                // A few degrees of tilt as it travels — reads as depth, not
                // as a spin.
                angle: delta * 0.06 * math.pi / 4,
                child: Transform.scale(
                  scale: 1 - distance * 0.16,
                  child: _IconTile(icon: slide.icon, fade: opacity),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            layer(
              110,
              Text(
                slide.title.of(s),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: ak.ink.withValues(alpha: opacity),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            layer(
              170,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl - 4,
                ),
                child: Text(
                  slide.body.of(s),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: ak.inkSub.withValues(alpha: opacity),
                    height: 1.7,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg + 2),
            // The proof row. A paragraph is a promise; these are the three
            // specific things the promise is made of, and they are what a
            // user skimming the tour in four seconds actually reads.
            layer(
              230,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: [
                    for (final chip in slide.chips)
                      _ProofChip(label: chip.of(s), fade: opacity),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single named capability on a slide — tick + two or three words.
class _ProofChip extends StatelessWidget {
  const _ProofChip({required this.label, required this.fade});

  final String label;

  /// Slide-transition fade — see [_SlideView] for why it is not an [Opacity].
  final double fade;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: ak.surface.withValues(alpha: fade),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ak.border.withValues(alpha: fade)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.check,
            size: 12,
            color: ak.success.withValues(alpha: fade),
          ),
          const SizedBox(width: 6),
          // Flexible, because the chips are sized by their own content inside
          // a Wrap: the longest Arabic label ("قطعة وأجرة منفصلتان") is 2.5px
          // wider than a 320pt screen allows, and a chip that cannot give is
          // a chip that overflows rather than wrapping onto its own line.
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ak.ink.withValues(alpha: fade),
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
  const _IconTile({required this.icon, this.fade = 1});

  final IconData icon;

  /// Slide-transition fade, applied to each colour directly — see
  /// [_SlideView]'s build for why this isn't an [Opacity] wrapper.
  final double fade;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: ak.surface.withValues(alpha: fade),
        borderRadius: BorderRadius.circular(44),
        border: Border.all(color: ak.border.withValues(alpha: fade)),
        boxShadow: [
          BoxShadow(
            color: ak.ink.withValues(alpha: 0.06 * fade),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              color: ak.amberBgSoft.withValues(alpha: fade),
              shape: BoxShape.circle,
            ),
          ),
          Icon(icon, size: 52, color: ak.ink.withValues(alpha: fade)),
        ],
      ),
    );
  }
}
