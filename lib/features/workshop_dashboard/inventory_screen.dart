import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/provider_dashboard_state.dart';
import 'inventory_item_editor.dart';
import 'stock_movement_sheet.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _query = TextEditingController();
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<InventoryItem> _filter(List<InventoryItem> items) {
    final q = _query.text.trim().toLowerCase();
    return [
      for (final item in items)
        if (item.isActive &&
            (!_lowStockOnly || item.isLowStock) &&
            (q.isEmpty ||
                item.name.ar.toLowerCase().contains(q) ||
                item.name.en.toLowerCase().contains(q) ||
                item.sku.toLowerCase().contains(q)))
          item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final inventory = ref.watch(workshopInventoryProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('المخزون', 'Inventory'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showInventoryItemEditor(context),
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(workshopInventoryProvider.notifier).refresh(),
          child: inventory.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: const [ListSkeleton()],
            ),
            error: (error, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                EmptyState(
                  icon: LucideIcons.circleAlert,
                  message: s.t(
                    'تعذّر تحميل المخزون.',
                    'Couldn\'t load inventory.',
                  ),
                  action: FilledButton(
                    onPressed: () =>
                        ref.read(workshopInventoryProvider.notifier).refresh(),
                    child: Text(s.t('إعادة المحاولة', 'Retry')),
                  ),
                ),
              ],
            ),
            data: (items) {
              final active = [
                for (final i in items)
                  if (i.isActive) i,
              ];
              final stockValue = active.fold<double>(
                0,
                (sum, i) => sum + i.stockValue,
              );
              final filtered = _filter(items);

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  TextField(
                    controller: _query,
                    decoration: InputDecoration(
                      hintText: s.t(
                        'ابحث بالاسم أو الرمز',
                        'Search by name or SKU',
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      FilterChip(
                        label: Text(s.t('منخفض المخزون فقط', 'Low stock only')),
                        selected: _lowStockOnly,
                        onSelected: (v) => setState(() => _lowStockOnly = v),
                      ),
                      const Spacer(),
                      RialAmount(
                        stockValue,
                        prefix: '${s.t('قيمة المخزون', 'Stock value')}: ',
                        style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (filtered.isEmpty)
                    EmptyState(
                      icon: LucideIcons.boxes,
                      title: s.t('لا عناصر', 'No items'),
                      message: items.isEmpty
                          ? s.t(
                              'أضف أول عنصر في مخزون الورشة.',
                              'Add the first item in your workshop\'s stock.',
                            )
                          : s.t('لا نتائج مطابقة.', 'No matching results.'),
                      compact: true,
                    )
                  else
                    for (final item in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _InventoryRow(item: item),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InventoryRow extends ConsumerWidget {
  const _InventoryRow({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name.of(s),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (item.isLowStock) StatusBadge.warn(s.t('منخفض', 'Low')),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.sku} · ${item.quantityOnHand} ${item.unit.label(s)}',
                  style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.t('تسجيل حركة مخزون', 'Record a movement'),
            icon: const Icon(LucideIcons.arrowUpDown, size: 16),
            onPressed: () => showStockMovementSheet(context, ref, item),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'edit':
                  await showInventoryItemEditor(context, existing: item);
                case 'delete':
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(s.t('حذف العنصر؟', 'Delete this item?')),
                      content: Text(
                        s.t(
                          'إذا كان مستخدماً في طلب مفتوح سيُرفض الحذف.',
                          'If it\'s used by an open booking, this will be refused.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(s.t('إلغاء', 'Cancel')),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: ak.danger,
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(s.t('حذف', 'Delete')),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await ref
                          .read(workshopInventoryProvider.notifier)
                          .delete(item.id);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              s.t(
                                'لا يمكن الحذف — العنصر مستخدم في طلب مفتوح.',
                                'Can\'t delete — this item is used by an open booking.',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(s.t('تعديل', 'Edit'))),
              PopupMenuItem(value: 'delete', child: Text(s.t('حذف', 'Delete'))),
            ],
          ),
        ],
      ),
    );
  }
}
