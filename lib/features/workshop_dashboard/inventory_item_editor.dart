import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/models.dart';
import '../../state/provider_dashboard_state.dart';

/// Create/edit form for one [InventoryItem]. Deliberately has no field for
/// `quantityOnHand` — that only ever moves through `stock_movement_sheet.dart`.
Future<void> showInventoryItemEditor(
  BuildContext context, {
  InventoryItem? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _InventoryItemEditorSheet(existing: existing),
  );
}

class _InventoryItemEditorSheet extends ConsumerStatefulWidget {
  const _InventoryItemEditorSheet({this.existing});

  final InventoryItem? existing;

  @override
  ConsumerState<_InventoryItemEditorSheet> createState() =>
      _InventoryItemEditorSheetState();
}

class _InventoryItemEditorSheetState
    extends ConsumerState<_InventoryItemEditorSheet> {
  late final _nameAr = TextEditingController(text: widget.existing?.name.ar);
  late final _nameEn = TextEditingController(text: widget.existing?.name.en);
  late final _sku = TextEditingController(text: widget.existing?.sku);
  late final _partNumber = TextEditingController(
    text: widget.existing?.partNumber,
  );
  late final _brand = TextEditingController(text: widget.existing?.brand);
  late final _unitCost = TextEditingController(
    text: widget.existing?.unitCost.toString(),
  );
  late final _sellPrice = TextEditingController(
    text: widget.existing?.sellPrice.toString(),
  );
  late final _reorderLevel = TextEditingController(
    text: widget.existing?.reorderLevel.toString() ?? '0',
  );
  late final _location = TextEditingController(text: widget.existing?.location);
  late InventoryUnit _unit = widget.existing?.unit ?? InventoryUnit.piece;
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _saving = false;

  bool get _ready =>
      _nameAr.text.trim().isNotEmpty &&
      _nameEn.text.trim().isNotEmpty &&
      _sku.text.trim().isNotEmpty &&
      double.tryParse(_unitCost.text.trim()) != null &&
      double.tryParse(_sellPrice.text.trim()) != null &&
      int.tryParse(_reorderLevel.text.trim()) != null;

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _sku.dispose();
    _partNumber.dispose();
    _brand.dispose();
    _unitCost.dispose();
    _sellPrice.dispose();
    _reorderLevel.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    setState(() => _saving = true);
    final notifier = ref.read(workshopInventoryProvider.notifier);
    final name = L(_nameAr.text.trim(), _nameEn.text.trim());
    try {
      if (widget.existing == null) {
        await notifier.create(
          name: name,
          sku: _sku.text.trim(),
          partNumber: _partNumber.text.trim().isEmpty
              ? null
              : _partNumber.text.trim(),
          brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
          unitCost: double.parse(_unitCost.text.trim()),
          sellPrice: double.parse(_sellPrice.text.trim()),
          reorderLevel: int.parse(_reorderLevel.text.trim()),
          unit: _unit,
          location: _location.text.trim().isEmpty
              ? null
              : _location.text.trim(),
        );
      } else {
        await notifier.edit(
          widget.existing!.id,
          name: name,
          sku: _sku.text.trim(),
          partNumber: _partNumber.text.trim().isEmpty
              ? null
              : _partNumber.text.trim(),
          brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
          unitCost: double.parse(_unitCost.text.trim()),
          sellPrice: double.parse(_sellPrice.text.trim()),
          reorderLevel: int.parse(_reorderLevel.text.trim()),
          unit: _unit,
          location: _location.text.trim().isEmpty
              ? null
              : _location.text.trim(),
          isActive: _isActive,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t(
                'تعذّر الحفظ — حاول مرة أخرى.',
                'Couldn\'t save — try again.',
              ),
            ),
          ),
        );
      }
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
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: ak.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            children: [
              Text(
                widget.existing == null
                    ? s.t('عنصر مخزون جديد', 'New inventory item')
                    : s.t('تعديل العنصر', 'Edit item'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameAr,
                decoration: const InputDecoration(labelText: 'الاسم (عربي)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _nameEn,
                decoration: const InputDecoration(labelText: 'Name (English)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _sku,
                decoration: InputDecoration(
                  labelText: s.t('رمز الصنف (SKU)', 'SKU'),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _partNumber,
                decoration: InputDecoration(
                  labelText: s.t('رقم القطعة', 'Part number'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _brand,
                decoration: InputDecoration(labelText: s.t('الماركة', 'Brand')),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _unitCost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: s.t('تكلفة الوحدة', 'Unit cost'),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _sellPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: s.t('سعر البيع', 'Sell price'),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reorderLevel,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: s.t('حد إعادة الطلب', 'Reorder level'),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<InventoryUnit>(
                      initialValue: _unit,
                      decoration: InputDecoration(
                        labelText: s.t('الوحدة', 'Unit'),
                      ),
                      items: [
                        for (final unit in InventoryUnit.values)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(unit.label(s)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _unit = v ?? _unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _location,
                decoration: InputDecoration(
                  labelText: s.t('الموقع في الورشة', 'Location'),
                ),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.t('نشِط', 'Active')),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _ready && !_saving ? _submit : null,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.t('حفظ', 'Save')),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
