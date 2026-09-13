import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/provider_dashboard_state.dart';
import '../operations/escrow_action_bar.dart';
import '../operations/queue_urgency.dart';
import '../operations/quote_sheet.dart';
import '../services/proof_upload_sheet.dart';

/// The job queue for a real, ownership-verified workshop account — richer
/// than the old `/workshop` panel's Jobs tab: status/date/text filters and an
/// assign-to-technician action, still driven entirely by the shared escrow
/// transition table (`ServiceRequest.escrow.transitionsFor`), never a
/// parallel status field.
///
/// **Escrow transitions here fire through `ServiceMarketplaceRepository`
/// directly**, not `EscrowActionBar`/`operatorQueueProvider` — that pair's
/// list comes from `GET /operator/requests`, which is founder-only on the
/// real backend, so a real (non-founder) workshop owner's refresh would 403
/// before any button here could even find its booking. `POST
/// .../requests/{id}/status` itself has no such restriction: it authorises
/// the workshop actor from `ProviderId` ownership, same as every
/// `/my-workshop/*` route. Quote submission on a part-install request opens
/// the same `QuoteSheet` (`../operations/quote_sheet.dart`) the `/workshop`
/// panel uses, then posts through the same repository call.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  EscrowState? _status;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final requests = ref.watch(workshopRequestsProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('الطلبات', 'Orders'))),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(workshopRequestsProvider.notifier).refresh(),
          // Slivers rather than one `ListView(children:)`: the job list is
          // server-driven and unbounded, and the plain form builds every card
          // in it whether or not it is on screen. The filter row stays a box
          // adapter above the sliver list, so it still scrolls with the cards.
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.screenMargin,
                  AppSpacing.screenMargin,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatusFilterRow(
                        selected: _status,
                        onSelected: (status) {
                          setState(() => _status = status);
                          ref
                              .read(workshopRequestsProvider.notifier)
                              .applyFilter(
                                WorkshopRequestsFilter(status: status),
                              );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  0,
                  AppSpacing.screenMargin,
                  AppSpacing.screenMargin,
                ),
                sliver: requests.when(
                  loading: () =>
                      const SliverToBoxAdapter(child: ListSkeleton()),
                  error: (error, _) => SliverToBoxAdapter(
                    child: EmptyState(
                      icon: LucideIcons.circleAlert,
                      message: s.t(
                        'تعذّر تحميل الطلبات.',
                        'Couldn\'t load orders.',
                      ),
                      action: FilledButton(
                        onPressed: () => ref
                            .read(workshopRequestsProvider.notifier)
                            .refresh(),
                        child: Text(s.t('إعادة المحاولة', 'Retry')),
                      ),
                    ),
                  ),
                  data: (list) => list.isEmpty
                      ? SliverToBoxAdapter(
                          child: EmptyState(
                            icon: LucideIcons.clipboardCheck,
                            title: s.t('لا طلبات', 'No jobs here'),
                            message: s.t(
                              'لا يوجد ما يطابق هذا التصفية الآن.',
                              'Nothing matches this filter right now.',
                            ),
                          ),
                        )
                      : SliverList.builder(
                          itemCount: list.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _OrderCard(request: list[index]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.selected, required this.onSelected});

  final EscrowState? selected;
  final void Function(EscrowState?) onSelected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const shown = [
      EscrowState.fundsHeld,
      EscrowState.acceptedByWorkshop,
      EscrowState.inProgress,
      EscrowState.awaitingApproval,
      EscrowState.disputed,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(s.t('الكل', 'All')),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final state in shown)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(state.label(s)),
                selected: selected == state,
                onSelected: (_) => onSelected(state),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final waitingOnMe = request.escrow
        .transitionsFor(EscrowActor.workshop)
        .isNotEmpty;
    final level = QueueSla.levelFor(
      request,
      window: QueueSla.workshop,
      waitingOnMe: waitingOnMe,
    );

    return UrgencyCard(
      level: level,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OperatorRequestHeader(request: request),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              UrgencyLabel(QueueSla.waitedLabel(s, request), level: level),
              const Spacer(),
              _AssignButton(request: request),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _OrderActions(request: request),
        ],
      ),
    );
  }
}

