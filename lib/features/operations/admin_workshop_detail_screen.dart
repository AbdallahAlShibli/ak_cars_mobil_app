import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/working_hours_field.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/admin_state.dart';
import '../../state/admin_workshop_detail_state.dart';
import '../services/service_photo_field.dart';
import 'admin_workshops_tab.dart' show PhoneField, showCrDocumentDialog;

/// The founder's "manage this workshop" screen — profile, offerings and
/// add-ons for one workshop picked from the roster (`_RosterRow`'s "Manage"
/// button in `admin_screen.dart`), plus the destructive delete action.
///
/// Same section shapes as the owner's own `workshop_profile_screen.dart` /
/// `offerings_screen.dart` / `add_ons_screen.dart`, deliberately not reused
/// directly: those are wired to `provider_dashboard_state.dart`, which always
/// means "the signed-in account's own workshop." This screen needs an
/// explicit `providerId` on every read/write instead, which is what
/// `admin_workshop_detail_state.dart`'s family notifiers provide.
class AdminWorkshopDetailScreen extends ConsumerWidget {
  const AdminWorkshopDetailScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final profile = ref.watch(adminWorkshopProfileProvider(providerId));

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(
        title: Text(
          profile.valueOrNull?.name.of(s) ??
              s.t('إدارة الورشة', 'Manage workshop'),
        ),
      ),
      body: SafeArea(
        child: profile.when(
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
                  'تعذّر تحميل بيانات الورشة.',
                  'Couldn\'t load this workshop.',
                ),
                action: FilledButton(
                  onPressed: () => ref
                      .read(adminWorkshopProfileProvider(providerId).notifier)
                      .refresh(),
                  child: Text(s.t('إعادة المحاولة', 'Retry')),
                ),
              ),
            ],
          ),
          data: (provider) => ListView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            children: [
              _ProfileSection(providerId: providerId, provider: provider),
              const SizedBox(height: AppSpacing.sectionGap),
              SectionHeader(s.t('الخدمات', 'Offerings')),
              const SizedBox(height: AppSpacing.headingGap),
              _OfferingsSection(providerId: providerId),
              const SizedBox(height: AppSpacing.sectionGap),
              SectionHeader(s.t('الإضافات', 'Add-ons')),
              const SizedBox(height: AppSpacing.headingGap),
              _AddOnsSection(providerId: providerId),
              const SizedBox(height: AppSpacing.sectionGap),
              _DeleteWorkshopButton(providerId: providerId, provider: provider),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- profile

class _ProfileSection extends ConsumerStatefulWidget {
  const _ProfileSection({required this.providerId, required this.provider});

  final String providerId;
  final ServiceProvider provider;

  @override
  ConsumerState<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<_ProfileSection> {
  late final _nameAr = TextEditingController(text: widget.provider.name.ar);
  late final _nameEn = TextEditingController(text: widget.provider.name.en);
  late final _area = TextEditingController(text: widget.provider.area);
  late final _region = TextEditingController(text: widget.provider.region);
  late final _phone = TextEditingController(text: widget.provider.phone);
  late final _whatsapp = TextEditingController(text: widget.provider.whatsapp);

  /// Opening hours are picked, not typed — see [WorkingHoursField]. Null
  /// means the stored sentence could not be read back as days and times; the
  /// field then shows it verbatim and this screen saves it unchanged unless
  /// the founder takes it over.
  late WorkingHours? _hours = WorkingHours.parse(widget.provider.hours);
  late final _pickupFee = TextEditingController(
    text: widget.provider.pickupFee.toString(),
  );
  late final _vatNumber = TextEditingController(
    text: widget.provider.vatNumber,
  );
  late final _crNumber = TextEditingController(text: widget.provider.crNumber);
  late final Set<Fulfillment> _fulfillments = {...widget.provider.fulfillments};
  late final Set<ProviderCapability> _capabilities = {
    ...widget.provider.capabilities,
  };
  bool _saving = false;

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _area.dispose();
    _region.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _pickupFee.dispose();
    _vatNumber.dispose();
    _crNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = S.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(adminWorkshopProfileProvider(widget.providerId).notifier)
          .save(
            name: L(_nameAr.text.trim(), _nameEn.text.trim()),
            area: _area.text.trim(),
            region: _region.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            whatsapp: _whatsapp.text.trim().isEmpty
                ? null
                : _whatsapp.text.trim(),
            // Unreadable stored text is passed straight back rather than
            // blanked: the founder has not been shown a picker for it, so
            // nothing here is a decision to change it.
            hours: _hours?.format() ?? widget.provider.hours,
            fulfillments: _fulfillments,
            capabilities: _capabilities,
            pickupFee:
                double.tryParse(_pickupFee.text.trim()) ??
                widget.provider.pickupFee,
            vatNumber: _vatNumber.text.trim().isEmpty
                ? null
                : _vatNumber.text.trim(),
            crNumber: _crNumber.text.trim().isEmpty
                ? null
                : _crNumber.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.t('تم الحفظ', 'Saved'))));
      }
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
    final s = S.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(s.t('الملف الشخصي', 'Profile')),
          const SizedBox(height: AppSpacing.headingGap),
          PhoneField(provider: widget.provider),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => showCrDocumentDialog(context, widget.provider),
              icon: const Icon(LucideIcons.fileText, size: 15),
              label: Text(
                widget.provider.crDocument == null
                    ? s.t('رفع وثيقة السجل التجاري', 'Upload CR document')
                    : s.t(
                        'عرض/استبدال وثيقة السجل التجاري',
                        'View / replace CR document',
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameAr,
            decoration: const InputDecoration(labelText: 'الاسم (عربي)'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nameEn,
            decoration: const InputDecoration(labelText: 'Name (English)'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _area,
                  decoration: InputDecoration(
                    labelText: s.t('المنطقة', 'Area'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _region,
                  decoration: InputDecoration(
                    labelText: s.t('المحافظة', 'Region'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _phone,
            decoration: InputDecoration(labelText: s.t('الهاتف', 'Phone')),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _whatsapp,
            decoration: InputDecoration(labelText: s.t('واتساب', 'WhatsApp')),
          ),
          const SizedBox(height: AppSpacing.md),
          WorkingHoursField(
            value: _hours,
            savedText: widget.provider.hours?.of(s),
            onChanged: (hours) => setState(() => _hours = hours),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _pickupFee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: s.t('رسوم الاستلام', 'Pickup fee'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _vatNumber,
            decoration: InputDecoration(
              labelText: s.t('الرقم الضريبي', 'VAT number'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _crNumber,
            decoration: InputDecoration(
              labelText: s.t('رقم السجل التجاري', 'CR number'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            s.t('طرق التنفيذ', 'Fulfillments'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final f in Fulfillment.values)
                FilterChip(
                  label: Text(f.label(s)),
                  selected: _fulfillments.contains(f),
                  onSelected: (v) => setState(
                    () => v ? _fulfillments.add(f) : _fulfillments.remove(f),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            s.t('القدرات', 'Capabilities'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final c in ProviderCapability.values)
                FilterChip(
                  label: Text(c.label.of(s)),
                  selected: _capabilities.contains(c),
                  onSelected: (v) => setState(
                    () => v ? _capabilities.add(c) : _capabilities.remove(c),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.t('حفظ', 'Save')),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- offerings

class _OfferingsSection extends ConsumerWidget {
  const _OfferingsSection({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final offerings = ref.watch(adminWorkshopOfferingsProvider(providerId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        offerings.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => EmptyState(
            compact: true,
            icon: LucideIcons.circleAlert,
            message: s.t('تعذّر تحميل الخدمات.', 'Couldn\'t load offerings.'),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(
                  compact: true,
                  icon: LucideIcons.wrench,
                  message: s.t('لا خدمات بعد.', 'No offerings yet.'),
                )
              : Column(
                  children: [
                    for (final offering in list) ...[
                      _AdminOfferingCard(
                        providerId: providerId,
                        offering: offering,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _showAdminOfferingEditor(context, providerId),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: Text(s.t('إضافة خدمة', 'Add offering')),
        ),
      ],
    );
  }
}

class _AdminOfferingCard extends ConsumerWidget {
  const _AdminOfferingCard({required this.providerId, required this.offering});

  final String providerId;
  final ServiceOffering offering;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, S s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('حذف الخدمة؟', 'Delete this offering?')),
        content: Text(
          s.t(
            'ستُخفى عن العملاء. إذا كان لها حجز مفتوح سيرفض الطلب.',
            'It will be hidden from customers. If it still has an open booking, this will be refused.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AkColors.of(dialogContext).danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(adminWorkshopOfferingsProvider(providerId).notifier)
          .delete(offering.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t(
                'لا يمكن الحذف — يوجد حجز مفتوح على هذه الخدمة.',
                'Can\'t delete — this offering still has an open booking.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfferingPhotoThumb(photo: offering.photo),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        offering.name.of(s),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    offering.isActive
                        ? StatusBadge.good(s.t('منشورة', 'Live'))
                        : StatusBadge(s.t('مخفية', 'Hidden')),
                  ],
                ),
                const SizedBox(height: 4),
                offering.quoteOnly
                    ? Text(
                        s.t('عرض سعر بعد الفحص', 'Quote after inspection'),
                        style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                      )
                    : RialAmount(
                        offering.price!,
                        style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                      ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'edit':
                  await _showAdminOfferingEditor(
                    context,
                    providerId,
                    existing: offering,
                  );
                case 'toggle':
                  await ref
                      .read(adminWorkshopOfferingsProvider(providerId).notifier)
                      .setActive(offering.id, isActive: !offering.isActive);
                case 'delete':
                  await _confirmDelete(context, ref, s);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(s.t('تعديل', 'Edit'))),
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  offering.isActive
                      ? s.t('إخفاء', 'Unpublish')
                      : s.t('نشر', 'Publish'),
                ),
              ),
              PopupMenuItem(value: 'delete', child: Text(s.t('حذف', 'Delete'))),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showAdminOfferingEditor(
  BuildContext context,
  String providerId, {
  ServiceOffering? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _AdminOfferingEditorSheet(providerId: providerId, existing: existing),
  );
}

class _AdminOfferingEditorSheet extends ConsumerStatefulWidget {
  const _AdminOfferingEditorSheet({required this.providerId, this.existing});

  final String providerId;
  final ServiceOffering? existing;

  @override
  ConsumerState<_AdminOfferingEditorSheet> createState() =>
      _AdminOfferingEditorSheetState();
}

class _AdminOfferingEditorSheetState
    extends ConsumerState<_AdminOfferingEditorSheet> {
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
      final notifier = ref.read(
        adminWorkshopOfferingsProvider(widget.providerId).notifier,
      );
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
          // A plain ListView here leaves SwitchListTile without a Material
          // ancestor above this Container's own background, so its ink splash
          // paints invisibly behind that background (Flutter warns about
          // exactly this). Material(transparency) gives it one without
          // changing how anything looks.
          child: Material(
            type: MaterialType.transparency,
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
                  decoration: const InputDecoration(
                    labelText: 'Name (English)',
                  ),
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
                  title: Text(
                    s.t('عرض سعر بعد الفحص', 'Quote after inspection'),
                  ),
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
      ),
    );
  }
}

// ------------------------------------------------------------- add-ons

class _AddOnsSection extends ConsumerWidget {
  const _AddOnsSection({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final addOns = ref.watch(adminWorkshopAddOnsProvider(providerId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        addOns.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => EmptyState(
            compact: true,
            icon: LucideIcons.circleAlert,
            message: s.t('تعذّر تحميل الإضافات.', 'Couldn\'t load add-ons.'),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(
                  compact: true,
                  icon: LucideIcons.puzzle,
                  message: s.t('لا إضافات بعد.', 'No add-ons yet.'),
                )
              : Column(
                  children: [
                    for (final addOn in list) ...[
                      _AdminAddOnCard(providerId: providerId, addOn: addOn),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _showAdminAddOnEditor(context, providerId),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: Text(s.t('إضافة', 'Add')),
        ),
      ],
    );
  }
}

class _AdminAddOnCard extends ConsumerWidget {
  const _AdminAddOnCard({required this.providerId, required this.addOn});

  final String providerId;
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
            onPressed: () =>
                _showAdminAddOnEditor(context, providerId, existing: addOn),
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
              if (confirmed == true) {
                await ref
                    .read(adminWorkshopAddOnsProvider(providerId).notifier)
                    .delete(addOn.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

void _showAdminAddOnEditor(
  BuildContext context,
  String providerId, {
  AddOn? existing,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _AdminAddOnEditorDialog(providerId: providerId, existing: existing),
  );
}

class _AdminAddOnEditorDialog extends ConsumerStatefulWidget {
  const _AdminAddOnEditorDialog({required this.providerId, this.existing});

  final String providerId;
  final AddOn? existing;

  @override
  ConsumerState<_AdminAddOnEditorDialog> createState() =>
      _AdminAddOnEditorDialogState();
}

class _AdminAddOnEditorDialogState
    extends ConsumerState<_AdminAddOnEditorDialog> {
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
      content: Column(
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.t('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: _ready && !_saving
              ? () async {
                  setState(() => _saving = true);
                  final notifier = ref.read(
                    adminWorkshopAddOnsProvider(widget.providerId).notifier,
                  );
                  final name = L(_nameAr.text.trim(), _nameEn.text.trim());
                  final price = double.parse(_price.text.trim());
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

// ------------------------------------------------------- delete workshop

/// Permanently removing a workshop is more severe than suspending it (that's
/// reversible from the roster with one tap; this is not from the UI at all),
/// so it carries the same "cannot confirm without a written reason"
/// discipline the app already applies to rejection/suspension — see
/// `_RejectionDialog` in `admin_screen.dart`, which this mirrors the shape of
/// rather than importing (that class is private to that file).
class _DeleteWorkshopButton extends ConsumerWidget {
  const _DeleteWorkshopButton({
    required this.providerId,
    required this.provider,
  });

  final String providerId;
  final ServiceProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: ak.danger,
        side: BorderSide(color: ak.dangerBorder),
      ),
      onPressed: () => _confirmDelete(context, ref, s),
      icon: const Icon(LucideIcons.trash2, size: 16),
      label: Text(s.t('حذف الورشة نهائياً', 'Permanently delete workshop')),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, S s) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _DeleteReasonDialog(s: s, provider: provider),
    );
    if (reason == null || reason.trim().isEmpty) return;
    if (!context.mounted) return;

    await ref.read(adminActionsProvider).deleteProvider(providerId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'حُذفت الورشة — لن تظهر بعد الآن للعملاء أو في القائمة.',
            'Workshop deleted — it no longer appears to customers or in the roster.',
          ),
        ),
      ),
    );
    context.pop();
  }
}

class _DeleteReasonDialog extends StatefulWidget {
  const _DeleteReasonDialog({required this.s, required this.provider});

  final S s;
  final ServiceProvider provider;

  @override
  State<_DeleteReasonDialog> createState() => _DeleteReasonDialogState();
}

class _DeleteReasonDialogState extends State<_DeleteReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final ready = _reason.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(s.t('حذف نهائي', 'Permanent delete')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t(
              '"${widget.provider.name.of(s)}" ستختفي عن العملاء وعن قائمتك فوراً. لا يوجد زر لاستعادتها من التطبيق. اكتب السبب للتوثيق.',
              '"${widget.provider.name.of(s)}" disappears from customers and from your roster immediately. There is no undo button in the app. Write why, for the record.',
            ),
            style: context.text.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reason,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: s.t('مثال: نشاط احتيالي مؤكّد', 'e.g. confirmed fraud'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.t('إلغاء', 'Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AkColors.of(context).danger,
          ),
          onPressed: ready
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
          child: Text(s.t('حذف نهائي', 'Delete permanently')),
        ),
      ],
    );
  }
}
