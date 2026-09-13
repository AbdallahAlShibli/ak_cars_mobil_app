import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_mark.dart';
import '../../core/widgets/car_artwork.dart';
import '../../state/app_state.dart';
import 'intro_content.dart';

/// Welcome screen (handoff #3a), first of the three first-launch steps.
///
/// Seen once per install: [AuthState.initialRoute] sends returning users
/// straight to /home, so this is allowed to take its time and animate.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// One timeline for the whole entrance; each element takes an [Interval] of
  /// it, so the stagger is declared in one place instead of in scattered
  /// delayed callbacks.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  /// Slow ambient loop — the background shapes drift and the mark breathes.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat(reverse: true);

  // Built once rather than per frame: a CurvedAnimation holds a listener on
  // its parent and has to be disposed.
  late final _markIn = _step(0, 0.4);
  late final _lightsOn = _step(0.3, 0.7);
  late final _titleIn = _step(0.22, 0.55);
  late final _taglineIn = _step(0.3, 0.62);
  late final _photoIn = _step(0.38, 0.78);
  late final _actionsIn = _step(0.55, 0.9);

  bool _reducedMotionApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the OS "reduce motion" setting: show the finished screen rather
    // than making someone who asked for stillness sit through the stagger.
    if (!_reducedMotionApplied && MediaQuery.disableAnimationsOf(context)) {
      _reducedMotionApplied = true;
      _intro.value = 1;
      _ambient.stop();
    }
  }

  @override
  void dispose() {
    for (final a in [
      _markIn,
      _lightsOn,
      _titleIn,
      _taglineIn,
      _photoIn,
      _actionsIn,
    ]) {
      a.dispose();
    }
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  CurvedAnimation _step(double begin, double end) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  void _start() {
    ref.read(authProvider.notifier).markOnboardingSeen();
    context.go('/onboarding');
  }

  /// Jump the tour, still answer the car question.
  void _skipIntro() {
    ref.read(authProvider.notifier).markOnboardingSeen();
    context.go('/start-choice');
  }

  /// The returning user's path.
  ///
  /// Sign-in used to be reachable only from the profile tab, four screens
  /// deep — so someone who reinstalled the app, or switched phones, had to
  /// sit through an intro for a product they already use and answer a car
  /// question about a car they had already registered, before they could get
  /// their own bookings back.
  ///
  /// `push`, not `go`: the login screen pops `true` to whoever opened it
  /// (`login_screen.dart`), and `AuthNotifier.login` has already recorded
  /// both first-run flags by then, so there is nothing left to ask.
  Future<void> _signIn() async {
    final signedIn = await context.push<bool>('/login');
    if (!mounted) return;
    if (signedIn ?? false) context.go(AppFlags.startLocation);
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return Scaffold(
      backgroundColor: ak.bg,
      body: Stack(
        children: [
          _DriftingShapes(ambient: _ambient),
          SafeArea(
            // Scrolls when it has to. The screen is built around two Spacers,
            // which need a bounded height — so the viewport height becomes a
            // *minimum* and `IntrinsicHeight` gives the column a determinate
            // height inside the scroll view. On a normal phone nothing
            // scrolls and the Spacers centre the hero exactly as before; on a
            // short screen, or at a large text scale, the content grows past
            // the viewport and scrolls instead of overflowing — which is what
            // it did once the tagline and the capability chips arrived.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Hero sits optically centred with the actions low: 3/4 the
                        // other way round left a dead band under the car card.
                        const Spacer(flex: 4),
                        _Rise(
                          animation: _markIn,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_intro, _ambient]),
                            builder: (context, _) {
                              // Settles in with a small overshoot, then breathes.
                              final pop = Curves.easeOutBack.transform(
                                const Interval(0, 0.45).transform(_intro.value),
                              );
                              final float =
                                  math.sin(_ambient.value * math.pi * 2) * 3;
                              return Transform.translate(
                                offset: Offset(0, float),
                                child: Transform.scale(
                                  scale: 0.86 + 0.14 * pop,
                                  child: AppMark(
                                    size: 96,
                                    // The light bar switches on a beat after the tile
                                    // lands, which is the whole point of the mark.
                                    barProgress: _lightsOn.value,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Rise(
                          animation: _titleIn,
                          child: Text(
                            'AK Cars',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: ak.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _Rise(
                          animation: _taglineIn,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              // Was "Everything your car needs… in one place", which
                              // is true of every automotive app ever shipped and so
                              // tells a first-time user nothing. This names the thing
                              // AK Cars actually does differently.
                              s.t(
                                'احجز لدى ورشة موثّقة، ومبلغك محفوظ حتى تعتمد العمل',
                                'Book a verified workshop — your money is held until you approve the work',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: ak.inkSub,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Three words before the first tap. Someone who installs the
                        // app and immediately skips the tour has still been told what
                        // it is for.
                        _Rise(
                          animation: _taglineIn,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final chip in introChips())
                                _IntroChip(label: chip.of(s)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _Rise(
                          animation: _photoIn,
                          child: Container(
                            width: 230,
                            height: 104,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: ak.surfaceDim,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: ak.border),
                            ),
                            // Drawn, not `CarImage`: the remote path fetches from
                            // cdn.imagin.studio, which returns a *watermarked* photo
                            // on the account currently configured — and the very
                            // first screen of the app should not wait on a CDN, or
                            // show someone else's watermark, to paint.
                            child: const Padding(
                              padding: EdgeInsets.all(14),
                              child: CarArtwork(
                                make: 'Toyota',
                                model: 'Land Cruiser',
                                color: 'Silver',
                              ),
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                        _Rise(
                          animation: _actionsIn,
                          child: Column(
                            children: [
                              _FlowDots(
                                step: 0,
                                of: 3,
                                ink: ak.ink,
                                idle: ak.inkFaint,
                              ),
                              const SizedBox(height: 18),
                              _PillButton(
                                label: s.t('ابدأ الرحلة', 'Start the journey'),
                                onTap: _start,
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _signIn,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: s.t(
                                          'لديك حساب؟ ',
                                          'Already have an account? ',
                                        ),
                                      ),
                                      TextSpan(
                                        text: s.t('تسجيل الدخول', 'Sign in'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: ak.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ak.inkSub,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _skipIntro,
                                child: Text(
                                  s.t('تخطَّ الجولة', 'Skip the tour'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: ak.inkFaint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the welcome screen's three capability chips — see [introChips].
class _IntroChip extends StatelessWidget {
  const _IntroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ak.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ak.inkSub,
        ),
      ),
    );
  }
}

/// Fade + rise driven by a shared timeline.
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.14),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

/// The two soft sand circles from the handoff, drifting slowly so the screen
/// is never completely static while it waits for a tap.
class _DriftingShapes extends StatelessWidget {
  const _DriftingShapes({required this.ambient});

  final Animation<double> ambient;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: ambient,
      builder: (context, _) {
        final t = ambient.value;
        return Stack(
          children: [
            PositionedDirectional(
              top: 130 - 14 * t,
              end: -70 + 10 * t,
              child: _blob(220, dark ? ak.surfaceDim : const Color(0xFFF3E3C6)),
            ),
            PositionedDirectional(
              bottom: 180 + 18 * t,
              start: -50 - 8 * t,
              child: _blob(150, dark ? ak.surface : const Color(0xFFEFE9DE)),
            ),
          ],
        );
      },
    );
  }

  Widget _blob(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// Progress through the three first-launch steps — the same promise the
/// start-choice screen's "Step 3 of 3" bar keeps.
class _FlowDots extends StatelessWidget {
  const _FlowDots({
    required this.step,
    required this.of,
    required this.ink,
    required this.idle,
  });

  final int step;
  final int of;
  final Color ink;
  final Color idle;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < of; i++) ...[
        if (i > 0) const SizedBox(width: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: i == step ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: i == step ? ink : idle,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    ],
  );
}

/// Ink pill with a press response — the primary action on a screen that has
/// no app bar, so it carries the whole affordance.
class _PillButton extends StatefulWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _down ? 0.96 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 15),
          decoration: BoxDecoration(
            color: ak.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: ak.ink.withValues(alpha: _down ? 0.16 : 0.26),
                blurRadius: _down ? 16 : 30,
                offset: Offset(0, _down ? 6 : 14),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: ak.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