class _AssignButton extends ConsumerWidget {
  const _AssignButton({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final staff = ref.watch(workshopStaffProvider).valueOrNull ?? const [];
    final active = [
      for (final m in staff)
        if (m.isActive) m,
    ];
    final assigned = active
        .where((m) => m.id == request.assignedStaffId)
        .firstOrNull;

    return PopupMenuButton<String>(
      tooltip: s.t('تعيين فني', 'Assign a technician'),
      onSelected: (staffId) => ref
          .read(workshopRequestsProvider.notifier)
          .assign(request.id, staffId: staffId),
      itemBuilder: (context) => [
        for (final member in active)
          PopupMenuItem(value: member.id, child: Text(member.name)),
      ],
      child: Chip(
        avatar: const Icon(LucideIcons.userCog, size: 14),
        label: Text(assigned?.name ?? s.t('غير معيّن', 'Unassigned')),
      ),
    );
  }
}

class _OrderActions extends ConsumerWidget {
  const _OrderActions({required this.request});

  final ServiceRequest request;

  Future<void> _fire(
    BuildContext context,
    WidgetRef ref,
    EscrowTransition transition,
  ) async {
    final s = S.of(context);
    if (transition.event.isDestructive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(s.t('تأكيد الإجراء', 'Confirm this action')),
          content: Text(
            s.t(
              'سيتحول الحجز إلى "${transition.to.label(s)}" — لا يمكن التراجع.',
              'The booking becomes "${transition.to.label(s)}". This cannot be undone.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AkColors.of(dialogContext).danger,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.t('تأكيد', 'Confirm')),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    if (transition.event == EscrowEvent.submitQuote) {
      final quote = await showModalBottomSheet<Quote>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => QuoteSheet(s: s, request: request),
      );
      if (quote == null || !context.mounted) return;
      // Same repository call `workshop_screen.dart` makes — not routed
      // through `operatorQueueProvider`, for the same reason every other
      // transition here isn't (see this file's class doc comment).
      await ref.read(serviceMarketplaceRepositoryProvider).submitQuote(request.id, quote);
    } else if (transition.event == EscrowEvent.submitProof) {
      final result = await showModalBottomSheet<ProofDraft>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => ProofUploadSheet(s: s, request: request),
      );
      if (result == null || !context.mounted) return;
      await ref
          .read(serviceMarketplaceRepositoryProvider)
          .applyEscrowEvent(
            request.id,
            EscrowEvent.submitProof,
            actor: EscrowActor.workshop,
            proof: ProofOfWork(
              id: 'proof-${request.id}',
              requestId: request.id,
              notes: result.notes.trim(),
              submittedAt: DateTime.now(),
              media: result.media,
              includesPartBoxPhoto: result.includesPartBoxPhoto,
            ),
          );
    } else {
      await ref
          .read(serviceMarketplaceRepositoryProvider)
          .applyEscrowEvent(
            request.id,
            transition.event,
            actor: EscrowActor.workshop,
          );
    }
    if (context.mounted) {
      await ref.read(workshopRequestsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final available = request.escrow.transitionsFor(EscrowActor.workshop);
    if (available.isEmpty) {
      return Text(
        s.t('لا إجراء مطلوب منك الآن', 'Nothing for you to do at this state.'),
        style: TextStyle(fontSize: 11.5, color: AkColors.of(context).inkFaint),
      );
    }

    final forward = [
      for (final t in available)
        if (!t.event.isDestructive) t,
    ];
    final destructive = [
      for (final t in available)
        if (t.event.isDestructive) t,
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (forward.isNotEmpty)
          FilledButton(
            onPressed: () => _fire(context, ref, forward.first),
            child: Text(forward.first.event.label.of(s)),
          ),
        for (final t in forward.skip(1))
          OutlinedButton(
            onPressed: () => _fire(context, ref, t),
            child: Text(t.event.label.of(s)),
          ),
        for (final t in destructive)
          TextButton(
            onPressed: () => _fire(context, ref, t),
            style: TextButton.styleFrom(
              foregroundColor: AkColors.of(context).danger,
            ),
            child: Text(t.event.label.of(s)),
          ),
      ],
    );
  }
}
