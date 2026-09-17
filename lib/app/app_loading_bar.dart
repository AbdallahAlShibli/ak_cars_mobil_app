import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/strings.dart';
import '../core/network/network_activity.dart';
import '../core/theme/app_colors.dart';
import '../di/providers.dart';
import '../state/startup_state.dart';

/// The thin amber bar that sweeps across the top of every screen while data
/// is loading.
///
/// One bar for the whole app, not one per page: it sits above every route
/// (see `AkCarsApp`) and shows whenever the app's first load is still running
/// ([startupLoadingProvider]) or any API request is in flight
/// ([NetworkActivity]). A page therefore never needs to remember to show it,
/// and a page added tomorrow gets it too.
///
/// It is careful not to flicker. It waits [showDelay] before appearing, so a
/// request that answers from a warm connection never flashes it, and once up
/// it stays at least [minVisible], so a short gap between two requests does
/// not blink it off and on. It honours the OS "reduce motion" setting with a
/// still bar, and sweeps from the reading edge in Arabic as well as English.
class AppLoadingBar extends ConsumerStatefulWidget {
  const AppLoadingBar({super.key});

  static const showDelay = Duration(milliseconds: 250);
  static const minVisible = Duration(milliseconds: 450);
  static const fade = Duration(milliseconds: 250);
  static const sweep = Duration(milliseconds: 1300);
  static const height = 3.0;

  @override
  ConsumerState<AppLoadingBar> createState() => _AppLoadingBarState();
}

class _AppLoadingBarState extends ConsumerState<AppLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: AppLoadingBar.sweep,
  );
  late final NetworkActivity _activity = ref.read(networkActivityProvider);

  Timer? _showTimer;
  Timer? _hideTimer;
  DateTime? _shownAt;
  bool _visible = false;

  bool get _wanted =>
      ref.read(startupLoadingProvider) || _activity.busy.value;

  @override
  void initState() {
    super.initState();
    _activity.busy.addListener(_sync);
    ref.listenManual<bool>(startupLoadingProvider, (_, _) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _activity.busy.removeListener(_sync);
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    if (_wanted) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (_visible || _showTimer != null) return;
      _showTimer = Timer(AppLoadingBar.showDelay, _show);
    } else {
      _showTimer?.cancel();
      _showTimer = null;
      if (!_visible || _hideTimer != null) return;
      final shownFor = DateTime.now().difference(_shownAt ?? DateTime.now());
      final remaining = AppLoadingBar.minVisible - shownFor;
      _hideTimer = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        _hide,
      );
    }
  }

  void _show() {
    _showTimer = null;
    if (!mounted || !_wanted) return;
    setState(() {
      _visible = true;
      _shownAt = DateTime.now();
    });
    if (!MediaQuery.disableAnimationsOf(context)) _motion.repeat();
  }

  void _hide() {
    _hideTimer = null;
    if (!mounted || _wanted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: Semantics(
            container: true,
            liveRegion: _visible,
            label: _visible ? S.of(context).t('جارٍ التحميل', 'Loading') : null,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: AppLoadingBar.fade,
              curve: Curves.easeOut,
              onEnd: () {
                if (!_visible) _motion.stop();
              },
              child: SizedBox(
                height: AppLoadingBar.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SweepPainter(
                    progress: still ? null : _motion,
                    color: ak.amber,
                    track: ak.amber.withValues(alpha: 0.16),
                    rtl: Directionality.of(context) == TextDirection.rtl,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft-edged comet of [color] crossing a faint [track], with a glow under
/// it. With no [progress] (reduce motion) the whole track is lit instead.
class _SweepPainter extends CustomPainter {
  _SweepPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.rtl,
  }) : super(repaint: progress);

  final Animation<double>? progress;
  final Color color;
  final Color track;
  final bool rtl;

  /// The comet's share of the bar's width.
  static const _segment = 0.38;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = track,
    );

    final motion = progress;
    if (motion == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, radius),
        Paint()..color = color.withValues(alpha: 0.7),
      );
      return;
    }

    final width = size.width * _segment;
    final travel = Curves.easeInOutCubic.transform(motion.value);
    var left = -width + (size.width + width) * travel;
    if (rtl) left = size.width - left - width;
    final comet = Rect.fromLTWH(left, 0, width, size.height);
    final gradient = LinearGradient(
      colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
    ).createShader(comet);

    canvas.drawRRect(
      RRect.fromRectAndRadius(comet.inflate(1.5), radius),
      Paint()
        ..shader = gradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(comet, radius),
      Paint()..shader = gradient,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.color != color ||
      old.track != track ||
      old.rtl != rtl ||
      old.progress != progress;
}
