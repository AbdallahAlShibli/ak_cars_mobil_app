import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// Payments — escrow wallet view across service requests and shop orders.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestsProvider);
    final orders = ref.watch(ordersProvider);

    // (title, subtitle, amount, state) — state: 0 held, 1 released, 2 disputed
    final held = <(String, String, double, int)>[
      for (final r in requests)
        if (r.status != RequestStatus.completed &&
            r.status != RequestStatus.disputed)
          ('Service #${r.id}', r.offering.name, r.total, 0),
      for (final r in requests)
        if (r.status == RequestStatus.disputed)
          ('Service #${r.id}', '${r.offering.name} · with admin', r.total, 2),
      for (final r in requests)
        if (r.status == RequestStatus.completed)
          ('Service #${r.id}', r.offering.name, r.total, 1),
      for (final o in orders)
        (
          'Order ${o.id}',
          '${o.items.length} parts · ${o.status.label}',
          o.total,
          o.status.held ? 0 : 1,
        ),
    ];

    final heldTotal = held
        .where((e) => e.$4 != 1)
        .fold<double>(0, (sum, e) => sum + e.$3);
    final releasedTotal = held
        .where((e) => e.$4 == 1)
        .fold<double>(0, (sum, e) => sum + e.$3);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    color: AppColors.amberSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 15, color: AppColors.amberText),
                            SizedBox(width: 6),
                            Text('Held in escrow',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.amberText)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'OMR ${heldTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7C5205),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppCard(
                    color: AppColors.goodSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_open_rounded,
                                size: 15, color: AppColors.good),
                            SizedBox(width: 6),
                            Text('Released',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.good)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'OMR ${releasedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF046C4E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SectionHeader('Transactions'),
            const SizedBox(height: 10),
            if (held.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No payments yet — they appear here when you book or order.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.ink2),
                  ),
                ),
              )
            else
              for (final (i, e) in held.indexed) ...[
                Entrance(
                  delayMs: 40 * i,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        IconTile(
                          switch (e.$4) {
                            0 => Icons.lock_outline_rounded,
                            2 => Icons.gavel_rounded,
                            _ => Icons.lock_open_rounded,
                          },
                          size: 38,
                          radius: 12,
                          background: switch (e.$4) {
                            0 => AppColors.amberSoft,
                            2 => AppColors.badSoft,
                            _ => AppColors.goodSoft,
                          },
                          foreground: switch (e.$4) {
                            0 => const Color(0xFFB45309),
                            2 => AppColors.bad,
                            _ => AppColors.good,
                          },
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.$1,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text(e.$2,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.ink3)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'OMR ${e.$3.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800),
                            ),
                            switch (e.$4) {
                              0 => const StatusBadge.warn('Held'),
                              2 => const StatusBadge.bad('Disputed'),
                              _ => const StatusBadge.good('Released'),
                            },
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}
