import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/escrow_timeline.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// "حجوزاتي" — the second tab, and the customer's entry point into the escrow
/// machine. Active bookings first, finished ones below.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  @override
  void initState() {
    super.initState();
    // A timer set in a previous process does not survive the app closing, so
    // any approval window that lapsed while the app was shut is settled here,
    // on the screen that would otherwise show it as still open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(requestsProvider.notifier).sweepExpiredApprovals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final requests = ref.watch(requestsProvider);
    final active = [
      for (final r in requests)
        if (!r.escrow.isTerminal) r,
    ];
    final done = [
      for (final r in requests)
        if (r.escrow.isTerminal) r,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.navBookings)),
      body: SafeArea(
        child: requests.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: LucideIcons.calendarCheck,
                    title: s.t('لا حجوزات بعد', 'No bookings yet'),
                    message: s.t(
                      'أول حجز لك يظهر هنا، وتتابع منه كل خطوة — من حجز المبلغ حتى تحريره بعد رضاك.',
                      'Your first booking shows up here, and you follow every step from it — from the money being held to your approval releasing it.',
                    ),
                    // §8: one prominent action. Requesting a part is the rarer
                    // path and reads as the quieter of the two.
                    action: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 220,
                          child: FilledButton(
                            onPressed: () => context.go('/services'),
                            child: Text(s.bookService),
                          ),
                        ),
                        if (AppFlags.requestPartInstall)
                          TextButton(
                            onPressed: () => context.push('/request-part'),
                            child: Text(s.t('اطلب قطعة + تركيب',
                                'Request a part + fitting')),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                    AppSpacing.xs, AppSpacing.screenMargin, AppSpacing.xl),
                children: [
                  // Reviews are invitations, not obligations — they sit above
                  // the list because a completed job is the one thing here the
                  // customer can still add to, and they disappear the moment
                  // it is written (spec §8).
                  if (AppFlags.verifiedReviews)
                    for (final r in ref.watch(pendingCustomerReviewsProvider)) ...[
                      _ReviewPrompt(request: r),
                      const SizedBox(height: AppSpacing.itemGap + 2),
                    ],
                  if (active.isNotEmpty) ...[
                    SectionHeader('${s.t('جارية', 'Active')} · ${active.length}'),
                    const SizedBox(height: AppSpacing.headingGap),
                    for (final (i, r) in active.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.itemGap + 2),
                      Entrance(delayMs: 40 * i, child: _RequestCard(request: r)),
                    ],
                  ],
                  if (done.isNotEmpty) ...[
                    if (active.isNotEmpty)
                      const SizedBox(height: AppSpacing.sectionGap),
                    SectionHeader('${s.t('منتهية', 'Finished')} · ${done.length}'),
                    const SizedBox(height: AppSpacing.headingGap),
                    for (final (i, r) in done.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.itemGap + 2),
                      _RequestCard(request: r),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

/// "How was it?" — shown only for a booking that actually completed and paid
/// out, which is the entire verification story behind reviews here (spec §8).
///
/// It is a prompt, not a gate: the money was released before this appeared,
/// and ignoring it costs the customer nothing.
class _ReviewPrompt extends StatelessWidget {
  const _ReviewPrompt({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return AppCard(
      color: ak.surfaceDim,
      onTap: () => context.push('/review/${request.id}'),
      child: Row(
        children: [
          IconTile(LucideIcons.star,
              background: ak.amberSoft, foreground: ak.amberText),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('كيف كانت تجربتك مع ${request.offering.provider.name.of(s)}؟',
                      'How was ${request.offering.provider.name.of(s)}?'),
                  style: context.text.cardTitle,
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  s.t('تقييمك يظهر موثّقاً لأنه عن الطلب #${request.id} المكتمل.',
                      'Your review shows as verified because it is about completed booking #${request.id}.'),
                  style: context.text.bodySecondary,
                ),
              ],
            ),
          ),
          // Lucide icons carry no `matchTextDirection`, so the "go on" chevron
          // is chosen by direction rather than flipped by the framework.
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevronLeft
                : LucideIcons.chevronRight,
            size: 18,
            color: ak.inkFaint,
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final escrow = request.escrow;

    // The three states that are *waiting on the customer* are the only ones
    // that get colour here. A booking merrily in progress does not need to
    // shout at the person who has nothing to do about it.
    final level = switch (escrow) {
      EscrowState.disputed || EscrowState.refunded => UrgencyLevel.overdue,
      EscrowState.quoted || EscrowState.awaitingApproval =>
        UrgencyLevel.upcoming,
      _ => UrgencyLevel.normal,
    };
    final statusLabel = switch (escrow) {
      EscrowState.requested => s.t('بانتظار السعر', 'Awaiting quote'),
      EscrowState.quoted => s.t('عرض بانتظارك', 'Quote for you'),
      EscrowState.releasedToWorkshop => s.t('مكتمل', 'Completed'),
      EscrowState.disputed => s.t('نزاع', 'Disputed'),
      EscrowState.refunded => s.t('مُعاد', 'Refunded'),
      EscrowState.cancelled => s.t('ملغي', 'Cancelled'),
      EscrowState.awaitingApproval => s.t('بحاجة لمراجعتك', 'Review needed'),
      _ => escrow.label(s),
    };
    final settled = escrow.isTerminal;

    return UrgencyCard(
      level: level,
      // The two states with something for the customer to *decide* jump
      // straight to the decision; everything else opens the tracking view.
      onTap: () => context.push(switch (escrow) {
        EscrowState.awaitingApproval => '/approve/${request.id}',
        EscrowState.quoted => '/quote/${request.id}',
        _ => '/track/${request.id}',
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                settled ? LucideIcons.circleCheck : LucideIcons.wrench,
                background: settled ? ak.successSoft : ak.surfaceDim,
                foreground: settled ? ak.success : ak.ink,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${request.id} · ${request.offering.name.of(s)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      // A booking still waiting on a price has no slot. Naming
                      // one would state something that is not true yet.
                      [
                        request.offering.provider.name.of(s),
                        if (request.slot.isNotEmpty) request.slot,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: EscrowTimeline(
                    state: escrow, size: EscrowTimelineSize.compact),
              ),
              const SizedBox(width: AppSpacing.md),
              // §2: the amount at price weight — it is what the customer is
              // tracking. An unpriced booking says so in words instead of
              // printing "OMR 0.00", which would be a number nobody named.
              if (request.inQuotePhase)
                Text(s.t('لم يُسعَّر بعد', 'Not priced yet'),
                    style: context.text.bodySecondary)
              else
                Text('${s.omr} ${request.total.toStringAsFixed(2)}',
                    style: context.text.price),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: UrgencyLabel(statusLabel, level: level),
          ),
        ],
      ),
    );
  }
}
