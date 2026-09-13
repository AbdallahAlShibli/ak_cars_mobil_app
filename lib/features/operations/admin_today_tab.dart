import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/escrow_timeline.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'admin_panel_widgets.dart';
import 'escrow_action_bar.dart';
import 'queue_urgency.dart';

/// Everything waiting on the founder, in the order it should be cleared:
/// disputes first (a customer *and* a workshop are both stuck), then
/// unconfirmed money, then applications, then the automatic release that is
/// about to fire on its own.
///
/// The ordering is the screen's only opinion, and it is deliberate. Every other
/// tab is a place to look something up; this one is a to-do list, so the top of
/// it has to be the thing whose delay costs the most.
class AdminTodayTab extends ConsumerWidget {
  const AdminTodayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final requests = ref.watch(operatorQueueProvider);
    final window = ref.watch(appConfigProvider).approvalWindow;
    final pending = ref.watch(pendingApplicationsProvider);

    final needsFunds = [
      for (final r in requests)
        if (r.escrow == EscrowState.createdPendingPayment) r,
    ];
    final disputes = [
      for (final r in requests)
        if (r.escrow == EscrowState.disputed) r,
    ];
    final running = [
      for (final r in requests)
        if (!r.escrow.isTerminal &&
            r.escrow != EscrowState.createdPendingPayment &&
            r.escrow != EscrowState.disputed)
          r,
    ];
    // Approval windows that have already lapsed. The release is automatic, but
    // the founder should be able to see which ones are about to move without
    // anyone touching them — a silent automatic release is indistinguishable
    // from the app taking the workshop's side.
    final lapsing = [
      for (final r in requests)
        if (r.autoReleaseDue(window)) r,
    ];
    // Every booking whose money is actually being held — which includes the
    // disputed ones. They are listed in their own section rather than under
    // "in flight", but the funds have not moved: the dispute notification tells
    // the customer "the funds stay held", so the founder's total has to agree
    // with it.
    final held = requests.fold<double>(
      0,
      (sum, r) => r.escrow.holdsFunds ? sum + r.total : sum,
    );
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final completedThisMonth = [
      for (final r in requests)
        if (r.escrow == EscrowState.releasedToWorkshop &&
            !r.inCurrentStateSince.isBefore(monthStart))
          r,
    ];
    final completedValue = completedThisMonth.fold<double>(
      0,
      (sum, r) => sum + r.total,
    );
    final waiting = disputes.length + needsFunds.length + pending.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        AdminSummaryCard(
          icon: LucideIcons.sunrise,
          title: s.t('اليوم', 'Today'),
          subtitle: waiting == 0
              ? s.t('لا شيء ينتظر قرارك.', 'Nothing is waiting on you.')
              : s.t(
                  '$waiting بنداً ينتظر قرارك.',
                  '$waiting items are waiting on you.',
                ),
          // Money first, because it is the figure the founder is accountable
          // for; then the two counts that say whether the day is calm.
          stats: [
            AdminStat(
              value: RialAmount(held),
              label: s.t('محجوز في الضمان', 'Held in escrow'),
            ),
            AdminStat.count(
              running.length,
              label: s.t('طلبات جارية', 'In flight'),
            ),
            AdminStat.count(
              disputes.length,
              label: s.t('نزاعات مفتوحة', 'Open disputes'),
              color: disputes.isEmpty ? null : ak.danger,
            ),
          ],
          chips: [
            AdminMetaChip(
              icon: LucideIcons.circleCheckBig,
              tone: AdminChipTone.good,
              // Whole rials, matching what this figure has always shown: a
              // month's takings are a scale, not an amount anyone reconciles,
              // and fils here would also put a second two-decimal number on a
              // screen whose one exact figure is the escrow total above.
              child: RialAmount(
                completedValue,
                decimals: 0,
                prefix:
                    '${s.t('اكتمل هذا الشهر', 'Completed this month')} · '
                    '${completedThisMonth.length} · ',
              ),
            ),
          ],
          footnote: s.t(
            'المحجوز يشمل الطلبات المتنازع عليها — النزاع يجمّد المبلغ ولا '
                'يعيده.',
            'Held includes disputed jobs — a dispute freezes the money, it '
                'does not return it.',
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // Disputes lead: both sides of the transaction are blocked, and this is
        // the queue measured against `QueueSla.founder`'s four hours.
        AdminRequestSection(
          icon: LucideIcons.handshake,
          tone: disputes.isEmpty ? AdminChipTone.normal : AdminChipTone.warn,
          title: s.t('نزاعات', 'Disputes'),
          emptyIcon: LucideIcons.handshake,
          empty: s.t(
            'لا نزاعات مفتوحة — الطرفان راضيان حتى الآن.',
            'No open disputes — both sides are happy so far.',
          ),
          requests: disputes,
          showDisputeNote: true,
          waitingOnFounder: true,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        AdminRequestSection(
          icon: LucideIcons.banknote,
          tone: needsFunds.isEmpty ? AdminChipTone.normal : AdminChipTone.warn,
          title: s.t('بانتظار تأكيد استلام المبلغ', 'Awaiting funds'),
          emptyIcon: LucideIcons.banknote,
          empty: s.t(
            'لا تحويلات بانتظارك — كل حجز مدفوع مؤكَّد.',
            'No transfers waiting on you — every paid booking is confirmed.',
          ),
          requests: needsFunds,
          waitingOnFounder: true,
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // Applications land here as a *pointer*, not a second queue: the
        // pipeline in the Workshops tab is the one place they are actioned
        // (§11 step 2), and duplicating the buttons would mean two places to
        // keep the mandatory-reason rule in.
        AdminGroupHeader(
          icon: LucideIcons.store,
          title: s.t('طلبات تسجيل ورش', 'Workshop applications'),
          count: pending.length,
          tone: pending.isEmpty ? AdminChipTone.normal : AdminChipTone.warn,
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (pending.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.store,
            message: s.t(
              'لا طلبات تسجيل بانتظار مراجعتك.',
              'No applications waiting on your review.',
            ),
          )
        else
          for (final (i, provider) in pending.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _ApplicationPointer(provider: provider),
          ],
        const SizedBox(height: AppSpacing.sectionGap),

        AdminRequestSection(
          icon: LucideIcons.timer,
          title: s.t('انتهت مهلة موافقة العميل', "Customer's window lapsed"),
          emptyIcon: LucideIcons.timer,
          empty: s.t(
            'لا مهلة منتهية — لا تحرير تلقائي وشيك.',
            'No lapsed windows — no automatic release is imminent.',
          ),
          requests: lapsing,
          readOnly: true,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        AdminRequestSection(
          icon: LucideIcons.wrench,
          title: s.t('طلبات جارية', 'In flight'),
          emptyIcon: LucideIcons.wrench,
          empty: s.t('لا طلبات جارية الآن.', 'Nothing in flight right now.'),
          requests: running,
          readOnly: true,
        ),
      ],
    );
  }
}

/// A pointer to an application, on the Today tab.
///
/// Deliberately has no approve/reject buttons: that decision needs the whole
/// submission in front of it, which is what the Workshops tab shows. This row
/// says *someone is waiting, and for how long*, and sends you there.
class _ApplicationPointer extends StatelessWidget {
  const _ApplicationPointer({required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final level = applicationUrgency(provider);

    return UrgencyCard(
      level: level,
      onTap: () => context.push('/admin/workshops/${provider.id}'),
      child: Row(
        children: [
          IconTile(LucideIcons.store, size: 38, radius: 13),
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
                  '${provider.stage.label(s)} · ${provider.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          UrgencyLabel(applicationWaitedLabel(s, provider), level: level),
          Icon(LucideIcons.chevronLeft, size: 16, color: ak.inkFaint),
        ],
      ),
    );
  }
}

/// How long an application has been waiting, on the same three-level scale the
/// booking queues use.
///
/// A day rather than [QueueSla.founder]'s four hours: reading a commercial
/// registration is not the same job as unblocking a stuck transaction, and
/// colouring every application red by lunchtime would train the founder to
/// ignore the colour — which is the failure mode `status_indicator.dart` exists
/// to avoid.
UrgencyLevel applicationUrgency(ServiceProvider provider, {DateTime? now}) {
  final since = provider.stageSince;
  if (since == null) return UrgencyLevel.normal;
  final waited = (now ?? DateTime.now()).difference(since);
  const window = Duration(hours: 24);
  if (waited >= window) return UrgencyLevel.overdue;
  if (waited >= window * (2 / 3)) return UrgencyLevel.upcoming;
  return UrgencyLevel.normal;
}

String applicationWaitedLabel(S s, ServiceProvider provider, {DateTime? now}) {
  final since = provider.stageSince;
  if (since == null) return s.t('غير معروف', 'Unknown');
  final waited = (now ?? DateTime.now()).difference(since);
  if (waited.inHours < 1) {
    return s.t('منذ ${waited.inMinutes} دقيقة', '${waited.inMinutes}m waiting');
  }
  if (waited.inHours < 24) {
    return s.t('منذ ${waited.inHours} ساعة', '${waited.inHours}h waiting');
  }
  return s.t(
    'منذ ${s.days(waited.inDays)}',
    '${s.days(waited.inDays)} waiting',
  );
}

/// One queue of bookings on the founder's panel.
///
/// Every section gets the same three parts in the same order — a header with
/// its icon and count, then either its cards or its empty state — so the eye
/// can tell where one queue ends and the next begins without reading either
/// title.
class AdminRequestSection extends ConsumerWidget {
  const AdminRequestSection({
    super.key,
    required this.icon,
    required this.title,
    required this.empty,
    required this.emptyIcon,
    required this.requests,
    this.tone = AdminChipTone.normal,
    this.showDisputeNote = false,
    this.readOnly = false,
    this.waitingOnFounder = false,
  });

  final IconData icon;
  final String title;
  final String empty;
  final IconData emptyIcon;
  final List<ServiceRequest> requests;
  final AdminChipTone tone;
  final bool showDisputeNote;

  /// Rows the founder watches but does not drive — the workshop and the
  /// customer own those transitions.
  final bool readOnly;

  /// Whether a delay in this queue is the founder's to answer for. Only these
  /// rows can go amber or red — see [QueueSla].
  final bool waitingOnFounder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final window = ref.watch(appConfigProvider).approvalWindow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminGroupHeader(
          icon: icon,
          title: title,
          count: requests.length,
          tone: tone,
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (requests.isEmpty)
          EmptyState(compact: true, icon: emptyIcon, message: empty)
        else
          for (final (i, r) in requests.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _RequestCard(
              request: r,
              window: window,
              level: QueueSla.levelFor(
                r,
                window: QueueSla.founder,
                waitingOnMe: waitingOnFounder,
              ),
              showDisputeNote: showDisputeNote,
              readOnly: readOnly,
              s: s,
            ),
          ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.window,
    required this.level,
    required this.showDisputeNote,
    required this.readOnly,
    required this.s,
  });

  final ServiceRequest request;
  final Duration window;
  final UrgencyLevel level;
  final bool showDisputeNote;
  final bool readOnly;
  final S s;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final deadline = request.approvalDeadline(window);
    final hours = deadline?.difference(DateTime.now()).inHours;

    return UrgencyCard(
      level: level,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/track/${request.id}'),
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
            child: OperatorRequestHeader(request: request),
          ),
          const AdminInsetDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: EscrowTimeline(
                        state: request.escrow,
                        size: EscrowTimelineSize.compact,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    UrgencyLabel(
                      QueueSla.waitedLabel(s, request),
                      level: level,
                    ),
                  ],
                ),
                if (request.escrow == EscrowState.awaitingApproval &&
                    hours != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AdminMetaChip(
                    icon: LucideIcons.timer,
                    tone: hours <= 0
                        ? AdminChipTone.warn
                        : AdminChipTone.normal,
                    label: hours <= 0
                        ? s.t(
                            'انتهت مهلة العميل — تحرير تلقائي',
                            "Customer's window closed — auto-releasing",
                          )
                        : s.t(
                            'يتبقى للعميل $hours ساعة قبل التحرير التلقائي',
                            '$hours h before the automatic release',
                          ),
                  ),
                ],
                if (showDisputeNote && request.disputeNote.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: ak.amberBgSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ak.amberBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.messageCircle,
                          size: 14,
                          color: ak.amberText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          // The customer's own words, unedited — a summarised
                          // complaint is a mis-stated complaint.
                          child: Text(
                            request.disputeNote,
                            style: context.text.bodySecondary.copyWith(
                              height: 1.5,
                              color: ak.amberText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!readOnly) ...[
            const AdminInsetDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                AppSpacing.md,
                AppSpacing.cardPadding,
                AppSpacing.cardPadding,
              ),
              child: EscrowActionBar(
                request: request,
                actor: EscrowActor.founder,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
