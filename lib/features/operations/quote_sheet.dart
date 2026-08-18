import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/rial_symbol.dart';
import '../../data/models/models.dart';

/// The itemised quote form (spec §6) a workshop fills in to price a
/// part-and-fitting request.
///
/// Two amount fields, both required. There is deliberately no single "total"
/// field to type into: a lump sum is the verbal arrangement this transaction
/// replaces, so the model cannot express one and neither can this sheet.
///
/// Shared between `workshop_screen.dart` (the old read-only panel) and
/// `workshop_dashboard/orders_screen.dart` (the new one) — extracted rather
/// than duplicated, since both screens open the same escrow event
/// (`EscrowEvent.submitQuote`) against the same booking shape.
class QuoteSheet extends StatefulWidget {
  const QuoteSheet({super.key, required this.s, required this.request});

  final S s;
  final ServiceRequest request;

  @override
  State<QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<QuoteSheet> {
  final _part = TextEditingController();
  final _partPrice = TextEditingController();
  final _laborPrice = TextEditingController();
  final _brand = TextEditingController();
  final _warranty = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Seeded with what the customer wrote so the workshop corrects it rather
    // than retypes it — and any correction is then visibly the workshop's.
    _part.text = widget.request.partRequest?.description ?? '';
  }

  @override
  void dispose() {
    _part.dispose();
    _partPrice.dispose();
    _laborPrice.dispose();
    _brand.dispose();
    _warranty.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _partAmount => double.tryParse(_partPrice.text.trim());
  double? get _laborAmount => double.tryParse(_laborPrice.text.trim());

  bool get _ready =>
      _part.text.trim().isNotEmpty &&
      (_partAmount ?? -1) >= 0 &&
      (_laborAmount ?? -1) >= 0 &&
      (_partAmount! + _laborAmount!) > 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final ak = AkColors.of(context);
    final total = (_partAmount ?? 0) + (_laborAmount ?? 0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('عرض سعر', 'Quote'), style: context.text.screenTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.t(
                'سعر القطعة وأجرة التركيب منفصلان — هكذا يراهما العميل، وهذا ما يوافق عليه.',
                'The part and the fitting are priced separately — that is how the customer sees them, and what they agree to.',
              ),
              style: context.text.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _part,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: s.t('القطعة التي ستركّبها', 'The part you will fit'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _brand,
              decoration: InputDecoration(
                labelText: s.t(
                  'الماركة/الأصل (اختياري)',
                  'Brand / origin (optional)',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _partPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: s.t('سعر القطعة', 'Part price'),
                      prefixIcon: Center(
                        child: RialGlyph(fontSize: 16, color: ak.inkSub),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _laborPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: s.t('أجرة التركيب', 'Fitting'),
                      prefixIcon: Center(
                        child: RialGlyph(fontSize: 16, color: ak.inkSub),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _warranty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: s.t(
                  'كفالة القطعة بالأيام (اختياري)',
                  'Part warranty in days (optional)',
                ),
                helperText: s.t(
                  'كفالتك أنت على القطعة — غير ضمان الدفع.',
                  "Your own warranty on the part — not the payment escrow.",
                ),
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: s.t(
                  'ملاحظة للعميل (اختياري)',
                  'Note to the customer (optional)',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.t('الإجمالي', 'Total'),
                    style: context.text.bodySecondary,
                  ),
                ),
                RialAmount(total, style: context.text.price),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _ready ? _submit : null,
              child: Text(s.t('إرسال العرض', 'Send the quote')),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() => Navigator.of(context).pop(
    Quote(
      // Replaced by the service, which owns the identity sequence.
      id: 'quote-${widget.request.id}',
      requestId: widget.request.id,
      workshopId: widget.request.offering.provider.id,
      partDescription: _part.text.trim(),
      partPrice: _partAmount!,
      laborPrice: _laborAmount!,
      partBrand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      warrantyDays: int.tryParse(_warranty.text.trim()),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: DateTime.now(),
    ),
  );
}
