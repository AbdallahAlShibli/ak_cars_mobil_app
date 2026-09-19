import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/security_overview.dart';

/// Suspicious calls over the window, stacked by how serious they were.
class SecurityTimelineChart extends StatelessWidget {
  const SecurityTimelineChart({
    super.key,
    required this.buckets,
    required this.hourly,
  });

  final List<TimelineBucket> buckets;

  /// Hourly buckets label as "14:00", daily ones as "9/18".
  final bool hourly;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final maxY = buckets.fold<int>(0, (m, b) => b.events > m ? b.events : m);
    final interval = maxY <= 3 ? 1.0 : (maxY / 3).ceilToDouble();
    final width = buckets.length > 30
        ? 4.0
        : (buckets.length > 14 ? 6.0 : 10.0);

    String label(DateTime at) => hourly
        ? '${at.hour.toString().padLeft(2, '0')}:00'
        : '${at.month}/${at.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY * 1.2,
              alignment: BarChartAlignment.spaceBetween,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: ak.divider, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: interval,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(fontSize: 9.5, color: ak.inkFaint),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      final last = buckets.length - 1;
                      if (i < 0 || i > last) return const SizedBox.shrink();
                      if (i != 0 && i != last && i != last ~/ 2) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label(buckets[i].start),
                          style: TextStyle(fontSize: 9.5, color: ak.inkSub),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => ak.ink,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final b = buckets[group.x];
                    return BarTooltipItem(
                      '${label(b.start)}\n',
                      TextStyle(
                        color: ak.bg,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      children: [
                        TextSpan(
                          text: s.t('${b.events} حدث', '${b.events} events'),
                          style: TextStyle(color: ak.bg, fontSize: 11),
                        ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: [
                for (final (i, b) in buckets.indexed)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: b.events.toDouble(),
                        width: width,
                        color: ak.amber,
                        borderRadius: BorderRadius.circular(3),
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            b.critical.toDouble(),
                            ak.danger,
                          ),
                          BarChartRodStackItem(
                            b.critical.toDouble(),
                            (b.critical + b.high).toDouble(),
                            ak.amberDeep,
                          ),
                          BarChartRodStackItem(
                            (b.critical + b.high).toDouble(),
                            b.events.toDouble(),
                            ak.amber,
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            _LegendDot(color: ak.danger, label: s.t('حرج', 'Critical')),
            _LegendDot(color: ak.amberDeep, label: s.t('مرتفع', 'High')),
            _LegendDot(color: ak.amber, label: s.t('أخرى', 'Other')),
          ],
        ),
      ],
    );
  }
}

/// What kinds of attack the window saw, as a donut with its legend.
class ThreatMixDonut extends StatelessWidget {
  const ThreatMixDonut({super.key, required this.types});

  final List<ThreatTypeCount> types;

  static List<Color> palette(AkColors ak) => [
    ak.danger,
    ak.amberDeep,
    ak.amber,
    ak.primary,
    ak.success,
    ak.inkSub,
    ak.promoTitle,
  ];

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final colors = palette(ak);
    final shown = types.take(colors.length).toList();
    final total = shown.fold<int>(0, (sum, t) => sum + t.events);

    return Row(
      children: [
        SizedBox(
          width: 118,
          height: 118,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  startDegreeOffset: -90,
                  sections: [
                    for (final (i, t) in shown.indexed)
                      PieChartSectionData(
                        value: t.events <= 0 ? 0.001 : t.events.toDouble(),
                        color: colors[i],
                        radius: 18,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: AppTheme.numeric(
                      size: 20,
                      weight: FontWeight.w800,
                      color: ak.ink,
                    ),
                  ),
                  Text(s.t('حدث', 'events'), style: context.text.bodySecondary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, t) in shown.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          t.title.of(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySecondary.copyWith(
                            color: ak.ink,
                          ),
                        ),
                      ),
                      Text(
                        total == 0
                            ? '0%'
                            : '${(t.events * 100 / total).round()}%',
                        style: AppTheme.numeric(size: 12, color: ak.inkSub),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A labelled horizontal bar — used for top targets and top countries.
class RankBar extends StatelessWidget {
  const RankBar({
    super.key,
    required this.leading,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.caption,
  });

  final Widget leading;
  final String label;
  final String? caption;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelStrong,
                      ),
                    ),
                    Text(
                      '$value',
                      style: AppTheme.numeric(size: 13, color: ak.ink),
                    ),
                  ],
                ),
                if (caption != null)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySecondary,
                  ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Stack(
                    children: [
                      Container(height: 6, color: ak.surfaceDim),
                      FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.55), color],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: context.text.bodySecondary),
    ],
  );
}
