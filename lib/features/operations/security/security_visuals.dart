import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/security_alert.dart';

/// The security dashboard's visual vocabulary: one colour per severity, one
/// icon per threat and per device, and the two infographics (the threat gauge
/// and the attack-path map).
///
/// Red here is the platform's alarm red on purpose — this is the one screen
/// whose whole job is to say "something is attacking you", and a critical
/// alert that looked like an amber offer would be the wrong message.

Color severityColor(AkColors ak, SecuritySeverity severity) =>
    switch (severity) {
      SecuritySeverity.critical => ak.danger,
      SecuritySeverity.high => ak.amberDeep,
      SecuritySeverity.medium => ak.amber,
      SecuritySeverity.low => ak.inkSub,
    };

Color threatLevelColor(AkColors ak, ThreatLevel level) => switch (level) {
  ThreatLevel.critical || ThreatLevel.severe => ak.danger,
  ThreatLevel.elevated => ak.amberDeep,
  ThreatLevel.guarded => ak.amber,
  ThreatLevel.calm => ak.success,
};

IconData threatIcon(String type) => switch (type) {
  'sqlInjection' => LucideIcons.database,
  'crossSiteScripting' => LucideIcons.code,
  'pathTraversal' => LucideIcons.folderTree,
  'commandInjection' => LucideIcons.squareTerminal,
  'vulnerabilityScan' => LucideIcons.scanSearch,
  'scannerTool' => LucideIcons.bug,
  'unsignedClient' => LucideIcons.shieldX,
  'forgedSignature' => LucideIcons.signature,
  'replayAttack' => LucideIcons.repeat,
  'credentialBruteForce' => LucideIcons.keyRound,
  'tokenAbuse' => LucideIcons.fingerprint,
  'accessViolation' => LucideIcons.ban,
  'rateLimitAbuse' => LucideIcons.gauge,
  'endpointEnumeration' => LucideIcons.search,
  _ => LucideIcons.shieldAlert,
};

IconData deviceIcon(String deviceType) => switch (deviceType) {
  'mobile' => LucideIcons.smartphone,
  'tablet' => LucideIcons.tablet,
  'desktop' => LucideIcons.monitor,
  'script' => LucideIcons.squareTerminal,
  'bot' => LucideIcons.bot,
  _ => LucideIcons.circleHelp,
};

String deviceLabel(S s, String deviceType) => switch (deviceType) {
  'mobile' => s.t('جوال', 'Mobile'),
  'tablet' => s.t('جهاز لوحي', 'Tablet'),
  'desktop' => s.t('حاسوب', 'Desktop'),
  'script' => s.t('سكربت / أداة', 'Script / tool'),
  'bot' => s.t('روبوت زاحف', 'Bot / crawler'),
  _ => s.t('غير معروف', 'Unknown'),
};

/// The country's flag as an emoji, or a globe when there is no usable code.
String flagEmoji(String? countryCode) {
  final code = countryCode?.toUpperCase();
  if (code == null || !RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '🌐';
  return String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
}

/// "3m ago", "5h ago", "2d ago" — the list rows' one clock.
String agoLabel(S s, DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return s.t('الآن', 'now');
  if (d.inHours < 1) return s.t('قبل ${d.inMinutes} د', '${d.inMinutes}m ago');
  if (d.inDays < 1) return s.t('قبل ${d.inHours} س', '${d.inHours}h ago');
  return s.t('قبل ${d.inDays} ي', '${d.inDays}d ago');
}

/// Full local timestamp, seconds included — evidence wants the exact time.
String stamp(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
}

class SeverityPill extends StatelessWidget {
  const SeverityPill(this.severity, {super.key, this.dense = false});

  final SecuritySeverity severity;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(AkColors.of(context), severity);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            severity.label(S.of(context)),
            style: TextStyle(
              color: color,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon on a tinted square in the alert's severity colour.
class ThreatIconTile extends StatelessWidget {
  const ThreatIconTile({
    super.key,
    required this.type,
    required this.severity,
    this.size = 42,
  });

  final String type;
  final SecuritySeverity severity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(AkColors.of(context), severity);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(threatIcon(type), size: size * 0.48, color: color),
    );
  }
}

/// The half-dial at the top of the dashboard: 0–100, calm green through to
/// alarm red, with the score and its word in the middle.
class ThreatGauge extends StatelessWidget {
  const ThreatGauge({
    super.key,
    required this.score,
    required this.level,
    this.size = 190,
  });

  final int score;
  final ThreatLevel level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final color = threatLevelColor(ak, level);
    return SizedBox(
      width: size,
      height: size * 0.62,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score / 100),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _GaugePainter(
            value: value,
            track: ak.divider,
            colors: [ak.success, ak.amber, ak.amberDeep, ak.danger],
            needle: color,
          ),
          child: Align(
            alignment: const Alignment(0, 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(value * 100).round()}',
                  style: AppTheme.numeric(
                    size: size * 0.2,
                    weight: FontWeight.w800,
                    color: ak.ink,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  level.label(s).toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.track,
    required this.colors,
    required this.needle,
  });

  final double value;
  final Color track;
  final List<Color> colors;
  final Color needle;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final radius = size.width / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height - stroke * 0.2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final v = value.clamp(0.0, 1.0);

    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = track,
    );

    if (v > 0) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * v,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: math.pi,
            endAngle: math.pi * 2,
            colors: colors,
          ).createShader(rect),
      );
    }

    // Tick marks every 10, longer every 50.
    final tick = Paint()
      ..color = track
      ..strokeWidth = 1.4;
    for (var i = 0; i <= 10; i++) {
      final angle = math.pi + math.pi * i / 10;
      final inner = radius - stroke * 0.95;
      final outer = radius - stroke * (i % 5 == 0 ? 1.55 : 1.25);
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        tick,
      );
    }

    final angle = math.pi + math.pi * v;
    final dot =
        center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    canvas.drawCircle(dot, stroke * 0.62, Paint()..color = Colors.white);
    canvas.drawCircle(dot, stroke * 0.42, Paint()..color = needle);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.needle != needle || old.track != track;
}

