import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/provider_dashboard_state.dart';
import '../operations/operator_shell.dart';

/// Charts and rates for the workshop's own numbers — real, server-computed
/// figures (`workshopDashboardEarningsProvider`/`workshopDashboardMetricsProvider`,
/// see `provider_dashboard_state.dart`) that had no screen of their own
/// before this one. The dashboard home shows four snapshot KPIs; this is
/// where a workshop reads its own trend rather than a single number.
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _windowDays = 30;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final earnings = ref.watch(workshopDashboardEarningsProvider(_windowDays));
    final metrics = ref.watch(workshopDashboardMetricsProvider(_windowDays));

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('الإحصائيات', 'Statistics'))),
      body: SafeArea(
        // Every other dashboard screen pulls to refresh; this one did not,
        // so the only way to re-read the figures was to leave and come back.
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(workshopDashboardEarningsProvider(_windowDays));
            ref.invalidate(workshopDashboardMetricsProvider(_windowDays));
            await Future.wait([
              ref.read(workshopDashboardEarningsProvider(_windowDays).future),
              ref.read(workshopDashboardMetricsProvider(_windowDays).future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.md,
              AppSpacing.screenMargin,
              AppSpacing.xxl,
            ),
            children: [
              Row(
                children: [
                  for (final (days, label) in [
                    (7, s.t('٧ أيام', '7d')),
                    (30, s.t('٣٠ يوم', '30d')),
                    (90, s.t('٩٠ يوم', '90d')),
                  ]) ...[
                    SelectChip(
                      label: label,
                      selected: _windowDays == days,
                      onTap: () => setState(() => _windowDays = days),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(s.t('صافي الأرباح', 'Net earnings')),
              const SizedBox(height: AppSpacing.headingGap),
              earnings.when(
                loading: () => const Skeleton(height: 180),
                error: (error, _) => _ChartError(s: s),
                data: (data) => _EarningsChart(s: s, earnings: data),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              SectionHeader(s.t('الأداء', 'Performance')),
              const SizedBox(height: AppSpacing.headingGap),
              metrics.when(
                loading: () => const Column(
                  children: [MetricSkeleton(count: 3), SizedBox(height: 12)],
                ),
                error: (error, _) => _ChartError(s: s),
                data: (data) =>
                    _PerformanceSection(s: s, ak: ak, metrics: data),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              SectionHeader(s.t('إدارة الورشة', 'Running the workshop')),
              const SizedBox(height: AppSpacing.headingGap),
              metrics.when(
                loading: () => const MetricSkeleton(count: 2),
                error: (error, _) => _ChartError(s: s),
                data: (data) => switch (data.business) {
                  final WorkshopBusinessKpis business => _BusinessSection(
                    s: s,
                    ak: ak,
                    business: business,
                  ),
                  null => EmptyState(
                    compact: true,
                    icon: LucideIcons.chartNoAxesColumn,
                    message: s.t(
                      'تظهر هذه الأرقام بعد تحديث الخادم.',
                      'These figures appear once the server is updated.',
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartError extends StatelessWidget {
  const _ChartError({required this.s});

  final S s;

  @override
  Widget build(BuildContext context) => EmptyState(
    compact: true,
    icon: LucideIcons.circleAlert,
    message: s.t('تعذّر تحميل الأرقام.', 'Couldn\'t load these figures.'),
  );
}

/// A bar per bucket of [WorkshopEarnings.lines], net of commission — capped
/// at 14 bars regardless of the window so a 90-day view reads as weeks, not
/// as ninety illegible slivers.
class _EarningsChart extends StatelessWidget {
  const _EarningsChart({required this.s, required this.earnings});

  final S s;
  final WorkshopEarnings earnings;

  static const _maxBuckets = 14;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final windowDays = earnings.window.inDays.clamp(1, 3650);
    final bucketDays = (windowDays / _maxBuckets).ceil().clamp(1, windowDays);
    final bucketCount = (windowDays / bucketDays).ceil();
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: windowDays - 1));

    final totals = List<double>.filled(bucketCount, 0);
    for (final line in earnings.lines) {
      final day = DateTime(line.at.year, line.at.month, line.at.day);
      final offset = day.difference(start).inDays;
      if (offset < 0 || offset >= windowDays) continue;
      final idx = (offset / bucketDays).floor().clamp(0, bucketCount - 1);
      totals[idx] += line.net;
    }

    if (earnings.lines.isEmpty) {
      return EmptyState(
        compact: true,
        icon: LucideIcons.chartNoAxesColumn,
        message: s.t(
          'لا معاملات في هذه الفترة بعد.',
          'No transactions in this window yet.',
        ),
      );
    }

    final maxY = totals.fold<double>(0, (m, v) => v > m ? v : m);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RialAmount(earnings.releasedNet, style: context.text.price),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            s.t(
              'صافي بعد عمولة ${earnings.releasedCommission.toStringAsFixed(2)} خلال ${s.days(windowDays)}',
              'Net after ${earnings.releasedCommission.toStringAsFixed(2)} commission over ${s.days(windowDays)}',
            ),
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: maxY <= 0 ? 1 : maxY * 1.2,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY <= 0 ? 1 : maxY / 2,
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
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx != 0 && idx != bucketCount - 1) {
                          return const SizedBox.shrink();
                        }
                        final day = start.add(Duration(days: idx * bucketDays));
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${day.month}/${day.day}',
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
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                          rod.toY.toStringAsFixed(2),
                          TextStyle(color: ak.bg, fontSize: 11),
                        ),
                  ),
                ),
                barGroups: [
                  for (final (i, total) in totals.indexed)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: total,
                          color: ak.primary,
                          width: bucketCount > 20 ? 4 : 10,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection({
    required this.s,
    required this.ak,
    required this.metrics,
  });

  final S s;
  final AkColors ak;
  final WorkshopMetrics metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return EmptyState(
        compact: true,
        icon: LucideIcons.chartNoAxesColumn,
        message: s.t(
          'لا أرقام أداء بعد — تظهر بعد أول طلب.',
          'No performance figures yet — these appear after your first job.',
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: Text(_percent(metrics.acceptanceRate)),
                label: s.t('نسبة القبول', 'Acceptance rate'),
                hint: s.t(
                  '${metrics.accepted} من ${metrics.received}',
                  '${metrics.accepted} of ${metrics.received}',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: Text(_percent(metrics.completionRate)),
                label: s.t('نسبة الإنجاز', 'Completion rate'),
                hint: s.t(
                  '${metrics.completed} من ${metrics.accepted}',
                  '${metrics.completed} of ${metrics.accepted}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.itemGap),
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: Text(_percent(metrics.disputeRate)),
                label: s.t('نسبة النزاعات', 'Dispute rate'),
                tone: (metrics.disputeRate ?? 0) > 0.1 ? ak.danger : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: Text(
                  metrics.avgRating == null
                      ? '—'
                      : metrics.avgRating!.toStringAsFixed(1),
                ),
                label: s.t('التقييم', 'Rating'),
                hint: s.reviews(metrics.reviewCount),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _percent(double? rate) =>
      rate == null ? '—' : '${(rate * 100).round()}%';
}

/// The shop-management figures (2026-09-15): average repair order, repeat
/// customers, extra work, margin, check-in discipline and time in the shop.
class _BusinessSection extends StatelessWidget {
  const _BusinessSection({
    required this.s,
    required this.ak,
    required this.business,
  });

  final S s;
  final AkColors ak;
  final WorkshopBusinessKpis business;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final aro = b.averageRepairOrder;
    final days = b.avgDaysInShop;
    final coverage = b.checkInCoverage;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: aro == null ? const Text('—') : RialAmount(aro),
                label: s.t('متوسط قيمة الطلب', 'Avg repair order'),
                hint: s.t('${b.carCount} سيارة', '${b.carCount} cars'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: Text(_PerformanceSection._percent(b.repeatCustomerRate)),
                label: s.t('عملاء عائدون', 'Repeat customers'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.itemGap),
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: Text(
                  _PerformanceSection._percent(b.extraWorkApprovalRate),
                ),
                label: s.t('قبول الأعمال الإضافية', 'Extra work approved'),
                hint: s.t(
                  'أُضيف ${b.extraWorkRevenue.toStringAsFixed(2)} ر.ع',
                  'OMR ${b.extraWorkRevenue.toStringAsFixed(2)} added',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: RialAmount(b.grossProfit),
                label: s.t('إجمالي الربح', 'Gross profit'),
                hint: s.t('الإيراد ناقص تكلفة القطع', 'Revenue minus parts cost'),
                tone: b.grossProfit < 0 ? ak.danger : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.itemGap),
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: Text(_PerformanceSection._percent(coverage)),
                label: s.t('تغطية الاستلام', 'Check-in coverage'),
                tone: coverage != null && coverage < 0.8 ? ak.amberText : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: Text(
                  days == null
                      ? '—'
                      : s.t(
                          '${days.toStringAsFixed(1)} يوم',
                          '${days.toStringAsFixed(1)} days',
                        ),
                ),
                label: s.t('متوسط البقاء في الورشة', 'Avg days in shop'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
