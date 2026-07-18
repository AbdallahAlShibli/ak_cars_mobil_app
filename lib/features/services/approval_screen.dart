import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// Rule 10: provider's photo proof → user approval → payment release.
class ApprovalScreen extends ConsumerWidget {
  const ApprovalScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref
        .watch(requestsProvider)
        .where((r) => r.id == requestId)
        .firstOrNull;

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: Text('Request not found')),
      );
    }

    final completed = request.status == RequestStatus.completed;

    return Scaffold(
      appBar: AppBar(title: const Text('Work completed — review')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            AppCard(
              child: Row(
                children: [
                  const IconTile(
                    Icons.fact_check_outlined,
                    background: AppColors.goodSoft,
                    foreground: AppColors.good,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.offering.provider.name,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                        const Text('Marked done · Tue 10:20 am',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.ink3)),
                      ],
                    ),
                  ),
                  completed
                      ? const StatusBadge.good('Approved')
                      : const StatusBadge.warn('Awaiting you'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader("Provider's proof photos"),
            const SizedBox(height: 9),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 9),
                  Expanded(
                    child: Container(
                      height: 86,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.photo_outlined,
                          size: 26, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const AppCard(
              child: Text(
                '"New oil and genuine filter installed — old filter shown in photo 2. 10-point check passed, tyre pressure adjusted."',
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.ink2, height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total to release',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                  Text(
                    'OMR ${request.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Auto-releases in 48h if no action is taken',
                style: TextStyle(fontSize: 11.5, color: AppColors.ink3),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: completed ? AppColors.ink3 : AppColors.good,
              ),
              onPressed: completed
                  ? null
                  : () {
                      ref
                          .read(requestsProvider.notifier)
                          .setStatus(request.id, RequestStatus.completed);
                      ref.read(notificationsProvider.notifier).push(
                            title: 'Payment released',
                            body:
                                'OMR ${request.total.toStringAsFixed(2)} released to ${request.offering.provider.name} for #${request.id}.',
                            icon: Icons.lock_open_rounded,
                            route: '/payments',
                          );
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Payment released to the provider — thank you')),
                      );
                      context.go('/home');
                    },
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(completed
                  ? 'Payment released'
                  : 'Approve & release payment'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bad,
                side: const BorderSide(color: Color(0xFFF3D2D2), width: 1.5),
              ),
              onPressed: completed
                  ? null
                  : () {
                      ref
                          .read(requestsProvider.notifier)
                          .setStatus(request.id, RequestStatus.disputed);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Dispute opened — our team will review both sides')),
                      );
                      context.go('/home');
                    },
              child: const Text('Report a problem'),
            ),
          ],
        ),
      ),
    );
  }
}
