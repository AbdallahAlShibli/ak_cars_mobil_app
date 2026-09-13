import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/rial_symbol.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/provider_dashboard_state.dart';
import '../services/service_photo_field.dart';

/// Create/edit form for one [ServiceOffering] — a modal sheet, following
/// `workshop_screen.dart`'s `_QuoteSheet` pattern: controllers seeded from
/// the existing offering when editing, a computed `_ready` flag gates the
/// submit button, and the sheet pops the saved offering rather than
/// mutating state itself.
Future<void> showOfferingEditorSheet(
  BuildContext context, {
  ServiceOffering? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OfferingEditorSheet(existing: existing),
  );
}

class _OfferingEditorSheet extends ConsumerStatefulWidget {
  const _OfferingEditorSheet({this.existing});

  final ServiceOffering? existing;

  @override
  ConsumerState<_OfferingEditorSheet> createState() =>
      _OfferingEditorSheetState();
}

class _OfferingEditorSheetState extends ConsumerState<_OfferingEditorSheet> {
  late final _nameAr = TextEditingController(text: widget.existing?.name.ar);
  late final _nameEn = TextEditingController(text: widget.existing?.name.en);
  late final _descAr = TextEditingController(
    text: widget.existing?.description.ar,
  );
  late final _descEn = TextEditingController(
    text: widget.existing?.description.en,
  );
  late final _price = TextEditingController(
    text: widget.existing?.price == null
        ? ''
        : widget.existing!.price.toString(),
  );
  late final _durationMin = TextEditingController(
    text: widget.existing?.durationMin?.toString() ?? '',
  );
  late final _warrantyMonths = TextEditingController(
    text: widget.existing?.warrantyMonths?.toString() ?? '',
  );
  late bool _quoteAfterInspection = widget.existing?.quoteOnly ?? false;
  late String? _categoryId = widget.existing?.categoryId;
  late List<L> _includes = [...?widget.existing?.includes];
  late MediaAttachment? _photo = widget.existing?.photo;
  bool _saving = false;

  bool get _ready =>
      _nameAr.text.trim().isNotEmpty &&
      _nameEn.text.trim().isNotEmpty &&
      _descAr.text.trim().isNotEmpty &&
      _descEn.text.trim().isNotEmpty &&
      _categoryId != null &&
      (_quoteAfterInspection || double.tryParse(_price.text.trim()) != null);

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _descAr.dispose();
    _descEn.dispose();
    _price.dispose();
    _durationMin.dispose();
    _warrantyMonths.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    setState(() => _saving = true);
    try {
      final notifier = ref.read(workshopOfferingsProvider.notifier);
      final price = _quoteAfterInspection
          ? null
          : double.tryParse(_price.text.trim());
      final durationMin = int.tryParse(_durationMin.text.trim());
      final warrantyMonths = int.tryParse(_warrantyMonths.text.trim());

      if (widget.existing == null) {
        await notifier.create(
          categoryId: _categoryId!,
          name: L(_nameAr.text.trim(), _nameEn.text.trim()),
          description: L(_descAr.text.trim(), _descEn.text.trim()),
          price: price,
          durationMin: durationMin,
          includes: _includes,
          warrantyMonths: warrantyMonths,
          photo: _photo,
        );
      } else {
        await notifier.edit(
          widget.existing!.id,
          categoryId: _categoryId!,
          name: L(_nameAr.text.trim(), _nameEn.text.trim()),
          description: L(_descAr.text.trim(), _descEn.text.trim()),
          price: price,
          durationMin: durationMin,
          includes: _includes,
          warrantyMonths: warrantyMonths,
          photo: _photo,
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

  void _addInclude() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final ar = TextEditingController();
        final en = TextEditingController();
        final s = S.of(dialogContext);
        return AlertDialog(
          title: Text(s.t('إضافة بند', 'Add an included item')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ar,
                decoration: const InputDecoration(labelText: 'عربي'),
              ),
              TextField(
                controller: en,
                decoration: const InputDecoration(labelText: 'English'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(s.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (ar.text.trim().isEmpty && en.text.trim().isEmpty) return;
                setState(
                  () => _includes = [
                    ..._includes,
                    L(
                      ar.text.trim(),
                      en.text.trim().isEmpty ? ar.text.trim() : en.text.trim(),
                    ),
                  ],
                );
                Navigator.of(dialogContext).pop();
              },
              child: Text(s.t('إضافة', 'Add')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final categories = ref
        .watch(serviceMarketplaceRepositoryProvider)
        .categories;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
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
                    ? s.t('خدمة جديدة', 'New offering')
                    : s.t('تعديل الخدمة', 'Edit offering'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: InputDecoration(
                  labelText: s.t('التصنيف', 'Category'),
                ),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name.of(s))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: AppSpacing.sm),
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
                controller: _descAr,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'الوصف (عربي)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _descEn,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (English)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              ServicePhotoField(
                value: _photo,
                onChanged: (photo) => setState(() => _photo = photo),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.t('عرض سعر بعد الفحص', 'Quote after inspection')),
                value: _quoteAfterInspection,
                onChanged: (v) => setState(() => _quoteAfterInspection = v),
              ),
              if (!_quoteAfterInspection)
                TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: s.t('السعر', 'Price'),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(14),
                      child: RialGlyph(fontSize: 14, color: ak.ink),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _durationMin,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.t('المدة (دقائق)', 'Duration (minutes)'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _warrantyMonths,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.t('الضمان (أشهر)', 'Warranty (months)'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.t('البنود المشمولة', 'Included items'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addInclude,
                    icon: const Icon(LucideIcons.plus, size: 15),
                    label: Text(s.t('إضافة', 'Add')),
                  ),
                ],
              ),
              for (final include in _includes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(include.of(s)),
                  trailing: IconButton(
                    tooltip: s.t('إزالة البند', 'Remove item'),
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => setState(
                      () => _includes = [
                        for (final i in _includes)
                          if (i != include) i,
                      ],
                    ),
                  ),
                ),
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
