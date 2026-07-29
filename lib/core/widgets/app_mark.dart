import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The AK Cars mark — the same drawing as the launcher icon in `icon/`.
///
/// It is a widget rather than an asset so the in-app mark and the installed
/// icon can never drift apart, and so the light bar can animate. The geometry
/// below is the icon's 1024-unit grid verbatim; keep the two in step if either
/// is edited.
class AppMark extends StatelessWidget {
  const AppMark({
    super.key,
    this.size = 88,
    this.tile = true,
    this.barProgress = 1,
  });

  final double size;

  /// Draws the ink tile behind the car, the way the launcher shows it. Off,
  /// the car is drawn in ink on whatever surface it sits on.
  final bool tile;

  /// 0–1 width of the amber light bar, measured from its centre. Animating
  /// this is the mark "switching its lights on".
  final double barProgress;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final car = CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(
        body: tile ? const Color(0xFFF6F3EE) : ak.ink,
        window: tile ? const Color(0xFF16150F) : ak.bg,
        barProgress: barProgress.clamp(0, 1),
      ),
    );

    if (!tile) return SizedBox.square(dimension: size, child: car);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26241F), Color(0xFF16150F)],
        ),
        borderRadius: BorderRadius.circular(size * 0.219),
        // In dark mode the ink tile all but merges with the background, so it
        // gets a hairline to keep its silhouette.
        border: dark ? Border.all(color: ak.border) : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1B17).withValues(alpha: dark ? 0.5 : 0.22),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.2),
          ),
        ],
      ),
      child: car,
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.body,
    required this.window,
    required this.barProgress,
  });

  final Color body;
  final Color window;
  final double barProgress;

  static const _amber = LinearGradient(
    colors: [Color(0xFFE9A23B), Color(0xFFB07818)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024);
    // The icon's outer group transform, so both drawings stay identical.
    canvas.translate(-51.2, -40.6);
    canvas.scale(1.1);

    final fill = Paint()..color = body;

    // Cabin.
    canvas.drawPath(
      Path()
        ..moveTo(414, 292)
        ..lineTo(610, 292)
        ..cubicTo(656, 292, 686, 316, 700, 360)
        ..lineTo(742, 456)
        ..lineTo(282, 456)
        ..lineTo(324, 360)
        ..cubicTo(338, 316, 368, 292, 414, 292)
        ..close(),
      fill,
    );

    // Windshield.
    canvas.drawPath(
      Path()
        ..moveTo(436, 346)
        ..lineTo(588, 346)
        ..cubicTo(610, 346, 622, 356, 628, 374)
        ..lineTo(648, 430)
        ..lineTo(376, 430)
        ..lineTo(396, 374)
        ..cubicTo(402, 356, 414, 346, 436, 346)
        ..close(),
      Paint()..color = window,
    );

    // Body with fender shoulders.
    canvas.drawPath(
      Path()
        ..moveTo(252, 446)
        ..lineTo(772, 446)
        ..cubicTo(796, 446, 812, 466, 810, 490)
        ..lineTo(796, 606)
        ..cubicTo(792, 640, 768, 660, 736, 660)
        ..lineTo(288, 660)
        ..cubicTo(256, 660, 232, 640, 228, 606)
        ..lineTo(214, 490)
        ..cubicTo(212, 466, 228, 446, 252, 446)
        ..close(),
      fill,
    );

    // Tyres.
    for (final left in const [278.0, 604.0]) {
      canvas.drawRRect(
        RRect.fromLTRBR(left, 658, left + 142, 714, const Radius.circular(28)),
        fill,
      );
    }

    // Light bar, opening from the centre.
    if (barProgress > 0) {
      final half = 226 * barProgress;
      final bar = Rect.fromLTRB(512 - half, 520, 512 + half, 564);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, Radius.circular(22 * barProgress)),
        Paint()..shader = _amber.createShader(bar),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.body != body ||
      old.window != window ||
      old.barProgress != barProgress;
}
