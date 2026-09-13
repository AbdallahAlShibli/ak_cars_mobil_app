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

/// The overview for a workshop owner's own dashboard.
///
/// Laid out as a priority ladder rather than a flat grid of equal tiles,
/// which is what it used to be — four same-sized KPIs where "3 jobs are
/// waiting on you" and "your average rating" carried identical visual weight,
/// so nothing on the screen said what to do first. The order now is:
///
///  1. **Alerts** — the only things that are wrong right now.
///  2. **Needs your action** — one number, in the largest type on the screen,
///     tappable straight through to the job list. This is the question a
///     workshop opens the app to answer.
///  3. **Today** — booked today, in progress, awaiting the customer.
///  4. **Money** — held in escrow and payout due, with the standing
///     off-app-transfer caveat attached to the figures it qualifies rather
///     than floating loose further down the page.
///  5. **Health** — stock, rating, customers, team: things to keep an eye on,
///     not things to act on this minute.
///  6. **Quick actions** — plain navigation, last.
///
/// Every figure is a drill-down: tapping it opens the list that produced the
/// number, so a count is never a dead end.
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
      appBar: AppBar(
        title: Text(s.t('لوحة الورشة', 'Workshop dashboard')),
        // This screen is reached via `context.go(...)` from the "My business"
        // card in My account, which replaces the navigation stack rather than
        // pushing onto it — GoRouter never adds its own back arrow here, so
        // without this a workshop owner had no way back short of the OS back
        // gesture.
        leading: IconButton(
          icon: const BackButtonIcon(),
          tooltip: s.t('العودة إلى حسابي', 'Back to my account'),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(workshopSummaryProvider.notifier).refresh(),
          child: summary.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: const [
                Skeleton(height: 64, radius: 18),
                SizedBox(height: AppSpacing.md),
                Skeleton(height: 104, radius: 18),
                SizedBox(height: AppSpacing.md),
                MetricSkeleton(count: 3),
                SizedBox(height: AppSpacing.md),
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
    final jobs = summary.jobs;
    final money = summary.money;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.md,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        _WorkshopIdentityStrip(s: s, provider: summary.provider),
        const SizedBox(height: AppSpacing.md),
        if (summary.alerts.isNotEmpty) ...[
          _AlertsStrip(s: s, alerts: summary.alerts),
          const SizedBox(height: AppSpacing.md),
        ],
        _NeedsYouCard(s: s, jobs: jobs),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          s.t('اليوم', 'Today'),
          action: s.t('كل الطلبات', 'All jobs'),
          onAction: () => context.push('/workshop/dashboard/orders'),
        ),
        const SizedBox(height: AppSpacing.headingGap),
        Row(
          children: [
            Expanded(
              child: _Figure(
                value: '${jobs.todays}',
                label: s.t('محجوز اليوم', 'Booked today'),
                onTap: () => context.push('/workshop/dashboard/schedule'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Figure(
                value: '${jobs.inProgress}',
                label: s.t('قيد التنفيذ', 'In progress'),
                onTap: () => context.push('/workshop/dashboard/orders'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Figure(
                value: '${jobs.awaitingApproval}',
                label: s.t('بانتظار العميل', 'Awaiting customer'),
                onTap: () => context.push('/workshop/dashboard/orders'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(
          s.t('الأموال', 'Money'),
          action: s.t('التفاصيل', 'Details'),
          onAction: () => context.push('/workshop/dashboard/statistics'),
        ),
        const SizedBox(height: AppSpacing.headingGap),
        AppCard(
          onTap: () => context.push('/workshop/dashboard/statistics'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _InlineAmount(
                      amount: money.heldInEscrow,
                      label: s.t('محجوز في الضمان', 'Held in escrow'),
                    ),
                  ),
                  Container(width: 1, height: 34, color: ak.divider),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _InlineAmount(
                      amount: money.payoutDue,
                      label: s.t('مستحق لك', 'Payout due'),
                      tone: money.payoutDue > 0 ? ak.success : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              OffAppTransferNotice(
                s.t(
                  'المبالغ هنا للاطلاع فقط — التحويلات الفعلية تتم خارج التطبيق حالياً.',
                  'Figures here are informational — actual transfers still happen outside the app.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('حالة الورشة', 'Workshop health')),
        const SizedBox(height: AppSpacing.headingGap),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          // 1.6, not something flatter: 'Low stock items' wraps to two lines
          // in English and still has a hint line under it, which overflowed a
          // shorter tile.
          childAspectRatio: 1.6,
          children: [
            _Figure(
              value: '${summary.stock.lowStock}',
              label: s.t('مخزون منخفض', 'Low stock items'),
              hint: s.t(
                'من ${summary.stock.items}',
                'of ${summary.stock.items}',
              ),
              tone: summary.stock.lowStock > 0 ? ak.dangerText : null,
              onTap: () => context.push('/workshop/dashboard/inventory'),
            ),
            _Figure(
              value: summary.rating.avg == null
                  ? '—'
                  : summary.rating.avg!.toStringAsFixed(1),
              label: s.t('التقييم', 'Rating'),
              hint: s.reviews(summary.rating.reviewCount),
              onTap: () => context.push('/workshop/dashboard/statistics'),
            ),
            _Figure(
              value: '${summary.people.customers}',
              label: s.t('العملاء', 'Customers'),
              onTap: () => context.push('/workshop/dashboard/customers'),
            ),
            _Figure(
              value: '${summary.people.activeStaff}',
              label: s.t('الفريق النشط', 'Active team'),
              onTap: () => context.push('/workshop/dashboard/staff'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('إجراءات سريعة', 'Quick actions')),
        const SizedBox(height: AppSpacing.headingGap),
        _QuickActionsGrid(s: s),
      ],
    );
  }
}

/// Whose dashboard this is — name, where, and whether the platform still has
/// it switched on. Costs no extra request: `/my-workshop/summary` already
/// carries the provider, and it used to be thrown away.
class _WorkshopIdentityStrip extends StatelessWidget {
  const _WorkshopIdentityStrip({required this.s, required this.provider});

  final S s;
  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final where = [
      provider.area,
      provider.region,
    ].where((p) => p.trim().isNotEmpty).join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push('/workshop/dashboard/profile'),
      child: Row(
        children: [
          IconTile(
            LucideIcons.store,
            size: 40,
            radius: 13,
            background: ak.surfaceDim,
            foreground: ak.ink,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.name.of(s),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.cardTitle,
                ),
                if (where.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySecondary,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          provider.isApproved
              ? StatusBadge.good(s.t('مفتوحة', 'Live'))
              : StatusBadge.warn(provider.stage.label(s)),
        ],
      ),
    );
  }
}

/// The one thing this screen exists to answer, in the largest type on it.
///
/// Reads as a plain "you're clear" card at zero rather than a grey zero in a
/// grid — an empty queue is good news and should look like it, not like a
/// number that failed to load.
class _NeedsYouCard extends StatelessWidget {
  const _NeedsYouCard({required this.s, required this.jobs});

  final S s;
  final WorkshopSummaryJobs jobs;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final waiting = jobs.needsYou > 0;
    final overdue = jobs.overdue;

    return AppCard(
      color: waiting ? ak.amberBgSoft : ak.surface,
      border: Border.all(color: waiting ? ak.amberBorder : ak.border),
      onTap: () => context.push('/workshop/dashboard/orders'),
      child: Row(
        children: [
          IconTile(
            waiting ? LucideIcons.bellRing : LucideIcons.circleCheck,
            size: 44,
            radius: 14,
            background: waiting ? ak.amberSoft : ak.successSoft,
            foreground: waiting ? ak.amberDeep : ak.success,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waiting ? '${jobs.needsYou}' : '—',
                  style: context.text.price.copyWith(
                    fontSize: 30,
                    height: 1.1,
                    color: waiting ? ak.amberDeep : ak.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  waiting
                      ? s.t('طلبات تنتظر إجراءك', 'jobs waiting on you')
                      : s.t('لا شيء ينتظرك الآن', 'Nothing is waiting on you'),
                  style: context.text.bodyPrimary.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (overdue > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    s.t(
                      'منها $overdue تجاوزت الوقت المتفق عليه',
                      '$overdue of them are past the agreed window',
                    ),
                    style: context.text.bodySecondary.copyWith(
                      color: ak.dangerText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevronLeft
                : LucideIcons.chevronRight,
            size: 18,
            color: ak.inkSub,
          ),
        ],
      ),
    );
  }
}

/// One amount inside the money card.
class _InlineAmount extends StatelessWidget {
  const _InlineAmount({required this.amount, required this.label, this.tone});

  final double amount;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RialAmount(
        amount,
        style: context.text.price.copyWith(color: tone),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(label, style: context.text.bodySecondary),
    ],
  );
}

/// A tappable figure tile. Same visual language as [OperatorFigure] — which
/// has no `onTap` and is still the right thing on the founder panel, where
/// several of its figures have no single list to drill into — plus the tap
/// target every figure on this screen needs.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    required this.onTap,
    this.hint,
    this.tone,
  });

  final String value;
  final String label;
  final VoidCallback onTap;
  final String? hint;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.price.copyWith(color: tone),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySecondary,
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySecondary.copyWith(
                fontSize: 10.5,
                color: ak.inkFaint,
              ),
            ),
          ],
        ],
      ),
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
                      Directionality.of(context) == TextDirection.rtl
                          ? LucideIcons.chevronLeft
                          : LucideIcons.chevronRight,
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
    // Ordered the way a workshop's day runs — what came in, when it is due,
    // what you sell, what you stock, who does the work, then the settings
    // behind all of it. "Workshop profile", not "Profile": the account
    // profile is a different screen in this same app, and two things called
    // the same thing is how someone ends up editing their own phone number
    // when they meant the shop's.
    final actions = <(IconData, String, String)>[
      (
        LucideIcons.clipboardList,
        s.t('الطلبات', 'Jobs'),
        '/workshop/dashboard/orders',
      ),
      (
        LucideIcons.calendarClock,
        s.t('الجدول', 'Schedule'),
        '/workshop/dashboard/schedule',
      ),
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
      (LucideIcons.users, s.t('الفريق', 'Team'), '/workshop/dashboard/staff'),
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
        LucideIcons.store,
        s.t('ملف الورشة', 'Workshop profile'),
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
