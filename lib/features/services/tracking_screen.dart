import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// The customer's view of the escrow machine.
///
/// Ten machine states collapse to six steps here — the customer does not need
/// to see the automatic hand-off between `proofSubmitted` and
/// `awaitingApproval`, and the three terminal states share one final row that
/// says which of them actually happened.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final request = ref
        .watch(requestsProvider)
        .where((r) => r.id == requestId)
        .firstOrNull;

    if (request == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const _TrackingExit(),
          title: Text(s.t('الطلب', 'Request')),
        ),
        body: Center(
            child: Text(s.t('الطلب غير موجود', 'Request not found'))),
      );
    }

    final config = ref.watch(appConfigProvider);
    final escrow = request.escrow;
    final statusIndex = escrow.customerStepIndex;
    // Which rows may be ticked. A cancelled or rejected booking is on the last
    // row without having passed through the ones above it, so "where the
    // customer is" and "what actually happened" are asked separately.
    final reachedIndex = request.reachedStepIndex;
    final amount = request.total.toStringAsFixed(2);

    final steps = <(String, String)>[
      (
        s.t('أرسلت الطلب', 'You sent the request'),
        // A quote-phase booking has no amount to be waiting on — the quote
        // card above the timeline is where its story actually is.
        switch (escrow) {
          EscrowState.requested =>
            s.t('بانتظار تسعير الورشة', 'Waiting for the workshop to price it'),
          EscrowState.quoted =>
            s.t('وصل السعر — القرار لك', 'The price is in — your decision'),
          EscrowState.quoteAccepted => s.t('قبلت العرض', 'You accepted'),
          _ => s.t('$amount ر.ع بانتظار تأكيد الحجز',
              'OMR $amount awaiting confirmation'),
        }
      ),
      (
        s.t('تأكد حجز المبلغ', 'Funds confirmed held'),
        s.t('محفوظ كضمان حتى موافقتك',
            'Held in escrow until you approve')
      ),
      (
        s.t('قبلت الورشة الطلب', 'Workshop accepted'),
        request.offering.provider.name.of(s)
      ),
      (
        s.t('العمل جارٍ', 'Work in progress'),
        request.slot.isEmpty
            ? s.t('الموعد بالاتفاق مع الورشة',
                'Timing agreed with the workshop')
            : s.t('مجدول في ${request.slot}',
                'Scheduled for ${request.slot}')
      ),
      (
        s.t('رُفع إثبات الإنجاز', 'Proof of work submitted'),
        s.t('راجعه ثم وافق أو سجّل ملاحظة',
            'Review it, then approve or raise an issue')
      ),
      _finalStep(s, request),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const _TrackingExit(),
        title: Text(s.t('الطلب #${request.id}', 'Request #${request.id}')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(child: StatusBadge(escrow.label(s))),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        const IconTile(Icons.storefront_rounded,
                            radius: 999),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(request.offering.provider.name.of(s),
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                '${request.offering.name.of(s)} · ${request.car.label} · ${request.plate}',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.ink3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The quote phase's own story, above the shared timeline:
                  // the timeline's first row is "you sent the request" for
                  // both kinds of booking, and the difference between waiting
                  // for a price, having one, and having accepted it is a
                  // difference about *numbers*, which belong here.
                  if (request.type == BookingType.customQuote) ...[
                    const SizedBox(height: 12),
                    _QuoteCard(request: request),
                  ],
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      children: [
                        for (final (i, step) in steps.indexed)
                          _TimelineStep(
                            title: step.$1,
                            subtitle: step.$2,
                            state: i == statusIndex
                                ? _StepState.now
                                : i < statusIndex && i <= reachedIndex
                                    ? _StepState.done
                                    : _StepState.next,
                            isLast: i == steps.length - 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  EscrowBanner(_escrowLine(s, request, amount)),
                  if (escrow == EscrowState.awaitingApproval)
                    _DeadlineNote(request: request, window: config.approvalWindow),
                  if (escrow == EscrowState.createdPendingPayment) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(requestsProvider.notifier)
                          .fire(request.id, EscrowEvent.cancelBooking,
                              actor: EscrowActor.customer),
                      child: Text(s.t('إلغاء الحجز', 'Cancel booking')),
                    ),
                  ],
                  if (config.simulateProviderLifecycle &&
                      escrow.happyPathNext != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.autorenew_rounded,
                            size: 14, color: AppColors.ink3),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.t('نسخة تجريبية — تتقدّم الحالة تلقائياً.',
                                'Demo build — the state advances on its own.'),
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.ink3),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(requestsProvider.notifier)
                              .advance(request.id),
                          child: Text(s.t('تخطَّ للأمام', 'Skip ahead'),
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                  if (escrow == EscrowState.awaitingApproval) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          context.push('/approve/${request.id}'),
                      child: Text(s.t('راجع العمل المنجز',
                          'Review completed work')),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    // Disabled rather than dialling a stand-in number when the
                    // workshop has not given one: a call button that reaches
                    // someone else is worse than no call button.
                    child: OutlinedButton.icon(
                      onPressed: switch (request.offering.provider.phone) {
                        final String phone when phone.isNotEmpty => () =>
                            Contact.call(context, phone),
                        _ => null,
                      },
                      icon: const Icon(Icons.phone_outlined, size: 17),
                      label: Text(s.t('اتصال', 'Call')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink),
                      onPressed: () =>
                          context.push('/chat/${request.id}'),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 17),
                      label: Text(s.t('محادثة', 'Chat')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The last row names the ending the booking actually reached, rather than
  /// leaving "you approve → payment released" showing on a refunded job.
  (String, String) _finalStep(S s, ServiceRequest request) =>
      switch (request.escrow) {
        EscrowState.releasedToWorkshop => (
            s.t('حُرِّر المبلغ للورشة', 'Payment released'),
            s.t('اكتمل الطلب — شكراً لك', 'Booking complete — thank you')
          ),
        EscrowState.disputed => (
            s.t('نزاع قيد المراجعة', 'Dispute under review'),
            s.t('المبلغ ما زال محجوزاً حتى نحسم الأمر',
                'The funds stay held until we resolve it')
          ),
        EscrowState.cancelled => (
            s.t('أُلغي الحجز', 'Booking cancelled'),
            s.t('لم يُحجز أي مبلغ', 'No funds were held')
          ),
        EscrowState.refunded => (
            s.t('أُعيد المبلغ إليك', 'Refunded to you'),
            s.t('${request.total.toStringAsFixed(2)} ر.ع في طريقها إليك',
                'OMR ${request.total.toStringAsFixed(2)} is on its way back')
          ),
        _ => (
            s.t('توافق → يُحرَّر المبلغ', 'You approve → payment released'),
            s.t('أو تسجّل ملاحظة ونتدخّل', 'Or raise an issue and we step in')
          ),
      };

  String _escrowLine(S s, ServiceRequest request, String amount) =>
      switch (request.escrow) {
        // Nothing is held, and no amount exists to name — saying "OMR 0.00 is
        // held in escrow" would be false twice over.
        EscrowState.requested => s.t(
            'لا يُحجز أي مبلغ قبل أن تقبل عرض السعر.',
            'Nothing is held until you accept a quote.'),
        EscrowState.quoted => s.t(
            'وصل عرض السعر. لا يُحجز شيء ما لم تقبله.',
            'The quote has arrived. Nothing is held unless you accept it.'),
        EscrowState.quoteAccepted => s.t(
            'قبلت العرض — الخطوة التالية تأكيد حجز $amount ر.ع.',
            'Quote accepted — next comes confirming OMR $amount into escrow.'),
        EscrowState.createdPendingPayment => s.t(
            'لم يُحجز المبلغ بعد — يبدأ الضمان فور تأكيد $amount ر.ع.',
            'Nothing is held yet — escrow starts the moment OMR $amount is confirmed.'),
        EscrowState.releasedToWorkshop => s.t(
            'تم تحرير $amount ر.ع إلى الورشة.',
            'OMR $amount was released to the workshop.'),
        EscrowState.refunded => s.t('أُعيد $amount ر.ع إليك.',
            'OMR $amount was returned to you.'),
        EscrowState.cancelled =>
          s.t('أُلغي الحجز ولم يُحجز أي مبلغ.',
              'The booking was cancelled and nothing was held.'),
        _ => s.t('$amount ر.ع محفوظة كضمان حتى موافقتك.',
            'OMR $amount held in escrow until your approval.'),
      };
}

/// The quote phase, for a "part + installation" booking (spec §6).
///
/// Three honest states and nothing in between: no price yet, a price to decide
/// on, or a price already agreed. It never estimates, and it never shows a
/// total before the workshop has named one.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final quote = request.quote;
    final decide = request.escrow == EscrowState.quoted;

    return AppCard(
      color: decide ? ak.amberSoft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.t('طلب قطعة + تركيب', 'Part + fitting request'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              StatusBadge(request.escrow.label(s)),
            ],
          ),
          if (request.partRequest != null) ...[
            const SizedBox(height: 6),
            Text(request.partRequest!.description,
                style: TextStyle(
                    fontSize: 12, height: 1.6, color: ak.inkSub)),
          ],
          if (quote == null) ...[
            const SizedBox(height: 8),
            Text(
              s.t('لم تصل تسعيرة بعد. سنُعلمك فور وصولها.',
                  'No price yet. We will tell you the moment it arrives.'),
              style: TextStyle(fontSize: 11.5, color: ak.inkSub),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              s.t('القطعة ${quote.partPrice.toStringAsFixed(2)} + التركيب ${quote.laborPrice.toStringAsFixed(2)} = ${quote.total.toStringAsFixed(2)} ${s.omr}',
                  'Part ${quote.partPrice.toStringAsFixed(2)} + fitting ${quote.laborPrice.toStringAsFixed(2)} = ${s.omr} ${quote.total.toStringAsFixed(2)}'),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800),
            ),
            if (decide) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.push('/quote/${request.id}'),
                child: Text(s.t('راجع العرض وقرّر', 'Review the quote')),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// How long the customer has left before the escrow releases itself.
class _DeadlineNote extends StatelessWidget {
  const _DeadlineNote({required this.request, required this.window});

  final ServiceRequest request;
  final Duration window;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final deadline = request.approvalDeadline(window);
    if (deadline == null) return const SizedBox.shrink();
    final hours = deadline.difference(DateTime.now()).inHours;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        hours <= 0
            ? s.t('انتهت مهلة المراجعة — يُحرَّر المبلغ الآن.',
                'The review window has closed — the payment is releasing now.')
            : s.t('أمامك $hours ساعة للمراجعة، ثم يُحرَّر المبلغ تلقائياً.',
                'You have $hours hours to review, after which the payment releases automatically.'),
        style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
      ),
    );
  }
}

