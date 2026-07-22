import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

String _orderStatusLabel(S s, OrderStatus status) => switch (status) {
      OrderStatus.placed => s.t('تم الطلب', 'Placed'),
      OrderStatus.processing => s.t('قيد التجهيز', 'Being prepared'),
      OrderStatus.delivered => s.t('تم التوصيل', 'Delivered'),
      OrderStatus.completed => s.t('مكتمل', 'Completed'),
    };

/// Payments — escrow wallet view across service requests and shop orders.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final requests = ref.watch(requestsProvider);
    final orders = ref.watch(ordersProvider);

    // (title, subtitle, amount, state) — state: 0 held, 1 released, 2 disputed
    final held = <(String, String, double, int)>[
      for (final r in requests)
        if (r.status != RequestStatus.completed &&
            r.status != RequestStatus.disputed)
          (
            s.t('خدمة #${r.id}', 'Service #${r.id}'),
            r.offering.name.of(s),
            r.total,
            0
          ),
      for (final r in requests)
        if (r.status == RequestStatus.disputed)
          (
            s.t('خدمة #${r.id}', 'Service #${r.id}'),
            s.t('${r.offering.name.ar} · لدى الإدارة',
                '${r.offering.name.en} · with admin'),
            r.total,
            2
          ),
      for (final r in requests)
        if (r.status == RequestStatus.completed)
          (
            s.t('خدمة #${r.id}', 'Service #${r.id}'),
            r.offering.name.of(s),
            r.total,
            1
          ),
      for (final o in orders)
        (
          s.t('طلب ${o.id}', 'Order ${o.id}'),
          s.t('${o.items.length} قطع · ${_orderStatusLabel(s, o.status)}',
              '${o.items.length} parts · ${_orderStatusLabel(s, o.status)}'),
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
      appBar: AppBar(title: Text(s.t('المدفوعات', 'Payments'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    color: ak.amberSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 15, color: ak.amberText),
                            const SizedBox(width: 6),
                            Text(s.t('محتجز في الضمان', 'Held in escrow'),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: ak.amberText)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.t('${heldTotal.toStringAsFixed(2)} ${s.omr}',
                              'OMR ${heldTotal.toStringAsFixed(2)}'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ak.amberDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppCard(
                    color: ak.successSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_open_rounded,
                                size: 15, color: ak.success),
                            const SizedBox(width: 6),
                            Text(s.t('محرّر', 'Released'),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: ak.success)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.t('${releasedTotal.toStringAsFixed(2)} ${s.omr}',
                              'OMR ${releasedTotal.toStringAsFixed(2)}'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ak.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionHeader(s.t('المعاملات', 'Transactions')),
            const SizedBox(height: 10),
            if (held.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    s.t('لا مدفوعات بعد — تظهر هنا عند الحجز أو الطلب.',
                        'No payments yet — they appear here when you book or order.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: ak.inkSub),
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
                            0 => ak.amberSoft,
                            2 => ak.dangerSoft,
                            _ => ak.successSoft,
                          },
                          foreground: switch (e.$4) {
                            0 => ak.amberText,
                            2 => ak.danger,
                            _ => ak.success,
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
                                  style: TextStyle(
                                      fontSize: 11.5, color: ak.inkFaint)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              s.t('${e.$3.toStringAsFixed(2)} ${s.omr}',
                                  'OMR ${e.$3.toStringAsFixed(2)}'),
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800),
                            ),
                            switch (e.$4) {
                              0 => StatusBadge.warn(s.t('محتجز', 'Held')),
                              2 => StatusBadge.bad(s.t('نزاع', 'Disputed')),
                              _ => StatusBadge.good(s.t('محرّر', 'Released')),
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
