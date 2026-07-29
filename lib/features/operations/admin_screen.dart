import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'escrow_action_bar.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(s.t('لوحة المؤسس', 'Founder panel'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('محجوز حالياً في الضمان',
                              'Currently held in escrow'),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.ink3),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.omr} ${held.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    s.t('${running.length} طلب جارٍ',
                        '${running.length} active'),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.t('الأرقام هنا تعكس ما سجّله التطبيق فقط. تحويل المبالغ فعلياً يتم خارجه في هذه المرحلة.',
                  'These figures reflect only what the app recorded. Actual transfers happen outside it at this stage.'),
              style: const TextStyle(
                  fontSize: 10.5, color: AppColors.ink3, height: 1.7),
            ),
            const SizedBox(height: 18),
            _Section(
              title: s.t('بانتظار تأكيد استلام المبلغ',
                  'Awaiting funds confirmation'),
              empty: s.t('لا شيء بانتظار التأكيد.', 'Nothing awaiting confirmation.'),
              requests: needsFunds,
            ),
            _Section(
              title: s.t('نزاعات', 'Disputes'),
              empty: s.t('لا نزاعات مفتوحة.', 'No open disputes.'),
              requests: disputes,
              showDisputeNote: true,
            ),
            _Section(
              title: s.t('طلبات جارية', 'In flight'),
              empty: s.t('لا طلبات جارية.', 'Nothing in flight.'),
              requests: running,
              readOnly: true,
            ),
            const _OffersSection(),
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
        SectionHeader(s.t('العروض', 'Offers')),
        const SizedBox(height: 6),
        Text(
          s.t('$live من ${audit.length} عرضاً تظهر الآن في الرئيسية. '
              'العرض لا يظهر إلا إذا استوفى كل الشروط.',
              '$live of ${audit.length} offers are showing on the home page. '
                  'An offer appears only when it meets every condition.'),
          style: const TextStyle(
              fontSize: 10.5, color: AppColors.ink3, height: 1.7),
        ),
        const SizedBox(height: 10),
        if (audit.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              s.t('لا عروض بعد.', 'No offers yet.'),
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
            ),
          )
        else
          for (final row in audit) ...[
            _OfferRow(offer: row.offer, rejection: row.rejection),
            const SizedBox(height: 10),
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

    return AppCard(
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
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              live
                  ? StatusBadge.good(s.t('ظاهر', 'Live'))
                  : StatusBadge(s.t('غير ظاهر', 'Hidden')),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            offering?.provider.name.of(s) ?? offer.workshopId,
            style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
          ),
          const SizedBox(height: 7),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${s.omr} ${offer.discountedPrice.toStringAsFixed(2)}  ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: '${s.omr} ${offer.referencePrice.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppColors.ink3,
                    decoration: TextDecoration.lineThrough),
              ),
              TextSpan(
                text: '  ·  ${offer.discountPercent.round()}%',
                style: const TextStyle(color: AppColors.ink3),
              ),
            ]),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            s.t('من ${_date(offer.startsAt)} إلى ${_date(offer.endsAt)}',
                '${_date(offer.startsAt)} → ${_date(offer.endsAt)}'),
            style: const TextStyle(fontSize: 10.5, color: AppColors.ink3),
          ),
          if (rejection != null) ...[
            const SizedBox(height: 7),
            Text(
              s.isAr ? rejection!.reason.$1 : rejection!.reason.$2,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.ink2, height: 1.5),
            ),
          ],
          const SizedBox(height: 11),
          Row(
            children: [
              InkPill(
                label: offer.activeByFounder
                    ? s.t('أوقف العرض', 'Stop offer')
                    : s.t('فعّل العرض', 'Enable offer'),
                outlined: offer.activeByFounder,
                fontSize: 11,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () => ref.read(offersAdminProvider).setActive(
                      offer.id,
                      active: !offer.activeByFounder,
                    ),
              ),
              if (blockedByOther) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.t('التفعيل وحده لن يُظهره — السبب أعلاه.',
                        'Enabling alone will not show it — see the reason above.'),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.ink3, height: 1.4),
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

class _Section extends ConsumerWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.requests,
    this.showDisputeNote = false,
    this.readOnly = false,
  });

  final String title;
  final String empty;
  final List<ServiceRequest> requests;
  final bool showDisputeNote;

  /// Rows the founder watches but does not drive — the workshop and the
  /// customer own those transitions.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final window = ref.watch(appConfigProvider).approvalWindow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title),
        const SizedBox(height: 10),
        if (requests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(empty,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.ink3)),
          )
        else
          for (final r in requests) ...[
            AppCard(
              onTap: () => context.push('/track/${r.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OperatorRequestHeader(request: r),
                  if (showDisputeNote && r.disputeNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      // The customer's own words, unedited — a summarised
                      // complaint is a mis-stated complaint.
                      '"${r.disputeNote}"',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.ink2, height: 1.6),
                    ),
                  ],
                  if (r.escrow == EscrowState.awaitingApproval)
                    _deadlineLine(s, r, window),
                  if (!readOnly) ...[
                    const SizedBox(height: 12),
                    EscrowActionBar(
                        request: r, actor: EscrowActor.founder),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _deadlineLine(S s, ServiceRequest request, Duration window) {
    final deadline = request.approvalDeadline(window);
    if (deadline == null) return const SizedBox.shrink();
    final hours = deadline.difference(DateTime.now()).inHours;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        hours <= 0
            ? s.t('انتهت مهلة العميل — تحرير تلقائي.',
                "Customer's window has closed — auto-releasing.")
            : s.t('يتبقى للعميل $hours ساعة قبل التحرير التلقائي.',
                'Customer has $hours hours before the automatic release.'),
        style: const TextStyle(fontSize: 10.5, color: AppColors.ink3),
      ),
    );
  }
}
