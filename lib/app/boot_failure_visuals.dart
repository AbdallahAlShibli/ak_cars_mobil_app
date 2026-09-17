import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n/strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'boot_failure_kind.dart';

/// The failure screen's accent: red for a hard outage, amber otherwise.
Color failureTint(AkColors ak, BootFailureKind kind) =>
    kind.isOutage ? ak.danger : ak.amber;

/// Fade-and-rise for one element of the failure screen's entrance, taking the
/// [begin]–[end] slice of the screen's shared [intro] timeline — so the whole
/// stagger reads top to bottom at the call sites.
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    super.key,
    required this.intro,
    required this.begin,
    required this.end,
    required this.child,
  });

  final Animation<double> intro;
  final double begin;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: intro,
    child: child,
    builder: (context, child) {
      final t = Interval(
        begin,
        end,
        curve: Curves.easeOutCubic,
      ).transform(intro.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, AppSpacing.lg * (1 - t)),
          child: child,
        ),
      );
    },
  );
}

/// Two soft glows drifting behind the content, one in the failure's tint, so
/// the screen never sits completely still while it waits.
class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({super.key, required this.ambient, required this.tint});

  final Animation<double> ambient;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: ambient,
        builder: (context, _) {
          final t = ambient.value;
          return Stack(
            children: [
              PositionedDirectional(
                top: -70 + 24 * t,
                end: -90 + 18 * t,
                child: _glow(280, tint.withValues(alpha: 0.14)),
              ),
              PositionedDirectional(
                bottom: 30 - 26 * t,
                start: -100 + 14 * t,
                child: _glow(240, ak.surfaceDim),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

/// The screen's animated illustration: the failure's icon on a floating disc,
/// with rings radiating out of it like a signal that is not getting through.
class FailureHero extends StatelessWidget {
  const FailureHero({super.key, required this.kind, required this.pulse});

  final BootFailureKind kind;

  /// A repeating 0–1 loop.
  final Animation<double> pulse;

  static const size = 168.0;
  static const _core = 84.0;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final tint = failureTint(ak, kind);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingsPainter(pulse: pulse, color: tint),
              ),
            ),
            AnimatedBuilder(
              animation: pulse,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  0,
                  AppSpacing.xs * math.sin(pulse.value * math.pi * 2),
                ),
                child: child,
              ),
              child: Container(
                width: _core,
                height: _core,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ak.surface,
                  border: Border.all(
                    color: tint.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.28),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(kind.icon, size: 36, color: tint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.pulse, required this.color})
    : super(repaint: pulse);

  final Animation<double> pulse;
  final Color color;

  static const _rings = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    const inner = FailureHero._core / 2;

    final glowRadius = outer * 0.8;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < _rings; i++) {
      final t = (pulse.value + i / _rings) % 1;
      stroke.color = color.withValues(alpha: 0.45 * (1 - t));
      canvas.drawCircle(
        center,
        inner + (outer - inner) * Curves.easeOut.transform(t),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color;
}

enum _LinkState { flowing, broken, struggling, unknown }

enum _NodeState { ok, failed, warning, unknown }

/// The infographic: phone → internet → AK Cars server, with data dots
/// travelling along each working link and stopping where the failure is.
class ConnectionInfographic extends StatelessWidget {
  const ConnectionInfographic({
    super.key,
    required this.kind,
    required this.flow,
    required this.badge,
    required this.s,
  });

  final BootFailureKind kind;

  /// A repeating 0–1 loop that moves the data dots.
  final Animation<double> flow;

  /// The technical label shown in the corner, e.g. `HTTP 502`.
  final String badge;
  final S s;

  static const _nodeSize = 52.0;

  _NodeState _node(int index) {
    if (index == kind.faultyNode) {
      return kind.isOutage ? _NodeState.failed : _NodeState.warning;
    }
    return index < kind.faultyNode ? _NodeState.ok : _NodeState.unknown;
  }

  _LinkState _link(int index) {
    final broken = kind.brokenLink;
    if (broken == index) {
      return kind == BootFailureKind.slow
          ? _LinkState.struggling
          : _LinkState.broken;
    }
    return broken != null && index < broken
        ? _LinkState.flowing
        : _LinkState.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final labels = [
      s.t('هاتفك', 'Your phone'),
      s.t('الإنترنت', 'Internet'),
      s.t('خادم AK Cars', 'AK Cars server'),
    ];
    const icons = [LucideIcons.smartphone, LucideIcons.globe, LucideIcons.server];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        border: Border.all(color: ak.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.t('أين توقف الاتصال', 'Where the connection stopped'),
                  style: context.text.cardTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _CodeChip(label: badge, color: failureTint(ak, kind)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LinksPainter(
                    flow: flow,
                    states: [_link(0), _link(1)],
                    nodeRadius: _nodeSize / 2,
                    direction: Directionality.of(context),
                    ok: ak.success,
                    bad: ak.danger,
                    warn: ak.amber,
                    idle: ak.inkFaint,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: _Node(
                        icon: icons[i],
                        label: labels[i],
                        state: _node(i),
                        kind: kind,
                        flow: flow,
                        s: s,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      textDirection: TextDirection.ltr,
      style: context.text.labelStrong.copyWith(color: color),
    ),
  );
}

class _Node extends StatelessWidget {
  const _Node({
    required this.icon,
    required this.label,
    required this.state,
    required this.kind,
    required this.flow,
    required this.s,
  });

  final IconData icon;
  final String label;
  final _NodeState state;
  final BootFailureKind kind;
  final Animation<double> flow;
  final S s;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final slow = kind == BootFailureKind.slow;
    final (Color color, Color soft, IconData? badge, String status) =
        switch (state) {
          _NodeState.ok => (
            ak.success,
            ak.successSoft,
            LucideIcons.check,
            s.t('يعمل', 'Working'),
          ),
          _NodeState.failed => (
            ak.danger,
            ak.dangerSoft,
            LucideIcons.x,
            s.t('لا يستجيب', 'No response'),
          ),
          _NodeState.warning => (
            ak.amber,
            ak.amberBgSoft,
            slow ? LucideIcons.clock : LucideIcons.zap,
            slow ? s.t('بطيء', 'Too slow') : s.t('توقف هنا', 'Stopped here'),
          ),
          _NodeState.unknown => (
            ak.inkFaint,
            ak.surfaceDim,
            null,
            s.t('لم نصل إليه', 'Not reached'),
          ),
        };
    final alarmed =
        state == _NodeState.failed || state == _NodeState.warning;

    final disc = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: ConnectionInfographic._nodeSize,
          height: ConnectionInfographic._nodeSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: soft,
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        if (badge != null)
          PositionedDirectional(
            end: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: ak.surface, width: 2),
              ),
              child: Icon(badge, size: 10, color: ak.surface),
            ),
          ),
      ],
    );

    return Column(
      children: [
        if (alarmed)
          AnimatedBuilder(
            animation: flow,
            child: disc,
            builder: (context, child) => Transform.scale(
              scale: 1 + 0.06 * math.sin(flow.value * math.pi * 2),
              child: child,
            ),
          )
        else
          disc,
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: context.text.bodySecondary.copyWith(
            color: ak.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          status,
          textAlign: TextAlign.center,
          style: context.text.labelStrong.copyWith(color: color),
        ),
      ],
    );
  }
}

