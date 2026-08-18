import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/models.dart';
import '../../state/provider_dashboard_state.dart';

/// Edit the workshop's own profile — name, area/region, contact, hours,
/// fulfillments, capabilities, pickup fee — plus a completeness meter.
///
/// The meter mirrors the same fields `GetMyWorkshopQuery` would flag as
/// missing server-side (phone, whatsapp, hours, VAT number, fulfillments,
/// CR document) — computed here from the already-loaded [ServiceProvider]
/// rather than a second round trip, since the fields it reads are exactly
/// the ones this screen already has on hand.
class WorkshopProfileScreen extends ConsumerWidget {
  const WorkshopProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final profile = ref.watch(myWorkshopProfileProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('الملف الشخصي', 'Workshop profile'))),
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
                  'تعذّر تحميل الملف الشخصي.',
                  'Couldn\'t load the profile.',
                ),
                action: FilledButton(
                  onPressed: () =>
                      ref.read(myWorkshopProfileProvider.notifier).refresh(),
                  child: Text(s.t('إعادة المحاولة', 'Retry')),
                ),
              ),
            ],
          ),
          data: (provider) => _ProfileForm(provider: provider),
        ),
      ),
    );
  }
}

double _completeness(ServiceProvider p) {
  final checks = [
    (p.phone ?? '').isNotEmpty,
    (p.whatsapp ?? '').isNotEmpty,
    p.hours != null,
    p.vatRegistered,
    p.fulfillments.isNotEmpty,
    p.crDocument != null,
  ];
  return checks.where((c) => c).length / checks.length;
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.provider});

  final ServiceProvider provider;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _nameAr = TextEditingController(text: widget.provider.name.ar);
  late final _nameEn = TextEditingController(text: widget.provider.name.en);
  late final _area = TextEditingController(text: widget.provider.area);
  late final _region = TextEditingController(text: widget.provider.region);
  late final _phone = TextEditingController(text: widget.provider.phone);
  late final _whatsapp = TextEditingController(text: widget.provider.whatsapp);
  late final _hoursAr = TextEditingController(text: widget.provider.hours?.ar);
  late final _hoursEn = TextEditingController(text: widget.provider.hours?.en);
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
    _hoursAr.dispose();
    _hoursEn.dispose();
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
          .read(myWorkshopProfileProvider.notifier)
          .save(
            name: L(_nameAr.text.trim(), _nameEn.text.trim()),
            area: _area.text.trim(),
            region: _region.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            whatsapp: _whatsapp.text.trim().isEmpty
                ? null
                : _whatsapp.text.trim(),
            hours: _hoursAr.text.trim().isEmpty && _hoursEn.text.trim().isEmpty
                ? null
                : L(_hoursAr.text.trim(), _hoursEn.text.trim()),
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
    final ak = AkColors.of(context);
    final s = S.of(context);
    final completeness = _completeness(widget.provider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: completeness,
                  minHeight: 8,
                  backgroundColor: ak.surfaceDim,
                  color: completeness == 1 ? ak.success : ak.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${(completeness * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
        if (completeness < 1) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            s.t(
              'أكمل الملف ليظهر بثقة أكبر للعملاء.',
              'Complete the profile so it reads as trustworthy to customers.',
            ),
            style: TextStyle(fontSize: 11, color: ak.inkFaint),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
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
                decoration: InputDecoration(labelText: s.t('المنطقة', 'Area')),
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
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _hoursAr,
          decoration: const InputDecoration(labelText: 'ساعات العمل (عربي)'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _hoursEn,
          decoration: const InputDecoration(labelText: 'Hours (English)'),
        ),
        const SizedBox(height: AppSpacing.sm),
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
    );
  }
}
