import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconTile(Icons.build_outlined,
                        size: 64,
                        radius: 22,
                        background: AppColors.field,
                        foreground: AppColors.ink3),
                    const SizedBox(height: 12),
                    Text(s.t('لا توجد حجوزات بعد', 'No bookings yet'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      child: FilledButton(
                        onPressed: () => context.go('/services'),
                        child: Text(s.bookService),
                      ),
                    ),
                    if (AppFlags.requestPartInstall) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 200,
                        child: OutlinedButton(
                          onPressed: () => context.push('/request-part'),
                          child: Text(s.t('اطلب قطعة + تركيب',
                              'Request a part + fitting')),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  // Reviews are invitations, not obligations — they sit above
                  // the list because a completed job is the one thing here the
                  // customer can still add to, and they disappear the moment
                  // it is written (spec §8).
                  if (AppFlags.verifiedReviews)
                    for (final r in ref.watch(pendingCustomerReviewsProvider)) ...[
                      _ReviewPrompt(request: r),
                      const SizedBox(height: 12),
                    ],
                  if (active.isNotEmpty) ...[
                    SectionHeader(s.t('جارية', 'Active')),
                    const SizedBox(height: 10),
                    for (final (i, r) in active.indexed) ...[
                      Entrance(delayMs: 40 * i, child: _RequestCard(request: r)),
                      const SizedBox(height: 12),
                    ],
                  ],
                  if (done.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SectionHeader(s.t('منتهية', 'Finished')),
                    const SizedBox(height: 10),
                    for (final r in done) ...[
                      _RequestCard(request: r),
                      const SizedBox(height: 12),
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
          IconTile(Icons.star_outline_rounded,
              background: ak.amberSoft, foreground: ak.amberText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('كيف كانت تجربتك مع ${request.offering.provider.name.of(s)}؟',
                      'How was ${request.offering.provider.name.of(s)}?'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  s.t('تقييمك يظهر موثّقاً لأنه عن الطلب #${request.id} المكتمل.',
                      'Your review shows as verified because it is about completed booking #${request.id}.'),
                  style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: ak.inkFaint),
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
    final escrow = request.escrow;

    final badge = switch (escrow) {
      EscrowState.requested =>
        StatusBadge(s.t('بانتظار السعر', 'Awaiting quote')),
      EscrowState.quoted =>
        StatusBadge.warn(s.t('عرض بانتظارك', 'Quote for you')),
      EscrowState.releasedToWorkshop =>
        StatusBadge.good(s.t('مكتمل', 'Completed')),
      EscrowState.disputed => StatusBadge.bad(s.t('نزاع', 'Disputed')),
      EscrowState.refunded => StatusBadge.bad(s.t('مُعاد', 'Refunded')),
      EscrowState.cancelled => StatusBadge(s.t('ملغي', 'Cancelled')),
      EscrowState.awaitingApproval =>
        StatusBadge.warn(s.t('بحاجة لمراجعتك', 'Review needed')),
      _ => StatusBadge(escrow.label(s)),
    };

    final settled =
        escrow == EscrowState.releasedToWorkshop || escrow.isTerminal;

    return AppCard(
      // The two states with something for the customer to *decide* jump
      // straight to the decision; everything else opens the tracking view.
      onTap: () => context.push(switch (escrow) {
        EscrowState.awaitingApproval => '/approve/${request.id}',
        EscrowState.quoted => '/quote/${request.id}',
        _ => '/track/${request.id}',
      }),
      child: Row(
        children: [
          IconTile(
            settled
                ? Icons.check_circle_outline_rounded
                : Icons.build_rounded,
            background: settled ? AppColors.goodSoft : AppColors.brandSoft,
            foreground: settled ? AppColors.good : AppColors.brand,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${request.id} · ${request.offering.name.of(s)}',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  // A booking still waiting on a price has no slot and no
                  // amount. Printing "· · OMR 0.00" for it would state two
                  // things that are not true yet.
                  [
                    request.offering.provider.name.of(s),
                    if (request.slot.isNotEmpty) request.slot,
                    if (request.inQuotePhase)
                      s.t('لم يُسعَّر بعد', 'not priced yet')
                    else
                      '${s.omr} ${request.total.toStringAsFixed(2)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.ink3),
                ),
              ],
            ),
          ),
          badge,
        ],
      ),
    );
  }
}