enum _StepState { done, now, next }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.isLast,
  });

  final String title;
  final String subtitle;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (state) {
      _StepState.done => (
          AppColors.goodSoft,
          AppColors.good,
          Icons.check_rounded
        ),
      _StepState.now => (
          AppColors.brand,
          Colors.white,
          Icons.timelapse_rounded
        ),
      _StepState.next => (
          AppColors.field,
          AppColors.ink3,
          Icons.circle_outlined
        ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  boxShadow: state == _StepState.now
                      ? [
                          BoxShadow(
                            color: AppColors.brandSoft,
                            spreadRadius: 4,
                          )
                        ]
                      : null,
                ),
                child: Icon(icon, size: 14, color: fg),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: state == _StepState.done
                        ? AppColors.good
                        : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: state == _StepState.next
                          ? FontWeight.w600
                          : FontWeight.w700,
                      color: switch (state) {
                        _StepState.now => AppColors.brand,
                        _StepState.next => AppColors.ink3,
                        _ => AppColors.ink,
                      },
                    ),
                  ),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.ink3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The way out of the booking details page.
///
/// This screen is entered two different ways and only one of them leaves a
/// stack behind. The bookings list and the founder's panel `push` it, so
/// popping is right. But finishing a booking, sending a part request,
/// accepting a quote and approving a job all `go` here — and `go` *replaces*
/// the stack, deliberately, so that "back" cannot return the user to a form
/// they have already submitted.
///
/// The cost of that was a dead end: `AppBar` only draws a back button when
/// `canPop()` is true, and `/track/:id` lives outside the tab shell, so a
/// customer who had just paid for something landed on a page with no back
/// button, no bottom navigation, and no way out of it at all.
///
/// So the exit is explicit rather than inherited: pop when there is something
/// to pop, otherwise go to the bookings tab — which is where the booking now
/// lives, and the same place the user would otherwise have opened it from.
class _TrackingExit extends StatelessWidget {
  const _TrackingExit();

  @override
  Widget build(BuildContext context) => SandBackButton(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/bookings');
          }
        },
      );
}
