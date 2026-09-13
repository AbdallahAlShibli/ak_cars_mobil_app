import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/bidi_text.dart';
import '../../core/utils/workshop_validation.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/working_hours_field.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/provider_dashboard_state.dart';

/// The workshop's own registered record — name, area/region, contact, hours,
/// fulfillments, capabilities, pickup fee — with a completeness meter that
/// names what the platform is still waiting on.
///
/// **Read first, edit on purpose.** The screen opens as a plain reading of
/// what is on file, because that is what an owner comes here for nine times
/// out of ten; editing is a deliberate tap on "Edit", not the default state of
/// every field on the screen. Saving writes straight to the live record
/// (`PUT /my-workshop`) — it does *not* re-file the workshop application, so
/// correcting a phone number never puts an approved workshop back into the
/// founder's review queue.
///
/// The certificate is the one thing not editable here: the founder approved
/// *that* document and there is no owner-side endpoint to replace it, so
/// swapping it silently is not something this screen can — or should — offer.
///
/// The meter is the server's own answer (`MyWorkshopProfile.missingFields`,
/// straight off `GET /my-workshop`), not a second guess made here: it is the
/// same list the founder's review reads. Each missing field is named rather
/// than merely counted — "70%" tells nobody which three fields to go and fill
/// in.
class WorkshopProfileScreen extends ConsumerStatefulWidget {
  const WorkshopProfileScreen({super.key});

  @override
  ConsumerState<WorkshopProfileScreen> createState() =>
      _WorkshopProfileScreenState();
}

class _WorkshopProfileScreenState extends ConsumerState<WorkshopProfileScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final profile = ref.watch(myWorkshopProfileProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(
        title: Text(s.t('الملف الشخصي', 'Workshop profile')),
        actions: [
          if (!_editing && profile.hasValue)
            TextButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(LucideIcons.pencil, size: 15),
              label: Text(s.t('تعديل', 'Edit')),
            ),
        ],
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
          data: (profile) => _editing
              ? _ProfileEditor(
                  // Rebuilt per edit session, so Cancel really does drop
                  // everything typed since the last save.
                  key: ValueKey(profile.provider),
                  profile: profile,
                  onClose: () => setState(() => _editing = false),
                )
              : _ProfileView(
                  profile: profile,
                  onEdit: () => setState(() => _editing = true),
                ),
        ),
      ),
    );
  }
}

/// The six fields `GetMyWorkshopQuery` checks, in its order — used only to
/// turn the server's `missingFields` keys back into a count and a label.
const _completenessFields = [
  'phone',
  'whatsapp',
  'hours',
  'vatNumber',
  'fulfillments',
  'crDocument',
];

String _missingFieldLabel(String key, S s) => switch (key) {
  'phone' => s.t('الهاتف', 'Phone'),
  'whatsapp' => s.t('واتساب', 'WhatsApp'),
  'hours' => s.t('ساعات العمل', 'Working hours'),
  'vatNumber' => s.t('الرقم الضريبي', 'VAT number'),
  'fulfillments' => s.t('طرق التنفيذ', 'Fulfillments'),
  'crDocument' => s.t('السجل التجاري', 'Commercial registration'),
  _ => key,
};

List<String> _missingOf(MyWorkshopProfile profile) => [
  for (final key in _completenessFields)
    if (profile.missingFields.contains(key)) key,
];