/// Where the attack came from, drawn as an arc from the attacker's point to
/// AK Cars' home in Muscat on a latitude/longitude grid.
///
/// Deliberately a grid and not a map: no tiles are fetched (an attacker's
/// address should not leave the app for a third-party tile server just because
/// the founder opened an alert), and the point of the picture is distance and
/// direction, which the grid shows. "Open in Maps" is one tap away for detail.
class AttackPathMap extends StatefulWidget {
  const AttackPathMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.color,
  });

  final double latitude;
  final double longitude;
  final Color color;

  /// Muscat — the server's side of the arc.
  static const homeLatitude = 23.59;
  static const homeLongitude = 58.41;

  @override
  State<AttackPathMap> createState() => _AttackPathMapState();
}

class _AttackPathMapState extends State<AttackPathMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return AspectRatio(
      aspectRatio: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ak.surfaceDim, ak.surface],
            ),
          ),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => CustomPaint(
              painter: _AttackPathPainter(
                from: Offset(widget.longitude, widget.latitude),
                to: const Offset(
                  AttackPathMap.homeLongitude,
                  AttackPathMap.homeLatitude,
                ),
                attack: widget.color,
                home: ak.success,
                // ak.border alone all but vanishes on the light surface.
                grid: ak.inkFaint.withValues(alpha: 0.35),
                pulse: _pulse.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttackPathPainter extends CustomPainter {
  _AttackPathPainter({
    required this.from,
    required this.to,
    required this.attack,
    required this.home,
    required this.grid,
    required this.pulse,
  });

  /// (longitude, latitude).
  final Offset from;
  final Offset to;
  final Color attack;
  final Color home;
  final Color grid;
  final double pulse;

  Offset _project(Offset lonLat, Size size) => Offset(
    (lonLat.dx + 180) / 360 * size.width,
    (90 - lonLat.dy) / 180 * size.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.7;
    for (var lon = -180; lon <= 180; lon += 30) {
      final x = (lon + 180) / 360 * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var lat = -90; lat <= 90; lat += 30) {
      final y = (90 - lat) / 180 * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // A dotted field, so the grid reads as a globe's surface, not graph paper.
    final dots = Paint()..color = grid.withValues(alpha: 0.5);
    for (var x = 6.0; x < size.width; x += 12) {
      for (var y = 6.0; y < size.height; y += 12) {
        canvas.drawCircle(Offset(x, y), 0.8, dots);
      }
    }

    final a = _project(from, size);
    final b = _project(to, size);
    final lift = math.max(24.0, (b - a).distance * 0.35);
    final control = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - lift);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [attack, home],
        ).createShader(Rect.fromPoints(a, b).inflate(1)),
    );

    // A packet travelling along the arc.
    for (final metric in path.computeMetrics()) {
      final tangent = metric.getTangentForOffset(metric.length * pulse);
      if (tangent != null) {
        canvas.drawCircle(tangent.position, 3.2, Paint()..color = attack);
      }
      break;
    }

    // The attacker: a solid point with an expanding ring.
    canvas.drawCircle(
      a,
      6 + 16 * pulse,
      Paint()..color = attack.withValues(alpha: (1 - pulse) * 0.35),
    );
    canvas.drawCircle(a, 6, Paint()..color = attack);
    canvas.drawCircle(a, 2.4, Paint()..color = Colors.white);

    // Home.
    canvas.drawCircle(b, 7, Paint()..color = home.withValues(alpha: 0.25));
    canvas.drawCircle(b, 4.5, Paint()..color = home);
  }

  @override
  bool shouldRepaint(_AttackPathPainter old) =>
      old.pulse != pulse || old.from != from || old.attack != attack;
}
