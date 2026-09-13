import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/guid.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/escrow_timeline.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// Which slice of the list is on screen.
///
/// [_Filter.needsYou] is the reason this filter exists at all. Everything else
/// here is a convenience; that one is the answer to the only question a
/// customer opens this tab with any urgency to ask — *is anything waiting on
/// me?* Without it, a quote that expires in two days sits in the same
/// undifferentiated "active" run as a job that will not need the customer for
/// another week.
enum _Filter { all, needsYou, active, done }

/// The states that are **blocked on the customer**, and only those.
///
/// Deliberately not "anything not finished": a booking the workshop is
/// currently working on is not waiting for anybody, and folding it in here
/// would make the count that drives the chip meaningless. The three below are
/// each a decision the customer has to make before the booking can move —
/// accept a price, approve the work, or answer a dispute.
bool _needsCustomer(EscrowState e) =>
    e == EscrowState.quoted ||
    e == EscrowState.awaitingApproval ||
    e == EscrowState.disputed;

/// "حجوزاتي" — the second tab, and the customer's entry point into the escrow
/// machine. What is waiting on the customer first, then everything else.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  _Filter _filter = _Filter.all;

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

    // Sorted, not merely partitioned: inside "active", the bookings the
    // customer has to act on are lifted to the top. The list is short enough
    // that a section header for them would cost more space than it saves, and
    // the colored urgency cards already make them findable once they are up
    // there.
    final active =
        [
          for (final r in requests)
            if (!r.escrow.isTerminal) r,
        ]..sort(
          (a, b) =>
              (_needsCustomer(b.escrow) ? 1 : 0) -
              (_needsCustomer(a.escrow) ? 1 : 0),
        );
    final done = [
      for (final r in requests)
        if (r.escrow.isTerminal) r,
    ];
    final needsYou = [
      for (final r in active)
        if (_needsCustomer(r.escrow)) r,
    ];

    return Scaffold(
      backgroundColor: AkColors.of(context).bg,
      body: SafeArea(
        child: SandRefresh(
          onRefresh: () =>
              ref.read(sessionRefreshProvider).refreshVisibleData(),
          child: requests.isEmpty
              ? _EmptyBookings(s: s)
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    AppSpacing.md,
                    AppSpacing.screenMargin,
                    AppSpacing.xl,
                  ),
                  children: [
                    SandTabHeader(
                      s.navBookings,
                      subtitle: needsYou.isEmpty
                          ? s.t(
                              'كل حجوزاتك، ومسار المبلغ في كل واحد منها',
                              'Every booking, and where its money stands',
                            )
                          : s.t(
                              '${needsYou.length} بانتظار قرارك',
                              '${needsYou.length} waiting on you',
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // The filter row is only worth its space once there is
                    // something to filter — with two bookings it is four chips
                    // explaining a list the user can already see all of.
                    if (requests.length > 2) ...[
                      _FilterBar(
                        filter: _filter,
                        counts: {
                          _Filter.all: requests.length,
                          _Filter.needsYou: needsYou.length,
                          _Filter.active: active.length,
                          _Filter.done: done.length,
                        },
                        onChanged: (f) => setState(() => _filter = f),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    // Reviews are invitations, not obligations — they sit above
                    // the list because a completed job is the one thing here
                    // the customer can still add to, and they disappear the
                    // moment it is written (spec §8). Hidden while a filter is
                    // on, so a filtered list holds only what the filter names.
                    if (AppFlags.verifiedReviews && _filter == _Filter.all)
                      for (final r in ref.watch(
                        pendingCustomerReviewsProvider,
                      )) ...[
                        _ReviewPrompt(request: r),
                        const SizedBox(height: AppSpacing.itemGap + 2),
                      ],
                    ..._body(
                      s: s,
                      active: active,
                      done: done,
                      needsYou: needsYou,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// The list under the filter bar. "All" keeps the two-section shape, because
  /// with nothing filtered out the boundary between a live booking and a
  /// finished one is the most useful line to draw; every other filter has
  /// already drawn its own line and so renders flat.
  List<Widget> _body({
    required S s,
    required List<ServiceRequest> active,
    required List<ServiceRequest> done,
    required List<ServiceRequest> needsYou,
  }) {
    List<Widget> list(List<ServiceRequest> items, {bool animate = true}) => [
      for (final (i, r) in items.indexed) ...[
        if (i > 0) const SizedBox(height: AppSpacing.itemGap + 2),
        if (animate)
          Entrance(
            delayMs: 40 * i,
            child: _RequestCard(request: r),
          )
        else
          _RequestCard(request: r),
      ],
    ];

    switch (_filter) {
      case _Filter.needsYou:
        return needsYou.isEmpty
            ? [
                _NothingHere(
                  s.t(
                    'لا شيء بانتظار قرارك الآن.',
                    'Nothing is waiting on you right now.',
                  ),
                ),
              ]
            : list(needsYou);
      case _Filter.active:
        return active.isEmpty
            ? [_NothingHere(s.t('لا حجوزات جارية.', 'No active bookings.'))]
            : list(active);
      case _Filter.done:
        return done.isEmpty
            ? [
                _NothingHere(
                  s.t('لا حجوزات منتهية بعد.', 'No finished bookings yet.'),
                ),
              ]
            : list(done, animate: false);
      case _Filter.all:
        return [
          if (active.isNotEmpty) ...[
            SectionHeader('${s.t('جارية', 'Active')} · ${active.length}'),
            const SizedBox(height: AppSpacing.headingGap),
            ...list(active),
          ],
          if (done.isNotEmpty) ...[
            if (active.isNotEmpty)
              const SizedBox(height: AppSpacing.sectionGap),
            SectionHeader('${s.t('منتهية', 'Finished')} · ${done.length}'),
            const SizedBox(height: AppSpacing.headingGap),
            ...list(done, animate: false),
          ],
        ];
    }
  }
}

/// The four chips, each carrying its own count so a filter says what it will
/// leave behind *before* it is tapped.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  final _Filter filter;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String label(_Filter f) => switch (f) {
      _Filter.all => s.t('الكل', 'All'),
      _Filter.needsYou => s.t('بانتظارك', 'Needs you'),
      _Filter.active => s.t('جارية', 'Active'),
      _Filter.done => s.t('منتهية', 'Finished'),
    };

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in _Filter.values)
            // A chip for a slice that is empty would be a control whose only
            // effect is to empty the screen — except "All", which is how the
            // user gets back from one of the others.
            if (f == _Filter.all || (counts[f] ?? 0) > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                child: SelectChip(
                  label: '${label(f)} · ${counts[f] ?? 0}',
                  icon: f == _Filter.needsYou ? LucideIcons.bellDot : null,
                  selected: filter == f,
                  onTap: () => onChanged(f),
                ),
              ),
        ],
      ),
    );
  }
}

