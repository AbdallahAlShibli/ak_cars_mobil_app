import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';

/// Cart & checkout — quantities, summary, escrow-backed payment.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _paying = false;

  Future<void> _checkout() async {
    final items = ref.read(cartItemsProvider);
    final total = ref.read(cartTotalProvider);
    setState(() => _paying = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final order = ref.read(ordersProvider.notifier).place(items, total);
    ref.read(cartProvider.notifier).clear();
    ref.read(notificationsProvider.notifier).push(
          title: 'Order ${order.id} placed',
          body:
              'OMR ${total.toStringAsFixed(2)} held — released when you confirm receipt.',
          icon: Icons.inventory_2_outlined,
          route: '/orders',
        );
    HapticFeedback.heavyImpact();
    context.pushReplacement('/orders');
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartItemsProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: SafeArea(
        child: items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconTile(Icons.shopping_bag_outlined,
                        size: 64,
                        radius: 22,
                        background: AppColors.field,
                        foreground: AppColors.ink3),
                    const SizedBox(height: 12),
                    const Text('Your cart is empty',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Parts you add will appear here.',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.ink2)),
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
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return Entrance(
                          delayMs: 40 * i,
                          child: AppCard(
                            padding: const EdgeInsets.all(11),
                            child: Row(
                              children: [
                                IconTile(item.product.icon,
                                    size: 48,
                                    radius: 14,
                                    background: AppColors.field,
                                    foreground: AppColors.ink2),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.product.name,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(
                                        'OMR ${item.product.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.brandDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _QtyStepper(
                                  qty: item.qty,
                                  onChanged: (q) => ref
                                      .read(cartProvider.notifier)
                                      .setQty(item.product.id, q),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    decoration: const BoxDecoration(
                      color: AppColors.card,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              'OMR ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const EscrowBanner(
                          'Payment held safely — released to the store only after you confirm you received the parts.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _paying ? null : _checkout,
                          child: _paying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white),
                                )
                              : Text(
                                  'Checkout — OMR ${total.toStringAsFixed(2)}'),
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

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
              size: 17,
              color: qty == 1 ? AppColors.bad : AppColors.ink2,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              onChanged(qty - 1);
            },
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              '$qty',
              key: ValueKey(qty),
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded,
                size: 17, color: AppColors.brand),
            onPressed: () {
              HapticFeedback.selectionClick();
              onChanged(qty + 1);
            },
          ),
        ],
      ),
    );
  }
}
