import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n/strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import 'boot_failure_kind.dart';
import 'boot_failure_visuals.dart';

/// What the app shows when it could not start (see `AppLauncher`).
///
/// Deliberately its own `MaterialApp` with no `ProviderScope`: the whole point
/// is that it renders when the dependency container could not be built, so it
/// may not read a single provider. Language comes from the platform rather
/// than from the stored preference for the same reason.
class BootFailureApp extends StatelessWidget {
  const BootFailureApp({super.key, required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final isAr = locale.languageCode != 'en';
    return MaterialApp(
      title: 'AK Cars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: Locale(isAr ? 'ar' : 'en'),
      home: Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: _BootFailureScreen(s: S(isAr), error: error, onRetry: onRetry),
      ),
    );
  }
}

class _BootFailureScreen extends StatefulWidget {
  const _BootFailureScreen({
    required this.s,
    required this.error,
    required this.onRetry,
  });

  final S s;
  final Object error;
  final Future<void> Function() onRetry;

  @override
  State<_BootFailureScreen> createState() => _BootFailureScreenState();
}

/// Tells the person *where* start-up failed — their phone, the internet, or
/// the AK Cars server — with an animated diagram of that path, then what to
/// do about it. The retry is pinned to the bottom so it never scrolls away,
/// and the technical error stays one tap away for whoever has to report it.
class _BootFailureScreenState extends State<_BootFailureScreen>
    with TickerProviderStateMixin {
  /// One entrance timeline; every element takes a slice of it (`StaggerIn`).
  late final AnimationController _intro;

  /// The fast loop: radiating rings, travelling data dots, the pulsing break.
  late final AnimationController _flow;

  /// The slow loop: the background glows drift.
  late final AnimationController _ambient;

  late final BootFailureKind _kind = BootFailureKind.of(widget.error);

  bool _retrying = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    // Started after the first frame, not while it is being built. This screen
    // is mounted by `runApp` — including again, mid-frame, when a retry fails
    // — and a ticker started during a build stamps itself with that frame's
    // time, which the next frame can precede (`elapsedInSeconds >= 0`).
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimations());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the OS "reduce motion" setting: the finished screen at once, and
    // the diagram frozen with its data dots part-way along the links. Setting
    // a value starts no ticker.
    if (!_reducedMotion && MediaQuery.disableAnimationsOf(context)) {
      _reducedMotion = true;
      _intro.value = 1;
      _flow.value = 0.35;
    }
  }

  void _startAnimations() {
    if (!mounted || _reducedMotion) return;
    _intro.forward();
    _flow.repeat();
    _ambient.repeat(reverse: true);
  }

  @override
  void dispose() {
    _intro.dispose();
    _flow.dispose();
    _ambient.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    // A successful retry replaces this widget wholesale, so there is nothing
    // to reset afterwards; a failed one rebuilds this screen with the new
    // error and its own fresh state.
    await widget.onRetry();
  }

  // The message names what could not be reached (the API base URL, the
  // failing repository), which is the difference between a bug report and
  // "it doesn't work".
  Future<void> _showDetails() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AkColors.of(context).surface,
    builder: (sheetContext) => _DetailsSheet(
      s: widget.s,
      error: widget.error,
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: '${widget.error}'));
        if (!sheetContext.mounted) return;
        Navigator.of(sheetContext).pop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.s.t('نُسخت تفاصيل الخطأ', 'Error details copied'),
            ),
          ),
        );
      },
    ),
  );

  Widget _stagger(double begin, double end, Widget child) =>
      StaggerIn(intro: _intro, begin: begin, end: end, child: child);

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final tint = failureTint(ak, _kind);

    return Scaffold(
      backgroundColor: ak.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AmbientBackdrop(ambient: _ambient, tint: tint),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(child: _content(context, tint)),
                _stagger(0.6, 1, _actionBar(context, ak)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, Color tint) {
    final s = widget.s;
    final tips = _kind.tips(s);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.xl,
          AppSpacing.screenMargin,
          AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stagger(
                0,
                0.35,
                Center(child: FailureHero(kind: _kind, pulse: _flow)),
              ),
              const SizedBox(height: AppSpacing.md),
              _stagger(0.1, 0.45, Center(child: _Eyebrow(s: s, tint: tint))),
              const SizedBox(height: AppSpacing.sm),
              _stagger(
                0.15,
                0.5,
                Text(
                  _kind.headline(s),
                  textAlign: TextAlign.center,
                  style: context.text.screenTitle,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _stagger(
                0.2,
                0.55,
                Text(
                  _kind.explanation(s),
                  textAlign: TextAlign.center,
                  style: context.text.bodySecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _stagger(
                0.3,
                0.7,
                ConnectionInfographic(
                  kind: _kind,
                  flow: _flow,
                  badge: BootFailureKind.badgeFor(widget.error),
                  s: s,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _stagger(
                0.4,
                0.75,
                Text(
                  s.t('ماذا يمكنك أن تفعل', 'What you can do'),
                  style: context.text.cardTitle,
                ),
              ),
              const SizedBox(height: AppSpacing.headingGap),
              for (var i = 0; i < tips.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.itemGap),
                _stagger(
                  0.45 + i * 0.08,
                  0.8 + i * 0.06,
                  TipTile(step: i + 1, icon: tips[i].icon, text: tips[i].text),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Pinned below the scrolling content, so the one action is always in
  /// reach however tall the explanation grows.
  Widget _actionBar(BuildContext context, AkColors ak) {
    final s = widget.s;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ak.bg.withValues(alpha: 0), ak.bg],
          stops: const [0, 0.35],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.sm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RetryPill(
                busy: _retrying,
                label: _retrying
                    ? s.t('جارٍ المحاولة…', 'Trying…')
                    : s.t('حاول مرة أخرى', 'Try again'),
                onTap: _retry,
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: TextButton.icon(
                  onPressed: _showDetails,
                  icon: Icon(LucideIcons.bug, size: 16, color: ak.inkSub),
                  label: Text(
                    s.t('تفاصيل الخطأ', 'Error details'),
                    style: context.text.bodySecondary,
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

/// The technical error, for whoever has to report it, with a one-tap copy.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.s,
    required this.error,
    required this.onCopy,
  });

  final S s;
  final Object error;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Directionality(
      textDirection: s.isAr ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.t('للدعم الفني', 'For support'),
                style: context.text.cardTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                s.t(
                  'أرسل هذا النص إلى الدعم ليعرفوا بالضبط ما الذي تعطّل.',
                  'Send this to support so they know exactly what failed.',
                ),
                style: context.text.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: ak.surfaceDim,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(color: ak.border),
                ),
                child: Text(
                  '$error',
                  textDirection: TextDirection.ltr,
                  style: context.text.bodySecondary.copyWith(color: ak.ink),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(LucideIcons.copy, size: 18),
                label: Text(s.t('نسخ التفاصيل', 'Copy details')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small tinted label above the headline — the one line that stays the
/// same whatever went wrong.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.s, required this.tint});

  final S s;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: tint.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      s.t('تعذّر تشغيل التطبيق', 'The app could not start'),
      style: context.text.labelStrong.copyWith(color: tint),
    ),
  );
}

/// The full-width ink pill that carries the screen's one action, with a press
/// response and a spinner while the retry runs.
class _RetryPill extends StatefulWidget {
  const _RetryPill({
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  State<_RetryPill> createState() => _RetryPillState();
}

class _RetryPillState extends State<_RetryPill> {
  bool _down = false;

  void _press(bool down) {
    if (widget.busy || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Semantics(
      button: true,
      enabled: !widget.busy,
      child: GestureDetector(
        onTapDown: (_) => _press(true),
        onTapCancel: () => _press(false),
        onTapUp: (_) => _press(false),
        onTap: widget.busy ? null : widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _down ? 0.97 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: widget.busy
                  ? ak.primary.withValues(alpha: 0.7)
                  : ak.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: ak.ink.withValues(alpha: _down ? 0.14 : 0.24),
                  blurRadius: _down ? 14 : 28,
                  offset: Offset(0, _down ? 5 : 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.busy)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ak.onPrimary,
                    ),
                  )
                else
                  Icon(LucideIcons.rotateCw, size: 18, color: ak.onPrimary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.label,
                  style: context.text.cardTitle.copyWith(color: ak.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
