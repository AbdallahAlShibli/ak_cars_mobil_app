import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/models.dart';
import '../../state/provider_dashboard_state.dart';

/// Quick +/- stock action, or a full "record a movement" form — the one
/// place [InventoryItem.quantityOnHand] is allowed to change on this screen,
/// mirroring the server's own rule that quantity only ever moves through a
/// movement (`RecordInventoryMovementCommand`), never a direct edit.
Future<void> showStockMovementSheet(
  BuildContext context,
  WidgetRef ref,
  InventoryItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _StockMovementSheet(item: item),
  );
}

class _StockMovementSheet extends ConsumerStatefulWidget {
  const _StockMovementSheet({required this.item});

  final InventoryItem item;

  @override
  ConsumerState<_StockMovementSheet> createState() =>
      _StockMovementSheetState();
}

class _StockMovementSheetState extends ConsumerState<_StockMovementSheet> {
  late final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  InventoryMovementReason _reason = InventoryMovementReason.purchase;
  bool _isAddition = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    final quantity = int.tryParse(_quantity.text.trim());
    if (quantity == null || quantity <= 0) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(workshopInventoryProvider.notifier)
          .recordMovement(
            widget.item.id,
            delta: _isAddition ? quantity : -quantity,
            reason: _reason,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(
        () => _error = s.t(
          'تعذّر التسجيل — قد يكون الرصيد غير كافٍ.',
          'Couldn\'t record this — stock may not be sufficient.',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        left: AppSpacing.screenMargin,
        right: AppSpacing.screenMargin,
        top: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.name.of(s),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            s.t(
              'الرصيد الحالي: ${widget.item.quantityOnHand}',
              'Currently: ${widget.item.quantityOnHand}',
            ),
            style: TextStyle(fontSize: 12, color: ak.inkSub),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(s.t('إضافة', 'Stock in'))),
              ButtonSegment(value: false, label: Text(s.t('سحب', 'Stock out'))),
            ],
            selected: {_isAddition},
            onSelectionChanged: (selection) =>
                setState(() => _isAddition = selection.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: s.t('الكمية', 'Quantity')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<InventoryMovementReason>(
            initialValue: _reason,
            decoration: InputDecoration(labelText: s.t('السبب', 'Reason')),
            items: [
              for (final reason in InventoryMovementReason.values)
                DropdownMenuItem(value: reason, child: Text(reason.label(s))),
            ],
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: s.t('ملاحظة (اختياري)', 'Note (optional)'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: TextStyle(color: ak.danger, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.t('تسجيل', 'Record')),
          ),
        ],
      ),
    );
  }
}
