import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// All service requests — active and history.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Service requests')),
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
                    const Text('No service requests yet',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      child: FilledButton(
                        onPressed: () => context.go('/services'),
                        child: const Text('Book a service'),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final r = requests[i];
                  final badge = switch (r.status) {
                    RequestStatus.completed =>
                      const StatusBadge.good('Completed'),
                    RequestStatus.disputed =>
                      const StatusBadge.bad('Disputed'),
                    RequestStatus.proofSubmitted =>
                      const StatusBadge.warn('Review needed'),
                    _ => StatusBadge(r.status.label),
                  };
                  return Entrance(
                    delayMs: 40 * i,
                    child: AppCard(
                      onTap: () => context.push(
                        r.status == RequestStatus.proofSubmitted
                            ? '/approve/${r.id}'
                            : '/track/${r.id}',
                      ),
                      child: Row(
                        children: [
                          IconTile(
                            r.status == RequestStatus.completed
                                ? Icons.check_circle_outline_rounded
                                : Icons.build_rounded,
                            background:
                                r.status == RequestStatus.completed
                                    ? AppColors.goodSoft
                                    : AppColors.brandSoft,
                            foreground:
                                r.status == RequestStatus.completed
                                    ? AppColors.good
                                    : AppColors.brand,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${r.id} · ${r.offering.name}',
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r.offering.provider.name} · ${r.slot} · OMR ${r.total.toStringAsFixed(2)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.ink3),
                                ),
                              ],
                            ),
                          ),
                          badge,
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
