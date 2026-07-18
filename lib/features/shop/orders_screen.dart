import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// Shop orders — live lifecycle: placed → prepared → delivered →
/// buyer confirms receipt → escrow released to the store.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shop orders')),
      body: SafeArea(
        child: orders.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconTile(Icons.inventory_2_outlined,
                        size: 64,
                        radius: 22,
                        background: AppColors.field,
                        foreground: AppColors.ink3),
                    const SizedBox(height: 12),
                    const Text('No orders yet',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 180,
                      child: FilledButton(
                        onPressed: () => context.go('/shop'),
                        child: const Text('Browse parts'),
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

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final Order order;

  static const _steps = [
    (OrderStatus.placed, 'Placed & paid', Icons.receipt_long_outlined),
    (OrderStatus.processing, 'Being prepared', Icons.inventory_2_outlined),
    (OrderStatus.delivered, 'Delivered', Icons.local_shipping_outlined),
    (OrderStatus.completed, 'Received → released', Icons.lock_open_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusIndex = order.status.index;

    final badge = switch (order.status) {
      OrderStatus.delivered => const StatusBadge.warn('Confirm receipt'),
      OrderStatus.completed => const StatusBadge.good('Completed'),
      _ => StatusBadge('${order.status.label} · held'),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Order ${order.id}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('d MMM y · h:mm a').format(order.placedAt),
            style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
          ),
          const SizedBox(height: 12),
          // ---- lifecycle strip
          Row(
            children: [
              for (final (i, step) in _steps.indexed) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i <= statusIndex
                            ? AppColors.good
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Tooltip(
                  message: step.$2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: i < statusIndex
                          ? AppColors.goodSoft
                          : i == statusIndex
                              ? (order.status == OrderStatus.completed
                                  ? AppColors.goodSoft
                                  : AppColors.brandSoft)
                              : AppColors.field,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      i < statusIndex ? Icons.check_rounded : step.$3,
                      size: 15,
                      color: i < statusIndex
                          ? AppColors.good
                          : i == statusIndex
                              ? (order.status == OrderStatus.completed
                                  ? AppColors.good
                                  : AppColors.brand)
                              : AppColors.ink3,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.status.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: order.status == OrderStatus.completed
                  ? AppColors.good
                  : AppColors.brand,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(item.product.icon, size: 15, color: AppColors.ink3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.product.name} × ${item.qty}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.ink2),
                    ),
                  ),
                  Text(
                    'OMR ${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.status.held
                    ? 'Total held in escrow'
                    : 'Total released to store',
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.ink2),
              ),
              Text(
                'OMR ${order.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: order.status.held
                      ? AppColors.brandDark
                      : AppColors.good,
                ),
              ),
            ],
          ),
          if (order.status == OrderStatus.delivered) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.good,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                ref
                    .read(ordersProvider.notifier)
                    .confirmReceived(order.id);
              },
              icon: const Icon(Icons.lock_open_rounded, size: 17),
              label: const Text('Confirm received — release payment'),
            ),
          ] else if (order.status != OrderStatus.completed) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.autorenew_rounded,
                    size: 13, color: AppColors.ink3),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Live — the store updates this automatically.',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.ink3),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(ordersProvider.notifier).advance(order.id),
                  child:
                      const Text('Skip ahead', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