// ---------------------------------------------------------------- reading

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.profile, required this.onEdit});

  final MyWorkshopProfile profile;
  final VoidCallback onEdit;

  ServiceProvider get provider => profile.provider;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final missing = _missingOf(profile);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      children: [
        _CompletenessCard(profile: profile, missing: missing),
        const SizedBox(height: AppSpacing.md),
        _EditInvitation(hasMissing: missing.isNotEmpty),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('الورشة', 'The workshop')),
        const SizedBox(height: AppSpacing.headingGap),
        AppCard(
          child: Column(
            children: [
              _Fact(label: 'الاسم (عربي)', value: provider.name.ar),
              _Fact(label: 'Name (English)', value: provider.name.en),
              _Fact(label: s.t('المنطقة', 'Area'), value: provider.area),
              _Fact(
                label: s.t('المحافظة', 'Region'),
                value: provider.region,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('التواصل وساعات العمل', 'Contact and hours')),
        const SizedBox(height: AppSpacing.headingGap),
        AppCard(
          child: Column(
            children: [
              _Fact(
                icon: LucideIcons.phone,
                label: s.t('الهاتف', 'Phone'),
                value: provider.phone,
              ),
              _Fact(
                icon: LucideIcons.messageCircle,
                label: s.t('واتساب', 'WhatsApp'),
                value: provider.whatsapp,
              ),
              _Fact(
                icon: LucideIcons.clock,
                label: s.t('ساعات العمل', 'Working hours'),
                value: provider.hours?.of(s),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('السجل التجاري والرسوم', 'Registration and fees')),
        const SizedBox(height: AppSpacing.headingGap),
        AppCard(
          child: Column(
            children: [
              _Fact(
                icon: LucideIcons.fileText,
                label: s.t('رقم السجل التجاري', 'CR number'),
                value: provider.crNumber,
              ),
              _Fact(
                icon: LucideIcons.receipt,
                label: s.t('الرقم الضريبي', 'VAT number'),
                value: provider.vatNumber,
              ),
              _Fact(
                icon: LucideIcons.truck,
                label: s.t('رسوم الاستلام', 'Pickup fee'),
                value: '${provider.pickupFee.toStringAsFixed(3)} ${s.omr}',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('ما تقدّمه الورشة', 'What the workshop offers')),
        const SizedBox(height: AppSpacing.headingGap),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChipRow(
                label: s.t('طرق التنفيذ', 'Fulfillments'),
                values: [for (final f in provider.fulfillments) f.label(s)],
                empty: s.t('لم تُحدَّد بعد', 'Not set yet'),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChipRow(
                label: s.t('القدرات', 'Capabilities'),
                values: [for (final c in provider.capabilities) c.label.of(s)],
                empty: s.t('لم تُحدَّد بعد', 'Not set yet'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(LucideIcons.pencil, size: 17),
            label: Text(s.t('تعديل بيانات الورشة', 'Edit workshop details')),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
      ],
    );
  }
}

/// What this screen is, and what saving it does — stated before the owner
/// starts changing a record customers book against.
class _EditInvitation extends StatelessWidget {
  const _EditInvitation({required this.hasMissing});

  final bool hasMissing;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.idCard, size: 15, color: ak.inkSub),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('بياناتك المسجَّلة', 'Your registered details'),
                  style: context.text.labelStrong,
                ),
                const SizedBox(height: 3),
                Text(
                  hasMissing
                      ? s.t(
                          'هذا ما يراه العملاء عن ورشتك. اضغط "تعديل" لاستكمال '
                              'الناقص أو تحديث أي بيان — يظهر التغيير للعملاء '
                              'فور الحفظ ولا يُعيد طلبك إلى المراجعة. وثيقة '
                              'السجل التجاري وحدها يستبدلها فريق AK Cars.',
                          'This is what customers see about your workshop. Tap '
                              'Edit to fill in what is missing or update '
                              'anything — the change reaches customers as soon '
                              'as you save, and it does not send you back for '
                              'review. The CR certificate is the one thing '
                              'only the AK Cars team can replace.',
                        )
                      : s.t(
                          'هذا ما يراه العملاء عن ورشتك. اضغط "تعديل" لتحديث '
                              'أي بيان — يظهر التغيير للعملاء فور الحفظ ولا '
                              'يُعيد طلبك إلى المراجعة. وثيقة السجل التجاري '
                              'وحدها يستبدلها فريق AK Cars.',
                          'This is what customers see about your workshop. Tap '
                              'Edit to update anything — the change reaches '
                              'customers as soon as you save, and it does not '
                              'send you back for review. The CR certificate is '
                              'the one thing only the AK Cars team can '
                              'replace.',
                        ),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ak.inkSub,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- editing

/// The edit pass over the same record: every field the owner is allowed to
/// change, checked by [WorkshopRules] — the same rules "My details" applies,
/// so a CR number accepted in one screen is accepted in the other.
class _ProfileEditor extends ConsumerStatefulWidget {
  const _ProfileEditor({
    super.key,
    required this.profile,
    required this.onClose,
  });

  final MyWorkshopProfile profile;
  final VoidCallback onClose;

  ServiceProvider get provider => profile.provider;

  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  late final _nameAr = TextEditingController(text: widget.provider.name.ar);
  late final _nameEn = TextEditingController(text: widget.provider.name.en);
  late final _area = TextEditingController(text: widget.provider.area);
  late final _region = TextEditingController(text: widget.provider.region);
  late final _phone = TextEditingController(text: widget.provider.phone);
  late final _whatsapp = TextEditingController(text: widget.provider.whatsapp);
  late final _pickupFee = TextEditingController(
    text: widget.provider.pickupFee.toString(),
  );
  late final _vatNumber = TextEditingController(
    text: widget.provider.vatNumber,
  );
  late final _crNumber = TextEditingController(text: widget.provider.crNumber);

  /// Opening hours are picked, not typed — see [WorkingHoursField]. Null means
  /// the stored sentence could not be read back as days and times; the field
  /// shows it verbatim then, and it is saved unchanged unless taken over.
  late WorkingHours? _hours = WorkingHours.parse(widget.provider.hours);

  late final Set<Fulfillment> _fulfillments = {...widget.provider.fulfillments};
  late final Set<ProviderCapability> _capabilities = {
    ...widget.provider.capabilities,
  };

  final _errors = <String, String>{};
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

  /// Fills [_errors] and reports whether the record can be saved.
  bool _validate(S s) {
    final errors = <String, String>{};
    void check(String key, String? message) {
      if (message != null) errors[key] = message;
    }

    check('nameAr', WorkshopRules.businessNameAr(_nameAr.text, s));
    check('area', WorkshopRules.area(_area.text, s));
    check('region', WorkshopRules.region(_region.text, s));
    // Not *required* here, unlike registration: a workshop that has not filled
    // its phone in yet is an incomplete profile, which the meter above already
    // says out loud. What is refused is a wrong one.
    check('phone', WorkshopRules.omanPhone(_phone.text, s, required: false));
    check('whatsapp', WorkshopRules.whatsapp(_whatsapp.text, s));
    check(
      'crNumber',
      WorkshopRules.crNumber(_crNumber.text, s, required: false),
    );
    check('vatNumber', WorkshopRules.vatNumber(_vatNumber.text, s));
    check('pickupFee', WorkshopRules.pickupFee(_pickupFee.text, s));
    check('fulfillments', WorkshopRules.fulfillments(_fulfillments, s));

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  String? _trimmedOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final s = S.of(context);
    if (!_validate(s)) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _saving = true);
    try {
      final nameAr = _nameAr.text.trim();
      final nameEn = _nameEn.text.trim();
      await ref
          .read(myWorkshopProfileProvider.notifier)
          .save(
            // An empty English name would leave English-speaking customers
            // looking at a blank card, so it falls back to the Arabic one.
            name: L(nameAr, nameEn.isEmpty ? nameAr : nameEn),
            area: _area.text.trim(),
            region: _region.text.trim(),
            phone: _trimmedOrNull(_phone),
            whatsapp: _trimmedOrNull(_whatsapp),
            // Unreadable stored text is passed straight back rather than
            // blanked: no picker was shown for it, so nothing here is a
            // decision to change it.
            hours: _hours?.format() ?? widget.provider.hours,
            fulfillments: _fulfillments,
            capabilities: _capabilities,
            pickupFee:
                double.tryParse(_pickupFee.text.trim()) ??
                widget.provider.pickupFee,
            vatNumber: _trimmedOrNull(_vatNumber),
            crNumber: _trimmedOrNull(_crNumber),
          );
      // The customer-facing roster is a separate cache — the status dialog on
      // "My account" and the services list both read it, and without this they
      // would keep showing the old name until the next cold start.
      await _refreshRoster();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.t('تم الحفظ', 'Saved'))));
      widget.onClose();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t('تعذّر الحفظ — حاول مرة أخرى.', 'Couldn\'t save — try again.'),
          ),
        ),
      );
    }
  }

  /// Never allowed to fail the save it follows: the record *is* saved by the
  /// time this runs, and reporting "couldn't save" because a second, optional
  /// fetch timed out would be a lie.
  Future<void> _refreshRoster() async {
    try {
      await ref.read(serviceMarketplaceRepositoryProvider).refreshProviders();
    } catch (_) {
      // The dashboard already shows the new record; the roster catches up on
      // its next refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: ak.amberBgSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ak.amberBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.pencil, size: 15, color: ak.amberText),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  s.t(
                    'أنت تعدّل بيانات ورشتك. ما تحفظه هنا يراه العملاء.',
                    'You are editing your workshop details. What you save here '
                        'is what customers see.',
                  ),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ak.amberDeep,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('الورشة', 'The workshop')),
        const SizedBox(height: AppSpacing.headingGap),
        TextField(
          controller: _nameAr,
          onChanged: (_) => _clear('nameAr'),
          decoration: InputDecoration(
            labelText: 'الاسم (عربي)',
            errorText: _errors['nameAr'],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _nameEn,
          decoration: const InputDecoration(labelText: 'Name (English)'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _area,
                onChanged: (_) => _clear('area'),
                decoration: InputDecoration(
                  labelText: s.t('المنطقة', 'Area'),
                  errorText: _errors['area'],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _region,
                onChanged: (_) => _clear('region'),
                decoration: InputDecoration(
                  labelText: s.t('المحافظة', 'Region'),
                  errorText: _errors['region'],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('التواصل وساعات العمل', 'Contact and hours')),
        const SizedBox(height: AppSpacing.headingGap),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _clear('phone'),
          decoration: InputDecoration(
            labelText: s.t('الهاتف', 'Phone'),
            errorText: _errors['phone'],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _clear('whatsapp'),
          decoration: InputDecoration(
            labelText: s.t('واتساب', 'WhatsApp'),
            errorText: _errors['whatsapp'],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        WorkingHoursField(
          value: _hours,
          savedText: widget.provider.hours?.of(s),
          onChanged: (hours) => setState(() => _hours = hours),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('السجل التجاري والرسوم', 'Registration and fees')),
        const SizedBox(height: AppSpacing.headingGap),
        TextField(
          controller: _crNumber,
          keyboardType: TextInputType.number,
          onChanged: (_) => _clear('crNumber'),
          decoration: InputDecoration(
            labelText: s.t('رقم السجل التجاري', 'CR number'),
            errorText: _errors['crNumber'],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _vatNumber,
          onChanged: (_) => _clear('vatNumber'),
          decoration: InputDecoration(
            labelText: s.t('الرقم الضريبي', 'VAT number'),
            helperText: s.t('اختياري', 'Optional'),
            errorText: _errors['vatNumber'],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _pickupFee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _clear('pickupFee'),
          decoration: InputDecoration(
            labelText: s.t('رسوم الاستلام', 'Pickup fee'),
            suffixText: s.omr,
            errorText: _errors['pickupFee'],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Notice(
          icon: LucideIcons.fileText,
          message: s.t(
            'وثيقة السجل التجاري لا تُستبدل من هنا — راجع الدعم إن تغيّر سجلك.',
            'The CR certificate cannot be replaced here — talk to support if '
                'your registration changed.',
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('ما تقدّمه الورشة', 'What the workshop offers')),
        const SizedBox(height: AppSpacing.headingGap),
        Text(
          s.t('طرق التنفيذ', 'Fulfillments'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final f in Fulfillment.values)
              FilterChip(
                label: Text(f.label(s)),
                selected: _fulfillments.contains(f),
                onSelected: (v) => setState(() {
                  if (v) {
                    _fulfillments.add(f);
                  } else {
                    _fulfillments.remove(f);
                  }
                  _errors.remove('fulfillments');
                }),
              ),
          ],
        ),
        if (_errors['fulfillments'] != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _errors['fulfillments']!,
            style: TextStyle(fontSize: 11.5, color: ak.dangerText),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          s.t('القدرات', 'Capabilities'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
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
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.t('حفظ التعديلات', 'Save changes')),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 44,
          child: TextButton(
            onPressed: _saving ? null : widget.onClose,
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  void _clear(String key) {
    if (!_errors.containsKey(key)) return;
    setState(() => _errors.remove(key));
  }
}

// ---------------------------------------------------------------- shared

/// How much of the record the platform has, and exactly which fields are
/// still missing.
class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.profile, required this.missing});

  final MyWorkshopProfile profile;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final done = _completenessFields.length - missing.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                profile.isComplete
                    ? LucideIcons.badgeCheck
                    : LucideIcons.circleDashed,
                size: 16,
                color: profile.isComplete ? ak.success : ak.amberText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  profile.isComplete
                      ? s.t('السجل مكتمل', 'Record complete')
                      : s.t('سجل الورشة غير مكتمل', 'Record incomplete'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Text(
                '$done/${_completenessFields.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: ak.inkSub,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: done / _completenessFields.length,
              minHeight: 8,
              backgroundColor: ak.surfaceDim,
              color: profile.isComplete ? ak.success : ak.primary,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.t(
                'ما زال ناقصاً — أكمله ليظهر ملفك بثقة أكبر للعملاء:',
                'Still missing — fill these in so your profile reads as '
                    'trustworthy:',
              ),
              style: TextStyle(fontSize: 11, color: ak.inkFaint),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final key in missing)
                  StatusBadge.warn(_missingFieldLabel(key, s)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One registered field, read-only. An empty one is shown as "not set" rather
/// than hidden: a missing phone number is information the owner needs, and a
/// row that is simply absent looks like a bug.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.icon,
    this.last = false,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final text = (value ?? '').trim();

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 14, color: ak.inkFaint),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: ak.inkSub)),
                const SizedBox(height: 2),
                Text(
                  text.isEmpty
                      ? s.t('غير مُسجَّل', 'Not set')
                      : isolateNumbers(text, rtl: s.isAr),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: text.isEmpty ? ak.inkFaint : ak.ink,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled set of values shown as pills. Deliberately not `FilterChip`
/// while reading: nothing there is selectable, and a chip that looks tappable
/// but is not is worse than plain text.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.values,
    required this.empty,
  });

  final String label;
  final List<String> values;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: ak.inkSub)),
        const SizedBox(height: AppSpacing.sm),
        if (values.isEmpty)
          Text(
            empty,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: ak.inkFaint,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [for (final value in values) StatusBadge(value)],
          ),
      ],
    );
  }
}

/// A quiet one-line note inside the editor.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: ak.inkFaint),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 11, color: ak.inkFaint, height: 1.5),
          ),
        ),
      ],
    );
  }
}