/// A filter that matched nothing. Quieter than [EmptyState] on purpose: the
/// screen is not empty, one slice of it is, and the way out is the chip the
/// user just tapped.
class _NothingHere extends StatelessWidget {
  const _NothingHere(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodySecondary.copyWith(color: ak.inkFaint),
        ),
      ),
    );
  }
}

/// No bookings at all — a different thing from a filter matching nothing, and
/// the only state on this screen that gets the full call to action.
class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({required this.s});

  final S s;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.md,
        AppSpacing.screenMargin,
        AppSpacing.xl,
      ),
      children: [
        SandTabHeader(s.navBookings),
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        EmptyState(
          icon: LucideIcons.calendarCheck,
          title: s.t('لا حجوزات بعد', 'No bookings yet'),
          message: s.t(
            'أول حجز لك يظهر هنا، وتتابع منه كل خطوة — من حجز المبلغ حتى تحريره بعد رضاك.',
            'Your first booking shows up here, and you follow every step from it — from the money being held to your approval releasing it.',
          ),
          // §8: one prominent action. Requesting a part is the rarer path and
          // reads as the quieter of the two.
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
                  child: Text(
                    s.t('اطلب قطعة + تركيب', 'Request a part + fitting'),
                  ),
                ),
            ],
          ),
        ),
      ],
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
          IconTile(
            LucideIcons.star,
            background: ak.amberSoft,
            foreground: ak.amberText,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'كيف كانت تجربتك مع ${request.offering.provider.name.of(s)}؟',
                    'How was ${request.offering.provider.name.of(s)}?',
                  ),
                  style: context.text.cardTitle,
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  s.t(
                    'تقييمك يظهر موثّقاً لأنه عن الطلب #${shortRef(request.id)} المكتمل.',
                    'Your review shows as verified because it is about completed booking #${shortRef(request.id)}.',
                  ),
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
      EscrowState.quoted ||
      EscrowState.awaitingApproval => UrgencyLevel.upcoming,
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
                      '#${shortRef(request.id)} · ${request.offering.name.of(s)}',
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
                  state: escrow,
                  size: EscrowTimelineSize.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // §2: the amount at price weight — it is what the customer is
              // tracking. An unpriced booking says so in words instead of
              // printing "OMR 0.00", which would be a number nobody named.
              if (request.inQuotePhase)
                Text(
                  s.t('لم يُسعَّر بعد', 'Not priced yet'),
                  style: context.text.bodySecondary,
                )
              else
                RialAmount(request.total, style: context.text.price),
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