class _LinksPainter extends CustomPainter {
  _LinksPainter({
    required this.flow,
    required this.states,
    required this.nodeRadius,
    required this.direction,
    required this.ok,
    required this.bad,
    required this.warn,
    required this.idle,
  }) : super(repaint: flow);

  final Animation<double> flow;
  final List<_LinkState> states;
  final double nodeRadius;
  final TextDirection direction;
  final Color ok;
  final Color bad;
  final Color warn;
  final Color idle;

  static const _gap = 6.0;
  static const _dash = 4.0;
  static const _breakHalfWidth = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = nodeRadius;
    // The nodes sit in three equal columns; in RTL the phone is on the right.
    double x(double fraction) => direction == TextDirection.rtl
        ? size.width * (1 - fraction)
        : size.width * fraction;

    for (var i = 0; i < states.length; i++) {
      final from = Offset(x((2 * i + 1) / 6), y);
      final to = Offset(x((2 * i + 3) / 6), y);
      final along = (to - from) / (to - from).distance;
      final a = from + along * (nodeRadius + _gap);
      final b = to - along * (nodeRadius + _gap);

      switch (states[i]) {
        case _LinkState.flowing:
          _line(canvas, a, b, ok.withValues(alpha: 0.35));
          _packets(canvas, a, b, ok, count: 3);
        case _LinkState.struggling:
          _dashed(canvas, a, b, warn.withValues(alpha: 0.55));
          // Dots that crawl through the middle of the link: getting there,
          // too slowly.
          _packets(canvas, a, b, warn, count: 2, curve: Curves.slowMiddle);
        case _LinkState.broken:
          _broken(canvas, a, b, along);
        case _LinkState.unknown:
          _dashed(canvas, a, b, idle.withValues(alpha: 0.45));
      }
    }
  }

  void _broken(Canvas canvas, Offset a, Offset b, Offset along) {
    final middle = Offset.lerp(a, b, 0.5)!;
    _line(canvas, a, middle - along * _breakHalfWidth, bad.withValues(alpha: 0.35));
    _dashed(canvas, middle + along * _breakHalfWidth, b, idle.withValues(alpha: 0.4));
    // Data sets off and fades out before the gap — it never arrives.
    _packets(
      canvas,
      a,
      middle - along * _breakHalfWidth,
      bad,
      count: 3,
      fadeOut: true,
    );

    final beat = 1 + 0.18 * math.sin(flow.value * math.pi * 2);
    canvas.drawCircle(
      middle,
      _breakHalfWidth * beat,
      Paint()..color = bad.withValues(alpha: 0.16),
    );
    final cross = Paint()
      ..color = bad
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final arm = 4.5 * beat;
    canvas
      ..drawLine(middle + Offset(-arm, -arm), middle + Offset(arm, arm), cross)
      ..drawLine(middle + Offset(-arm, arm), middle + Offset(arm, -arm), cross);
  }

  void _packets(
    Canvas canvas,
    Offset a,
    Offset b,
    Color color, {
    required int count,
    Curve curve = Curves.linear,
    bool fadeOut = false,
  }) {
    for (var k = 0; k < count; k++) {
      final t = (flow.value + k / count) % 1;
      final position = Offset.lerp(a, b, curve.transform(t))!;
      var alpha = 1.0;
      if (t < 0.1) alpha = t / 0.1;
      if (fadeOut && t > 0.6) {
        alpha = (1 - t) / 0.4;
      } else if (t > 0.9) {
        alpha = (1 - t) / 0.1;
      }
      canvas
        ..drawCircle(
          position,
          7,
          Paint()..color = color.withValues(alpha: 0.18 * alpha),
        )
        ..drawCircle(
          position,
          3.5,
          Paint()..color = color.withValues(alpha: alpha),
        );
    }
  }

  void _line(Canvas canvas, Offset a, Offset b, Color color) => canvas.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round,
  );

  void _dashed(Canvas canvas, Offset a, Offset b, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final length = (b - a).distance;
    if (length <= 0) return;
    final along = (b - a) / length;
    for (var d = 0.0; d < length; d += _dash * 2) {
      canvas.drawLine(
        a + along * d,
        a + along * math.min(d + _dash, length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LinksPainter old) =>
      !listEquals(old.states, states) ||
      old.direction != direction ||
      old.ok != ok ||
      old.bad != bad ||
      old.warn != warn ||
      old.idle != idle;
}

/// One numbered piece of advice.
class TipTile extends StatelessWidget {
  const TipTile({
    super.key,
    required this.step,
    required this.icon,
    required this.text,
  });

  final int step;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: ak.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ak.surfaceDim,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Icon(icon, size: 20, color: ak.ink),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.text.bodyPrimary)),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ak.border),
            ),
            child: Text(
              '$step',
              style: context.text.labelStrong.copyWith(color: ak.inkSub),
            ),
          ),
        ],
      ),
    );
  }
}
