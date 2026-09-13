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
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'admin_form_widgets.dart';
import 'admin_panel_widgets.dart';

/// The escrow ledger and what each workshop is owed (§5 tab 3).
///
/// Nothing here moves money, and the tab says so three times — in the panel's
/// standing banner, in the summary card's footnote, and in the confirmation
/// beside the button. "Mark as paid" records that a bank transfer happened; it
/// is a note, not a transaction, and a button that implied otherwise would be
/// the most misleading control in the app.
class AdminMoneyTab extends ConsumerWidget {
  const AdminMoneyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final requests = ref.watch(operatorQueueProvider);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final outstanding = ref.watch(outstandingByProviderProvider);
    final ledger = ref.watch(payoutsProvider);
    final config = ref.watch(appConfigProvider);

    final held = requests.fold<double>(
      0,
      (sum, r) => r.escrow.holdsFunds ? sum + r.total : sum,
    );
    final cutoff = DateTime.now().subtract(config.earningsWindow);
    final released = requests.fold<double>(
      0,
      (sum, r) =>
          r.escrow == EscrowState.releasedToWorkshop &&
              !r.inCurrentStateSince.isBefore(cutoff)
          ? sum + r.total
          : sum,
    );
    final refunded = requests.fold<double>(
      0,
      (sum, r) => r.escrow == EscrowState.refunded ? sum + r.total : sum,
    );
    final owed = [
      for (final entry in outstanding.entries)
        if (entry.value > 0.005) entry,
    ]..sort((a, b) => b.value.compareTo(a.value));
    final owedTotal = owed.fold<double>(0, (sum, e) => sum + e.value);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        AdminSummaryCard(
          icon: LucideIcons.banknote,
          title: s.t('دفتر الضمان', 'Escrow ledger'),
          subtitle: s.t(
            'أين المال الآن، ولمن.',
            'Where the money is right now, and whose it is.',
          ),
          stats: [
            AdminStat(
              value: RialAmount(held),
              label: s.t('محجوز الآن', 'Held now'),
            ),
            AdminStat(
              value: RialAmount(released),
              label: s.t(
                'حُرِّر خلال ${s.days(config.earningsWindow.inDays)}',
                'Released in ${config.earningsWindow.inDays}d',
              ),
              color: ak.success,
            ),
            AdminStat(
              value: RialAmount(refunded),
              label: s.t('مُعاد للعملاء', 'Refunded'),
              color: refunded > 0 ? ak.amberText : null,
            ),
          ],
          chips: [
            AdminMetaChip(
              icon: LucideIcons.scale,
              tone: owed.isEmpty ? AdminChipTone.good : AdminChipTone.warn,
              child: RialAmount(
                owedTotal,
                prefix: '${s.t('مستحق للورش', 'Owed to workshops')} · ',
              ),
            ),
          ],
          footnote: s.t(
            'المحجوز يشمل الطلبات المتنازع عليها. التطبيق لا يحوّل شيئاً — '
                'كل ما هنا تسجيل لتحويلات تمت خارجه.',
            'Held includes disputed jobs. The app transfers nothing — '
                'everything here records transfers made outside it.',
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        AdminGroupHeader(
          icon: LucideIcons.scale,
          title: s.t('مستحقات الورش', 'Owed to workshops'),
          count: owed.length,
          tone: owed.isEmpty ? AdminChipTone.normal : AdminChipTone.warn,
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (owed.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.banknote,
            message: s.t(
              'لا مستحقات قائمة — كل ما حُرِّر سُجِّل تحويله.',
              'Nothing outstanding — every release has a transfer recorded '
                  'against it.',
            ),
          )
        else
          for (final (i, entry) in owed.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _OwedCard(
              provider: marketplace.providerById(entry.key)!,
              amount: entry.value,
            ),
          ],
        const SizedBox(height: AppSpacing.sectionGap),

        AdminGroupHeader(
          icon: LucideIcons.receipt,
          title: s.t('تحويلات مسجَّلة', 'Recorded transfers'),
          count: ledger.length,
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (ledger.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.receipt,
            message: s.t(
              'لم تسجَّل أي تحويلات بعد.',
              'No transfers recorded yet.',
            ),
          )
        else
          for (final (i, record) in ledger.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _PayoutCard(
              record: record,
              provider: marketplace.providerById(record.providerId),
            ),
          ],
      ],
    );
  }
}

/// What one workshop is owed, and the note that says it was sent.
class _OwedCard extends ConsumerWidget {
  const _OwedCard({required this.provider, required this.amount});

  final ServiceProvider provider;
  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                IconTile(LucideIcons.store, size: 42, radius: 14),
                const SizedBox(width: AppSpacing.md),
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
                      const SizedBox(height: 3),
                      Text(
                        '${provider.area} · ${provider.region}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                RialAmount(amount, style: context.text.price),
              ],
            ),
          ),
          const AdminInsetDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.md,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AdminMetaChip(
                icon: LucideIcons.info,
                label: s.t(
                  'صافٍ بعد العمولة وبعد ما سُجِّل تحويله',
                  'Net of commission and of what is already recorded',
                ),
              ),
            ),
          ),
          const AdminInsetDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: () => _markPaid(context, ref),
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: Text(s.t('علّم كمدفوع', 'Mark as paid')),
                    ),
                  ),
                ),
                AdminCardAction(
                  icon: LucideIcons.chevronLeft,
                  tooltip: s.t('إدارة الورشة', 'Manage workshop'),
                  onTap: () => context.push('/admin/workshops/${provider.id}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('تسجيل تحويل', 'Record a transfer')),
        content: Builder(
          builder: (context) {
            final style = dialogContext.text.bodyPrimary.copyWith(height: 1.6);
            return Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(
                    text: s.t(
                      'هذا تسجيل فقط: التطبيق لا يحوّل شيئاً. أكّد أنك حوّلت ',
                      'This only records it — the app transfers nothing. '
                          'Confirm that you have actually sent ',
                    ),
                  ),
                  rialAmountSpan(amount: amount, style: style),
                  TextSpan(
                    text: s.t(
                      ' إلى ${provider.name.of(s)} فعلياً.',
                      ' to ${provider.name.of(s)}.',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('نعم، حوّلته', 'Yes, I sent it')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final now = DateTime.now();
    await ref
        .read(adminActionsProvider)
        .markPaid(
          providerId: provider.id,
          amount: amount,
          // The period is everything up to now that was not already settled,
          // which is exactly what the outstanding figure was computed over.
          periodFrom: now.subtract(const Duration(days: 3650)),
          periodTo: now,
        );
  }
}

/// One line of the transfer ledger — history, not a queue, so it is quieter
/// than the cards above it and carries no controls at all.
class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.record, required this.provider});

  final PayoutRecord record;
  final ServiceProvider? provider;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return AppCard(
      color: ak.surfaceDim,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconTile(
            LucideIcons.receipt,
            size: 34,
            radius: 12,
            background: ak.surface,
            foreground: ak.inkSub,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider?.name.of(s) ?? record.providerId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyPrimary,
                ),
                const SizedBox(height: 3),
                Text(
                  record.note == null
                      ? formatAdminDate(record.markedAt)
                      : '${formatAdminDate(record.markedAt)} · ${record.note}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySecondary.copyWith(
                    color: ak.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          RialAmount(record.amount, style: context.text.labelStrong),
        ],
      ),
    );
  }
}
