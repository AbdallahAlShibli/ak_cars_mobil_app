import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// Shop orders — live lifecycle: placed → prepared → delivered →
/// buyer confirms receipt → escrow released to the store.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('طلبات المتجر', 'Shop orders'))),
      body: SafeArea(
        child: orders.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTile(Icons.inventory_2_outlined,
                        size: 64,
                        radius: 22,
                        background: ak.surfaceDim,
                        foreground: ak.inkFaint),
                    const SizedBox(height: 12),
                    Text(s.t('لا طلبات بعد', 'No orders yet'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 180,
                      child: FilledButton(
                        onPressed: () => context.go('/shop'),
                        child: Text(s.t('تصفّح القطع', 'Browse parts')),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => Entrance(
                  delayMs: 40 * i,
                  child: _OrderCard(order: orders[i]),
                ),
              ),
      ),
    );
  }
}

String _statusLabel(S s, OrderStatus status) => switch (status) {
      OrderStatus.placed => s.t('تم الطلب', 'Placed'),
      OrderStatus.processing => s.t('قيد التجهيز', 'Being prepared'),
      OrderStatus.delivered =>
        s.t('تم التوصيل — أكّد الاستلام', 'Delivered — confirm receipt'),
      OrderStatus.completed => s.t('مكتمل', 'Completed'),
    };

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final Order order;

  static const _stepIcons = [
    Icons.receipt_long_outlined,
    Icons.inventory_2_outlined,
    Icons.local_shipping_outlined,
    Icons.lock_open_rounded,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final statusIndex = order.status.index;

    final badge = switch (order.status) {
      OrderStatus.delivered =>
        StatusBadge.warn(s.t('أكّد الاستلام', 'Confirm receipt')),
      OrderStatus.completed => StatusBadge.good(s.t('مكتمل', 'Completed')),
      _ => StatusBadge(
          s.t('${_statusLabel(s, order.status)} · محتجز',
              '${_statusLabel(s, order.status)} · held')),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.t('الطلب ${order.id}', 'Order ${order.id}'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('d MMM y · h:mm a').format(order.placedAt),
            style: TextStyle(fontSize: 11.5, color: ak.inkFaint),
          ),
          const SizedBox(height: 12),
          // ---- lifecycle strip
          Row(
            children: [
              for (var i = 0; i < _stepIcons.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i <= statusIndex ? ak.success : ak.surfaceDim,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: i < statusIndex
                        ? ak.successSoft
                        : i == statusIndex
                            ? (order.status == OrderStatus.completed
                                ? ak.successSoft
                                : ak.surfaceDim)
                            : ak.surfaceDim,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    i < statusIndex ? Icons.check_rounded : _stepIcons[i],
                    size: 15,
                    color: i < statusIndex
                        ? ak.success
                        : i == statusIndex
                            ? (order.status == OrderStatus.completed
                                ? ak.success
                                : ak.ink)
                            : ak.inkFaint,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _statusLabel(s, order.status),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: order.status == OrderStatus.completed
                  ? ak.success
                  : ak.ink,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(item.product.icon, size: 15, color: ak.inkFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.product.name.of(s)} × ${item.qty}',
                      style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                    ),
                  ),
                  Text(
                    s.t('${item.total.toStringAsFixed(2)} ${s.omr}',
                        'OMR ${item.total.toStringAsFixed(2)}'),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          Divider(height: 16, color: ak.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.status.held
                    ? s.t('الإجمالي محتجز في الضمان', 'Total held in escrow')
                    : s.t('الإجمالي حُوّل للمتجر', 'Total released to store'),
                style: TextStyle(fontSize: 12.5, color: ak.inkSub),
              ),
              Text(
                s.t('${order.total.toStringAsFixed(2)} ${s.omr}',
                    'OMR ${order.total.toStringAsFixed(2)}'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: order.status.held ? ak.ink : ak.success,
                ),
              ),
            ],
          ),
          if (order.status == OrderStatus.delivered) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ak.success,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                ref
                    .read(ordersProvider.notifier)
                    .confirmReceived(order.id);
              },
              icon: const Icon(Icons.lock_open_rounded, size: 17),
              label: Text(s.t('أكّد الاستلام — حرّر الدفع',
                  'Confirm received — release payment')),
            ),
          ] else if (order.status != OrderStatus.completed) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.autorenew_rounded, size: 13, color: ak.inkFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.t('مباشر — المتجر يحدّث هذا تلقائياً.',
                        'Live — the store updates this automatically.'),
                    style: TextStyle(fontSize: 11, color: ak.inkFaint),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(ordersProvider.notifier).advance(order.id),
                  child: Text(s.t('تقديم', 'Skip ahead'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
