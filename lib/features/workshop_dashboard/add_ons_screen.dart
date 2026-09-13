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

/// Inline CRUD for a workshop's add-ons — simpler than offerings (no
/// category, no include list), so create/edit both happen in one dialog
/// rather than a full sheet.
class AddOnsScreen extends ConsumerWidget {
  const AddOnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final addOns = ref.watch(workshopAddOnsProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('الإضافات', 'Add-ons'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, ref),
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(workshopAddOnsProvider.notifier).refresh(),
          child: addOns.when(
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
                    'تعذّر تحميل الإضافات.',
                    'Couldn\'t load add-ons.',
                  ),
                  action: FilledButton(
                    onPressed: () =>
                        ref.read(workshopAddOnsProvider.notifier).refresh(),
                    child: Text(s.t('إعادة المحاولة', 'Retry')),
                  ),
                ),
              ],
            ),
            data: (list) => list.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    children: [
                      EmptyState(
                        icon: LucideIcons.puzzle,
                        title: s.t('لا إضافات بعد', 'No add-ons yet'),
                        message: s.t(
                          'الإضافات اختيارات إضافية يمكن للعميل طلبها مع الخدمة.',
                          'Add-ons are extras a customer can add on top of a booking.',
                        ),
                        action: FilledButton.icon(
                          onPressed: () => _showEditor(context, ref),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: Text(s.t('إضافة', 'Add')),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _AddOnRow(addOn: list[index]),
                  ),
          ),
        ),
      ),
    );
  }
}

void _showEditor(BuildContext context, WidgetRef ref, {AddOn? existing}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => _AddOnEditorDialog(existing: existing),
  );
}

class _AddOnRow extends ConsumerWidget {
  const _AddOnRow({required this.addOn});

  final AddOn addOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addOn.name.of(s),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    RialAmount(
                      addOn.price,
                      style: TextStyle(fontSize: 12, color: ak.inkSub),
                    ),
                    const SizedBox(width: 8),
                    if (addOn.isPart) StatusBadge(s.t('قطعة', 'Part')),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.t('تعديل الإضافة', 'Edit add-on'),
            icon: const Icon(LucideIcons.pencil, size: 16),
            onPressed: () => _showEditor(context, ref, existing: addOn),
          ),
          IconButton(
            tooltip: s.t('حذف الإضافة', 'Delete add-on'),
            icon: Icon(LucideIcons.trash2, size: 16, color: ak.danger),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(s.t('حذف الإضافة؟', 'Delete this add-on?')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(s.t('إلغاء', 'Cancel')),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: ak.danger),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(s.t('حذف', 'Delete')),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              try {
                await ref
                    .read(workshopAddOnsProvider.notifier)
                    .delete(addOn.id);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        s.t(
                          'تعذّر الحذف — حاول مرة أخرى.',
                          'Couldn\'t delete — try again.',
                        ),
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _AddOnEditorDialog extends ConsumerStatefulWidget {
  const _AddOnEditorDialog({this.existing});

  final AddOn? existing;

  @override
  ConsumerState<_AddOnEditorDialog> createState() => _AddOnEditorDialogState();
}

class _AddOnEditorDialogState extends ConsumerState<_AddOnEditorDialog> {
  late final _nameAr = TextEditingController(text: widget.existing?.name.ar);
  late final _nameEn = TextEditingController(text: widget.existing?.name.en);
  late final _price = TextEditingController(
    text: widget.existing?.price.toString(),
  );
  late bool _isPart = widget.existing?.isPart ?? false;
  bool _saving = false;

  bool get _ready =>
      _nameAr.text.trim().isNotEmpty &&
      _nameEn.text.trim().isNotEmpty &&
      double.tryParse(_price.text.trim()) != null;

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? s.t('إضافة جديدة', 'New add-on')
            : s.t('تعديل الإضافة', 'Edit add-on'),
      ),
      // Scrollable: four fields and an on-screen keyboard overflow a plain
      // Column on a short phone, and an AlertDialog will not scroll for you.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameAr,
              decoration: const InputDecoration(labelText: 'عربي'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _nameEn,
              decoration: const InputDecoration(labelText: 'English'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: s.t('السعر', 'Price')),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.t('قطعة فعلية', 'Physical part')),
              value: _isPart,
              onChanged: (v) => setState(() => _isPart = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.t('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: _ready && !_saving
              ? () async {
                  setState(() => _saving = true);
                  final notifier = ref.read(workshopAddOnsProvider.notifier);
                  final name = L(_nameAr.text.trim(), _nameEn.text.trim());
                  final price = double.parse(_price.text.trim());
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    if (widget.existing == null) {
                      await notifier.create(
                        name: name,
                        price: price,
                        isPart: _isPart,
                      );
                    } else {
                      await notifier.edit(
                        widget.existing!.id,
                        name: name,
                        price: price,
                        isPart: _isPart,
                      );
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (_) {
                    // Was a bare `finally`: a rejected save left the spinner
                    // stopped, the dialog open and nothing said, which reads
                    // as the button not working.
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          s.t(
                            'تعذّر الحفظ — حاول مرة أخرى.',
                            'Couldn\'t save — try again.',
                          ),
                        ),
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                }
              : null,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(s.t('حفظ', 'Save')),
        ),
      ],
    );
  }
}
