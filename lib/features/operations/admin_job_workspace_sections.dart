import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../state/job_workspace_state.dart';
import '../services/job_media_widgets.dart';
import 'admin_panel_widgets.dart';

/// The founder's side of the job workspace (2026-09-15): the extra-work
/// funding queue for the Money tab, and the per-workshop performance table
/// for the Workshops tab.

/// Extra work the customer approved, waiting for the founder to confirm the
/// added amount is held — the same promise the original booking made.
class AdminExtraWorkFundingSection extends ConsumerWidget {
  const AdminExtraWorkFundingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final queue = ref.watch(founderExtraWorkQueueProvider);
    final count = queue.valueOrNull?.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminGroupHeader(
          icon: LucideIcons.wrench,
          title: s.t('أعمال إضافية بانتظار تأكيد المبلغ', 'Extra work to fund'),
          count: count,
          tone: (count ?? 0) == 0 ? AdminChipTone.normal : AdminChipTone.warn,
        ),
        const SizedBox(height: AppSpacing.headingGap),
        queue.when(
          loading: () => const Skeleton(height: 96),
          error: (error, _) => EmptyState(
            compact: true,
            icon: LucideIcons.circleAlert,
            message: jobWorkspaceErrorText(s, error),
          ),
          data: (items) => items.isEmpty
              ? EmptyState(
                  compact: true,
                  icon: LucideIcons.wrench,
                  message: s.t(
                    'لا أعمال إضافية موافق عليها بانتظارك.',
                    'No approved extra work is waiting on you.',
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, item) in items.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      _FundingCard(item: item),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _FundingCard extends ConsumerStatefulWidget {
  const _FundingCard({required this.item});

  final ExtraWorkQueueItem item;

  @override
  ConsumerState<_FundingCard> createState() => _FundingCardState();
}

class _FundingCardState extends ConsumerState<_FundingCard> {
  bool _busy = false;

  Future<void> _confirm() async {
    final s = S.of(context);
    final extra = widget.item.extraWork;
    final amount = extra.amount.toStringAsFixed(2);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('تأكيد حجز المبلغ', 'Confirm the funds')),
        content: Text(
          s.t(
            'أكّد أن $amount ر.ع الإضافية محجوزة فعلياً. ستُبلَّغ الورشة بالبدء.',
            'Confirm the extra OMR $amount is actually held. The workshop is told to go ahead.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('نعم، محجوز', 'Yes, it is held')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await runJobAction(
      context,
      () => ref.read(jobWorkspaceServiceProvider).confirmExtraWorkFunds(extra.id),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(founderExtraWorkQueueProvider);
      // The booking's total and escrow card moved too.
      ref.read(operatorQueueProvider.notifier).refresh().ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final item = widget.item;
    final extra = item.extraWork;

    return UrgencyCard(
      level: UrgencyLevel.upcoming,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.providerName.of(s),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.cardTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              RialAmount(extra.amount, style: context.text.price),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [item.customerName, item.plate].where((v) => v.isNotEmpty).join(' · '),
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(extra.description, style: context.text.bodyPrimary),
          if (extra.respondedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.t(
                'وافق العميل في ${formatJobDate(extra.respondedAt!)}',
                'Customer approved on ${formatJobDate(extra.respondedAt!)}',
              ),
              style: context.text.bodySecondary,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : _confirm,
            icon: const Icon(LucideIcons.check, size: 16),
            label: Text(s.t('تأكيد حجز المبلغ', 'Confirm funds held')),
          ),
        ],
      ),
    );
  }
}

/// How each workshop is doing over the last [windowDays] days, from real
/// bookings — one card per workshop, most completed jobs first (server order).
class AdminWorkshopPerformanceSection extends ConsumerWidget {
  const AdminWorkshopPerformanceSection({super.key});

  static const windowDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final rows = ref.watch(founderWorkshopPerformanceProvider(windowDays));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminGroupHeader(
          icon: LucideIcons.chartNoAxesColumn,
          title: s.t('أداء الورش (٣٠ يوماً)', 'Workshop performance (30 days)'),
          count: rows.valueOrNull?.length,
        ),
        const SizedBox(height: AppSpacing.headingGap),
        rows.when(
          loading: () => const Skeleton(height: 120),
          error: (error, _) => EmptyState(
            compact: true,
            icon: LucideIcons.circleAlert,
            message: jobWorkspaceErrorText(s, error),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(
                  compact: true,
                  icon: LucideIcons.chartNoAxesColumn,
                  message: s.t(
                    'لا نشاط للورش في آخر ٣٠ يوماً.',
                    'No workshop activity in the last 30 days.',
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, row) in list.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      _PerformanceCard(row: row),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.row});

  final WorkshopPerformanceRow row;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final rating = row.avgRating;
    final aro = row.averageRepairOrder;

    return AppCard(
      onTap: () => context.push('/admin/workshops/${row.providerId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name.of(s),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.cardTitle,
                ),
              ),
              if (rating != null) ...[
                Icon(LucideIcons.star, size: 14, color: ak.amberText),
                const SizedBox(width: 3),
                Text(
                  '${rating.toStringAsFixed(1)} (${row.reviewCount})',
                  style: context.text.labelStrong,
                ),
              ],
            ],
          ),
          if (row.region.isNotEmpty)
            Text(row.region, style: context.text.bodySecondary),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _Figure(value: Text('${row.completed}'), label: s.t('مكتمل', 'Completed')),
              _Figure(value: RialAmount(row.releasedGross), label: s.t('محرَّر', 'Released')),
              _Figure(
                value: aro == null ? const Text('—') : RialAmount(aro),
                label: s.t('متوسط الفاتورة', 'Avg repair order'),
              ),
              _Figure(
                value: Text(formatJobRate(row.disputeRate)),
                label: s.t('النزاعات', 'Disputes'),
                tone: (row.disputeRate ?? 0) > 0.1 ? ak.danger : null,
              ),
              _Figure(
                value: Text(formatJobRate(row.extraWorkApprovalRate)),
                label: s.t('قبول الأعمال الإضافية', 'Extra work approved'),
              ),
              _Figure(
                value: Text(formatJobRate(row.checkInCoverage)),
                label: s.t('تغطية الاستلام', 'Check-in coverage'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, this.tone});

  final Widget value;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      DefaultTextStyle.merge(
        style: context.text.labelStrong.copyWith(color: tone),
        child: value,
      ),
      const SizedBox(height: 2),
      Text(label, style: context.text.bodySecondary.copyWith(fontSize: 11)),
    ],
  );
}
