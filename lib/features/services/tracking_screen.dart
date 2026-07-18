import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// Rule 9/10: live tracking, call/chat, escrow visibility.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref
        .watch(requestsProvider)
        .where((r) => r.id == requestId)
        .firstOrNull;

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request')),
        body: const Center(child: Text('Request not found')),
      );
    }

    final statusIndex = switch (request.status) {
      RequestStatus.requested => 0,
      RequestStatus.accepted => 1,
      RequestStatus.inProgress => 2,
      RequestStatus.proofSubmitted => 3,
      RequestStatus.completed || RequestStatus.disputed => 4,
    };

    final steps = [
      (
        'Requested & paid',
        'OMR ${request.total.toStringAsFixed(2)} held · waiting for provider'
      ),
      ('Accepted by provider', request.offering.provider.name),
      ('Work in progress', 'Scheduled for ${request.slot}'),
      ('Provider uploads photo proof', 'You will get a notification'),
      ('You approve → payment released', 'Or report a problem'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Request #${request.id}'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(child: StatusBadge(request.status.label)),
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
                              Text(request.offering.provider.name,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                '${request.offering.name} · ${request.car.label} · ${request.plate}',
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
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      children: [
                        for (final (i, step) in steps.indexed)
                          _TimelineStep(
                            title: step.$1,
                            subtitle: step.$2,
                            state: i < statusIndex
                                ? _StepState.done
                                : i == statusIndex
                                    ? _StepState.now
                                    : _StepState.next,
                            isLast: i == steps.length - 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  EscrowBanner(
                    'OMR ${request.total.toStringAsFixed(2)} held in escrow until your approval.',
                  ),
                  if (request.status == RequestStatus.requested ||
                      request.status == RequestStatus.accepted ||
                      request.status == RequestStatus.inProgress) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.autorenew_rounded,
                            size: 14, color: AppColors.ink3),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Live — the provider updates this automatically.',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.ink3),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(requestsProvider.notifier)
                              .advance(request.id),
                          child: const Text('Skip ahead',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                  if (request.status == RequestStatus.proofSubmitted) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          context.push('/approve/${request.id}'),
                      child: const Text('Review completed work'),
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
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Contact.call(context, '+96824000000'),
                      icon: const Icon(Icons.phone_outlined, size: 17),
                      label: const Text('Call'),
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
                      label: const Text('Chat'),
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
