import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';

/// Renders the escrow transitions [actor] may fire on [request], and nothing
/// else.
///
/// Both operator panels build their buttons from this, which is why neither
/// hard-codes a workflow: add a row to the transition table in `escrow.dart`
/// and the button appears in the right panel, on the right jobs, on its own.
class EscrowActionBar extends ConsumerWidget {
  const EscrowActionBar({
    super.key,
    required this.request,
    required this.actor,
    this.onSubmitProof,
    this.onSubmitQuote,
  });

  final ServiceRequest request;
  final EscrowActor actor;

  /// Fired instead of the plain transition for [EscrowEvent.submitProof],
  /// which needs the workshop's notes and photos before it can move.
  final VoidCallback? onSubmitProof;

  /// Fired instead of the plain transition for [EscrowEvent.submitQuote],
  /// which needs the itemised prices before it can move.
  final VoidCallback? onSubmitQuote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final available = request.escrow.transitionsFor(actor);
    if (available.isEmpty) {
      return Text(
        s.t('لا إجراء مطلوب منك في هذه الحالة.',
            'Nothing for you to do at this state.'),
        style: context.text.bodySecondary,
      );
    }

    // §8, applied to a bar whose buttons the transition table decides: exactly
    // one filled button, and it is the *forward* move. Rejecting a job and
    // accepting it are not equal choices — one of them is what the operator
    // opened the panel to do — and rendering them as two identical buttons
    // was inviting the wrong tap on an action that cannot be undone.
    final forward = [
      for (final t in available)
        if (!t.event.isDestructive) t,
    ];
    final destructive = [
      for (final t in available)
        if (t.event.isDestructive) t,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, t) in forward.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          if (i == 0)
            FilledButton(
              onPressed: () => _fire(context, ref, t),
              child: Text(t.event.label.of(s)),
            )
          else
            OutlinedButton(
              onPressed: () => _fire(context, ref, t),
              child: Text(t.event.label.of(s)),
            ),
        ],
        if (destructive.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
                top: forward.isEmpty ? 0 : AppSpacing.xs),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final t in destructive)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: ak.dangerText),
                    onPressed: () => _fire(context, ref, t),
                    child: Text(t.event.label.of(s)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _fire(
    BuildContext context,
    WidgetRef ref,
    EscrowTransition transition,
  ) async {
    final s = S.of(context);

    // Both of these carry a payload the table knows nothing about — the
    // itemised prices, and the completion evidence — so the panel collects it
    // first and the transition happens on the way back.
    if (transition.event == EscrowEvent.submitProof) {
      onSubmitProof?.call();
      return;
    }
    if (transition.event == EscrowEvent.submitQuote) {
      onSubmitQuote?.call();
      return;
    }

    if (transition.event.isDestructive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(transition.event.label.of(s)),
          content: Text(
            s.t('سيصبح الطلب «${transition.to.label(s)}». لا يمكن التراجع.',
                'The booking becomes "${transition.to.label(s)}". This cannot be undone.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.t('تراجع', 'Back')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.t('تأكيد', 'Confirm')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await ref.read(requestsProvider.notifier).fire(
          request.id,
          transition.event,
          actor: actor,
        );
  }
}

/// Shared summary line for a booking as an operator sees it: who, what car,
/// how much, and where in the machine it sits.
class OperatorRequestHeader extends StatelessWidget {
  const OperatorRequestHeader({super.key, required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '#${request.id} · ${request.offering.name.of(s)}',
                style: context.text.cardTitle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // §2: the amount is the heaviest thing on an operator row. It is
            // what the panel exists to move.
            Text('${s.omr} ${request.total.toStringAsFixed(2)}',
                style: context.text.price),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${request.car.label} · ${request.plate}'
          '${request.slot.isEmpty ? '' : ' · ${request.slot}'}',
          style: context.text.bodySecondary,
        ),
        Text(
          '${request.offering.provider.name.of(s)} · ${request.escrow.label(s)}',
          style: context.text.bodySecondary,
        ),
      ],
    );
  }
}
