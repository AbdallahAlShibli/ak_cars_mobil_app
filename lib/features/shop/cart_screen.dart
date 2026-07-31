import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';

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
    setState(() => _paying = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    // Placing the order raises the "funds held" notification itself.
    await ref.read(ordersProvider.notifier).place(items);
    ref.read(cartProvider.notifier).clear();
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    context.pushReplacement('/orders');
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final items = ref.watch(cartItemsProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('السلة', 'Cart'))),
      body: SafeArea(
        child: items.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: LucideIcons.shoppingBag,
                    title: s.t('سلتك فارغة', 'Your cart is empty'),
                    message: s.t(
                      'القطع التي تضيفها تنتظرك هنا حتى تقرّر.',
                      'Anything you add waits here until you decide.',
                    ),
                    action: SizedBox(
                      width: 200,
                      child: FilledButton(
                        onPressed: () => context.go('/shop'),
                        child: Text(s.t('تصفّح القطع', 'Browse parts')),
                      ),
                    ),
                  ),
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
                                    background: ak.surfaceDim,
                                    foreground: ak.inkSub),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.product.name.of(s),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(
                                        s.t(
                                            '${item.product.price.toStringAsFixed(2)} ${s.omr}',
                                            'OMR ${item.product.price.toStringAsFixed(2)}'),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: ak.ink,
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
                    decoration: BoxDecoration(
                      color: ak.surface,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.t('الإجمالي', 'Total'),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              s.t('${total.toStringAsFixed(2)} ${s.omr}',
                                  'OMR ${total.toStringAsFixed(2)}'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: ak.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        EscrowBanner(
                          s.t(
                              'المبلغ محتجز بأمان — يُحوّل للمتجر فقط بعد تأكيدك استلام القطع.',
                              'Payment held safely — released to the store only after you confirm you received the parts.'),
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
                              : Text(s.t(
                                  'الدفع — ${total.toStringAsFixed(2)} ${s.omr}',
                                  'Checkout — OMR ${total.toStringAsFixed(2)}')),
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
    final ak = AkColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              qty == 1 ? LucideIcons.trash2 : LucideIcons.minus,
              size: 17,
              color: qty == 1 ? ak.danger : ak.inkSub,
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
            icon: Icon(LucideIcons.plus, size: 17, color: ak.ink),
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
