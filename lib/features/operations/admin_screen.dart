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
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'escrow_action_bar.dart';
import 'queue_urgency.dart';

/// The founder's panel (spec §3, note 2 and §6).
///
/// In the pilot the money moves by hand: you confirm a transfer landed before
/// a job is offered to a workshop, and you settle disputes yourself. The app
/// is the ledger of state — it never claims to have moved anything.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final requests = ref.watch(requestsProvider);

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
    // Every booking whose money is actually being held — which includes the
    // disputed ones. They are listed in their own section rather than under
    // "in flight", but the funds have not moved: the dispute notification
    // tells the customer "the funds stay held", so the founder's total has to
    // agree with it.
    final held = requests.fold<double>(
        0, (sum, r) => r.escrow.holdsFunds ? sum + r.total : sum);

    final ak = AkColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('لوحة المؤسس', 'Founder panel'))),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ------------------------------------------- metrics layer
            // Fixed at the top and deliberately inert: these are the three
            // numbers the founder checks, not three things to press.
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, 0,
                  AppSpacing.screenMargin, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          value: '${s.omr} ${held.toStringAsFixed(2)}',
                          label: s.t('محجوز في الضمان', 'Held in escrow'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MetricTile(
                          value: '${needsFunds.length}',
                          label:
                              s.t('بانتظار تأكيدك', 'Awaiting your confirmation'),
                          tone: needsFunds.isEmpty ? null : ak.amberText,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MetricTile(
                          value: '${disputes.length}',
                          label: s.t('نزاعات مفتوحة', 'Open disputes'),
                          tone: disputes.isEmpty ? null : ak.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    s.t('الأرقام هنا تعكس ما سجّله التطبيق فقط. تحويل المبالغ فعلياً يتم خارجه في هذه المرحلة.',
                        'These figures reflect only what the app recorded. Actual transfers happen outside it at this stage.'),
                    style: context.text.bodySecondary
                        .copyWith(fontSize: 11, height: 1.6),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: ak.divider),
            // -------------------------------------------- queue layer
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                    AppSpacing.lg, AppSpacing.screenMargin, AppSpacing.xl),
                children: [
                  _Section(
                    title: s.t('بانتظار تأكيد استلام المبلغ',
                        'Awaiting funds confirmation'),
                    emptyIcon: LucideIcons.banknote,
                    empty: s.t(
                        'لا تحويلات بانتظارك — كل حجز مدفوع مؤكَّد.',
                        'No transfers waiting on you — every paid booking is confirmed.'),
                    requests: needsFunds,
                    waitingOnFounder: true,
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  _Section(
                    title: s.t('نزاعات', 'Disputes'),
                    emptyIcon: LucideIcons.handshake,
                    empty: s.t('لا نزاعات مفتوحة — الطرفان راضيان حتى الآن.',
                        'No open disputes — both sides are happy so far.'),
                    requests: disputes,
                    showDisputeNote: true,
                    waitingOnFounder: true,
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  _Section(
                    title: s.t('طلبات جارية', 'In flight'),
                    emptyIcon: LucideIcons.wrench,
                    empty: s.t('لا طلبات جارية الآن.',
                        'Nothing in flight right now.'),
                    requests: running,
                    readOnly: true,
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const _OffersSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offer governance (home-page spec §3): offers are approved and stopped from
/// here, not self-served by workshops.
///
/// The panel shows every offer the platform holds, live or not, with the exact
/// rule that is keeping it off the home page. That is the point of the screen:
/// a workshop asks why its discount is not showing, and the answer is one line
/// long and comes from the same validation the home page runs.
///
/// The founder's switch is the *only* control here. There is deliberately no
/// way to edit a price: the reference price belongs to the published
/// catalogue and the discount belongs to the workshop, and an approval screen
/// that could quietly adjust either would hollow out the validation it exists
/// to enforce. There is also no way to feature or boost one — home-page
/// ranking is on merit only (spec §2), so there is nothing to promote with.
class _OffersSection extends ConsumerWidget {
  const _OffersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final audit = ref.watch(offersAuditProvider);
    final live = audit.where((row) => row.rejection == null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('${s.t('العروض', 'Offers')} · ${audit.length}'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          s.t('$live من ${audit.length} عرضاً تظهر الآن في الرئيسية. '
              'العرض لا يظهر إلا إذا استوفى كل الشروط.',
              '$live of ${audit.length} offers are showing on the home page. '
                  'An offer appears only when it meets every condition.'),
          style: context.text.bodySecondary.copyWith(height: 1.6),
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (audit.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.tag,
            message: s.t(
                'لا عروض مقدَّمة بعد — سيظهر هنا أي عرض ترفعه ورشة، بسبب ظهوره أو حجبه.',
                'No offers submitted yet — anything a workshop puts forward lands here, with the reason it is showing or hidden.'),
          )
        else
          for (final (i, row) in audit.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap + 2),
            _OfferRow(offer: row.offer, rejection: row.rejection),
          ],
      ],
    );
  }
}

class _OfferRow extends ConsumerWidget {
  const _OfferRow({required this.offer, required this.rejection});

  final Offer offer;
  final OfferRejection? rejection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final offering = marketplace.offeringById(offer.serviceOfferingId);
    final live = rejection == null;
    // A rejection the founder's switch cannot fix — flipping the switch on an
    // offer whose reference price is wrong changes nothing, and the button
    // says so rather than pretending to work.
    final blockedByOther =
        rejection != null && rejection != OfferRejection.notApprovedByFounder;

    final ak = AkColors.of(context);
    // A blocked offer is a workshop waiting on an answer, so it carries the
    // warning tone; a live one is simply working.
    final level = blockedByOther ? UrgencyLevel.upcoming : UrgencyLevel.normal;

    return UrgencyCard(
      level: level,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offering?.name.of(s).replaceAll('\n', ' ') ??
                      offer.serviceOfferingId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.cardTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              live
                  ? StatusBadge.good(s.t('ظاهر', 'Live'))
                  : StatusBadge(s.t('غير ظاهر', 'Hidden')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(offering?.provider.name.of(s) ?? offer.workshopId,
              style: context.text.bodySecondary),
          const SizedBox(height: AppSpacing.md),
          // §2: the discounted price is what this row is about, so it leads;
          // the price it replaced and the percentage support it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${s.omr} ${offer.discountedPrice.toStringAsFixed(2)}',
                  style: context.text.price),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '${s.omr} ${offer.referencePrice.toStringAsFixed(2)} · ${offer.discountPercent.round()}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySecondary
                      .copyWith(decoration: TextDecoration.lineThrough),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            s.t('من ${_date(offer.startsAt)} إلى ${_date(offer.endsAt)}',
                '${_date(offer.startsAt)} → ${_date(offer.endsAt)}'),
            style: context.text.bodySecondary,
          ),
          if (rejection != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.isAr ? rejection!.reason.$1 : rejection!.reason.$2,
              style: context.text.bodySecondary
                  .copyWith(height: 1.5, color: ak.inkSub),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              InkPill(
                label: offer.activeByFounder
                    ? s.t('أوقف العرض', 'Stop offer')
                    : s.t('فعّل العرض', 'Enable offer'),
                outlined: offer.activeByFounder,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg + 2, vertical: AppSpacing.sm + 2),
                onTap: () => ref.read(offersAdminProvider).setActive(
                      offer.id,
                      active: !offer.activeByFounder,
                    ),
              ),
              if (blockedByOther) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    s.t('التفعيل وحده لن يُظهره — السبب أعلاه.',
                        'Enabling alone will not show it — see the reason above.'),
                    style: context.text.bodySecondary
                        .copyWith(fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// One queue of the founder's panel.
///
/// Every section gets the same three parts in the same order — heading with
/// its count, then either its cards or its empty state — so the eye can tell
/// where one queue ends and the next begins without reading either title.
class _Section extends ConsumerWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.emptyIcon,
    required this.requests,
    this.showDisputeNote = false,
    this.readOnly = false,
    this.waitingOnFounder = false,
  });

  final String title;
  final String empty;
  final IconData emptyIcon;
  final List<ServiceRequest> requests;
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
    final ak = AkColors.of(context);
    final window = ref.watch(appConfigProvider).approvalWindow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('$title · ${requests.length}'),
        const SizedBox(height: AppSpacing.headingGap),
        if (requests.isEmpty)
          EmptyState(compact: true, icon: emptyIcon, message: empty)
        else
          for (final (i, r) in requests.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap + 2),
            Builder(builder: (context) {
              final level = QueueSla.levelFor(r,
                  window: QueueSla.founder, waitingOnMe: waitingOnFounder);
              return UrgencyCard(
                level: level,
                onTap: () => context.push('/track/${r.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OperatorRequestHeader(request: r),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: EscrowTimeline(
                              state: r.escrow,
                              size: EscrowTimelineSize.compact),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        UrgencyLabel(QueueSla.waitedLabel(s, r), level: level),
                      ],
                    ),
                    if (showDisputeNote && r.disputeNote.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        // The customer's own words, unedited — a summarised
                        // complaint is a mis-stated complaint.
                        '"${r.disputeNote}"',
                        style: context.text.bodyPrimary
                            .copyWith(height: 1.6, color: ak.inkSub),
                      ),
                    ],
                    if (r.escrow == EscrowState.awaitingApproval)
                      _deadlineLine(context, s, r, window),
                    if (!readOnly) ...[
                      const SizedBox(height: AppSpacing.lg),
                      EscrowActionBar(request: r, actor: EscrowActor.founder),
                    ],
                  ],
                ),
              );
            }),
          ],
      ],
    );
  }

  Widget _deadlineLine(
      BuildContext context, S s, ServiceRequest request, Duration window) {
    final deadline = request.approvalDeadline(window);
    if (deadline == null) return const SizedBox.shrink();
    final hours = deadline.difference(DateTime.now()).inHours;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        hours <= 0
            ? s.t('انتهت مهلة العميل — تحرير تلقائي.',
                "Customer's window has closed — auto-releasing.")
            : s.t('يتبقى للعميل $hours ساعة قبل التحرير التلقائي.',
                'Customer has $hours hours before the automatic release.'),
        style: context.text.bodySecondary,
      ),
    );
  }
}
