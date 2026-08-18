import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

/// The modern overview for a workshop owner's own dashboard — KPI cards,
/// an alerts strip, today's schedule, and quick actions into every section.
///
/// Reachable only once `_guardOperatorPanels` (app_router.dart) confirms the
/// signed-in account owns an approved workshop: every figure here comes from
/// `/my-workshop/summary`, which resolves ownership from the JWT server-side
/// and has no "first approved workshop" fallback to stand in for an account
/// that never applied — see `provider_dashboard_state.dart`'s file doc
/// comment for the full reasoning.
class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final summary = ref.watch(workshopSummaryProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('لوحة الورشة', 'Workshop dashboard'))),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(workshopSummaryProvider.notifier).refresh(),
          child: summary.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: const [
                MetricSkeleton(count: 3),
                SizedBox(height: 16),
                ListSkeleton(),
              ],
            ),
            error: (error, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                EmptyState(
                  icon: LucideIcons.circleAlert,
                  title: s.t(
                    'تعذّر تحميل اللوحة',
                    'Couldn\'t load the dashboard',
                  ),
                  message: s.t(
                    'تحقق من الاتصال وحاول مرة أخرى.',
                    'Check your connection and try again.',
                  ),
                  action: FilledButton(
                    onPressed: () =>
                        ref.read(workshopSummaryProvider.notifier).refresh(),
                    child: Text(s.t('إعادة المحاولة', 'Retry')),
                  ),
                ),
              ],
            ),
            data: (data) => _DashboardBody(ak: ak, s: s, summary: data),
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.ak,
    required this.s,
    required this.summary,
  });

  final AkColors ak;
  final S s;
  final WorkshopSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.md,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        if (summary.alerts.isNotEmpty) ...[
          _AlertsStrip(s: s, alerts: summary.alerts),
          const SizedBox(height: AppSpacing.md),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.5,
          children: [
            OperatorFigure(
              value: Text('${summary.jobs.needsYou}'),
              label: s.t('يحتاج إجراءك', 'Needs your action'),
              tone: summary.jobs.needsYou > 0 ? ak.amberText : null,
            ),
            OperatorFigure(
              value: RialAmount(summary.money.heldInEscrow),
              label: s.t('محجوز في الضمان', 'Held in escrow'),
            ),
            OperatorFigure(
              value: Text('${summary.stock.lowStock}'),
              label: s.t('مخزون منخفض', 'Low stock items'),
              tone: summary.stock.lowStock > 0 ? ak.dangerText : null,
            ),
            OperatorFigure(
              value: Text(
                summary.rating.avg == null
                    ? '—'
                    : summary.rating.avg!.toStringAsFixed(1),
              ),
              label: s.t('التقييم', 'Rating'),
              hint: s.reviews(summary.rating.reviewCount),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        OffAppTransferNotice(
          s.t(
            'المبالغ هنا للاطلاع فقط — التحويلات الفعلية تتم خارج التطبيق حالياً.',
            'Figures here are informational — actual transfers still happen outside the app.',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(s.t('إجراءات سريعة', 'Quick actions')),
        const SizedBox(height: AppSpacing.sm),
        _QuickActionsGrid(s: s),
      ],
    );
  }
}

class _AlertsStrip extends StatelessWidget {
  const _AlertsStrip({required this.s, required this.alerts});

  final S s;
  final List<WorkshopAlert> alerts;

  String _label(WorkshopAlert alert) => switch (alert.code) {
    'low_stock' => s.t(
      '${alert.count} عناصر منخفضة المخزون',
      '${alert.count} items low on stock',
    ),
    'overdue_jobs' => s.t(
      '${alert.count} طلبات تجاوزت الوقت',
      '${alert.count} jobs past the window',
    ),
    _ => '${alert.code} · ${alert.count}',
  };

  String _route(WorkshopAlert alert) => switch (alert.code) {
    'low_stock' => '/workshop/dashboard/inventory',
    'overdue_jobs' => '/workshop/dashboard/orders',
    _ => '/workshop/dashboard',
  };

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      children: [
        for (final alert in alerts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(_route(alert)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: ak.amberBgSoft,
                  border: Border.all(color: ak.amberBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: 15,
                      color: ak.amberDeep,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _label(alert),
                        style: context.text.bodySecondary.copyWith(
                          color: ak.amberDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronLeft,
                      size: 15,
                      color: ak.amberDeep,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.s});

  final S s;

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, String)>[
      (
        LucideIcons.wrench,
        s.t('الخدمات', 'Offerings'),
        '/workshop/dashboard/offerings',
      ),
      (
        LucideIcons.puzzle,
        s.t('الإضافات', 'Add-ons'),
        '/workshop/dashboard/add-ons',
      ),
      (
        LucideIcons.boxes,
        s.t('المخزون', 'Inventory'),
        '/workshop/dashboard/inventory',
      ),
      (
        LucideIcons.clipboardList,
        s.t('الطلبات', 'Orders'),
        '/workshop/dashboard/orders',
      ),
      (LucideIcons.users, s.t('الفريق', 'Staff'), '/workshop/dashboard/staff'),
      (
        LucideIcons.contact,
        s.t('العملاء', 'Customers'),
        '/workshop/dashboard/customers',
      ),
      (
        LucideIcons.chartNoAxesColumn,
        s.t('الإحصائيات', 'Statistics'),
        '/workshop/dashboard/statistics',
      ),
      (
        LucideIcons.calendarClock,
        s.t('الجدول', 'Schedule'),
        '/workshop/dashboard/schedule',
      ),
      (
        LucideIcons.store,
        s.t('الملف الشخصي', 'Profile'),
        '/workshop/dashboard/profile',
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.85,
      children: [
        for (final (icon, label, route) in actions)
          _QuickActionTile(
            icon: icon,
            label: label,
            onTap: () => context.push(route),
          ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon, background: ak.surfaceDim, foreground: ak.ink),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySecondary.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
