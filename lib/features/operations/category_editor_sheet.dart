import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/app_exception.dart';
import '../../core/i18n/strings.dart';
import '../../core/json/icon_codec.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';

/// Slugs the app itself reads.
///
/// `MaintenanceTypeX.forCategory` resets a maintenance line from the first
/// eight; the booking screen treats `sos` as an emergency callout that skips
/// time slots and defaults to roadside. Everything else about a category is
/// wording.
///
/// Kept here, next to the editor that can change one, rather than derived from
/// the mapper: the mapper's job is to answer "which line does this reset", and
/// this list's job is to warn a founder *before* they change the answer. A slug
/// added to the mapper but not here costs a warning, not a behaviour — which is
/// the right way round for a list that exists to explain.
const _behaviouralSlugs = <String, (String, String)>{
  'express': ('يُصفّر تذكير زيت المحرك', 'resets the engine-oil reminder'),
  'full': ('يُصفّر تذكير زيت المحرك', 'resets the engine-oil reminder'),
  'major': ('يُصفّر تذكير زيت المحرك', 'resets the engine-oil reminder'),
  'tyres': ('يُصفّر تذكير الإطارات', 'resets the tyres reminder'),
  'battery': ('يُصفّر تذكير البطارية', 'resets the 12V battery reminder'),
  'ac': ('يُصفّر تذكير فلتر المقصورة', 'resets the cabin-filter reminder'),
  'ev-battery': (
    'يُصفّر تذكير بطارية السيارة الكهربائية',
    'resets the EV-battery reminder',
  ),
  'ev-check': (
    'يُصفّر تذكير بطارية السيارة الكهربائية',
    'resets the EV-battery reminder',
  ),
  'sos': (
    'يجعل الحجز طوارئ: بلا مواعيد، ومساعدة على الطريق',
    'makes the booking an emergency: no time slots, roadside by default',
  ),
};

/// The icons a service type can wear — the service-flavoured half of
/// [IconCodec], paired with the wording a founder would pick one by.
///
/// A curated subset rather than the whole codec: the codec also holds shop
/// products, notification glyphs and fulfilment icons, and offering a founder
/// "shopping bag" for a service type is offering them a mistake.
const _categoryIcons = <String, (String, String)>{
  'settings_suggest': ('صيانة عامة', 'General service'),
  'build': ('إصلاح', 'Repair'),
  'car_repair': ('ميكانيكا', 'Mechanical'),
  'tire_repair': ('إطارات', 'Tyres'),
  'battery_charging': ('بطارية', 'Battery'),
  'ac_unit': ('تكييف', 'Air conditioning'),
  'local_car_wash': ('تلميع وغسيل', 'Wash & polish'),
  'monitor_heart': ('فحص', 'Diagnostics'),
  'assignment_turned_in': ('عقود وفحص', 'Contracts & inspection'),
  'rv_hookup': ('طوارئ الطريق', 'Roadside'),
  'bolt': ('كهرباء', 'Electrical'),
  'electric_car': ('سيارة كهربائية', 'Electric car'),
  'ev_station': ('شاحن', 'Charger'),
  'cable': ('كوابل', 'Cables'),
};

/// Whether the app reads this key for behaviour rather than only showing it.
///
/// Exposed so the catalogue list can flag those rows before a founder opens
/// one — the warning inside the editor arrives a step too late to help someone
/// scanning the list to decide what to rename.
bool isBehaviouralSlug(String slug) => _behaviouralSlugs.containsKey(slug);

Future<void> showCategoryEditorSheet(
  BuildContext context, {
  ServiceCategory? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _CategoryEditorSheet(existing: existing),
);

/// Create or rewrite one service type.
///
/// The whole record is editable, including the slug — the founder owns their
/// catalogue. What the editor will not do is let the slug change *quietly*: it
/// names, in the founder's own language, what the app currently does with the
/// slug being replaced and what it will stop doing. The API keeps every
/// offering's denormalised `categorySlug` in step; what it cannot know is
/// whether the change was intended, which is the one thing a person supplies.
class _CategoryEditorSheet extends ConsumerStatefulWidget {
  const _CategoryEditorSheet({this.existing});

  final ServiceCategory? existing;

  @override
  ConsumerState<_CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<_CategoryEditorSheet> {
  late final _nameAr = TextEditingController(text: widget.existing?.name.ar);
  late final _nameEn = TextEditingController(text: widget.existing?.name.en);
  late final _slug = TextEditingController(text: widget.existing?.slug);
  late final _noteAr = TextEditingController(text: widget.existing?.note?.ar);
  late final _noteEn = TextEditingController(text: widget.existing?.note?.en);
  late String _iconKey = () {
    final current = widget.existing == null
        ? null
        : IconCodec.encode(widget.existing!.icon);
    return current != null && _categoryIcons.containsKey(current)
        ? current
        : _categoryIcons.keys.first;
  }();
  late bool _emergency = widget.existing?.emergency ?? false;
  late bool _primary = widget.existing?.primary ?? false;
  late final Set<Powertrain> _powertrains = {...?widget.existing?.powertrains};
  late ProviderCapability? _requires = widget.existing?.requires;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _slug.dispose();
    _noteAr.dispose();
    _noteEn.dispose();
    super.dispose();
  }

  String get _slugText => _slug.text.trim().toLowerCase();

  /// Mirrors the API's `ServiceCategoryRules.SlugPattern`, so a slug the server
  /// would reject is rejected here first — with the same explanation.
  static final _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  /// The behaviour this edit is about to take away, if any.
  ///
  /// Fires only on an existing category whose slug currently means something
  /// and is being changed. Creating a fresh type takes nothing away, and
  /// adopting a behavioural slug is covered by [_gaining] instead.
  (String, String)? get _losing {
    final was = widget.existing?.slug;
    if (was == null || was == _slugText) return null;
    return _behaviouralSlugs[was];
  }

  /// The behaviour this slug is about to switch on.
  (String, String)? get _gaining {
    if (widget.existing?.slug == _slugText) return null;
    return _behaviouralSlugs[_slugText];
  }

  String? _blocker(S s) {
    if (_nameAr.text.trim().isEmpty || _nameEn.text.trim().isEmpty) {
      return s.t('اكتب الاسم باللغتين.', 'Write the name in both languages.');
    }
    if (_slugText.isEmpty) {
      return s.t('المفتاح مطلوب.', 'The key is required.');
    }
    if (!_slugPattern.hasMatch(_slugText)) {
      return s.t(
        'المفتاح: حروف إنجليزية صغيرة وأرقام وشرطات فقط — مثل "ev-check".',
        'Key: lower-case letters, digits and hyphens only — like "ev-check".',
      );
    }
    // The note is optional, but half of it is the same empty-card problem the
    // badge has.
    final noteAr = _noteAr.text.trim();
    final noteEn = _noteEn.text.trim();
    if (noteAr.isEmpty != noteEn.isEmpty) {
      return s.t(
        'الملاحظة باللغتين، أو امسحهما معاً.',
        'Fill the note in both languages, or clear both.',
      );
    }
    return null;
  }

  Future<void> _submit() async {
    final s = S.of(context);
    setState(() => _saving = true);
    final noteAr = _noteAr.text.trim();
    final draft = ServiceCategoryDraft(
      slug: _slugText,
      name: L(_nameAr.text.trim(), _nameEn.text.trim()),
      icon: IconCodec.decode(_iconKey),
      note: noteAr.isEmpty ? null : L(noteAr, _noteEn.text.trim()),
      emergency: _emergency,
      primary: _primary,
      powertrains: _powertrains,
      requires: _requires,
    );
    try {
      final admin = ref.read(categoryBadgeAdminProvider);
      if (_isNew) {
        await admin.create(draft);
      } else {
        await admin.update(widget.existing!.id, draft);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error, s))));
      }
    }
  }

  /// The server's own reason where it gave one — a duplicate key is the single
  /// failure a founder can actually fix, and "couldn't save" does not say how.
  String _message(Object error, S s) =>
      error is BusinessRuleException && error.code == 'slug_taken'
      ? s.t(
          'المفتاح "$_slugText" مستخدم في نوع آخر.',
          'The key "$_slugText" is already used by another service type.',
        )
      : s.t('تعذّر الحفظ — حاول مرة أخرى.', "Couldn't save — try again.");

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final blocker = _blocker(s);
    final losing = _losing;
    final gaining = _gaining;

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
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.sm,
                AppSpacing.screenMargin,
                AppSpacing.screenMargin,
              ),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: ak.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  _isNew
                      ? s.t('نوع خدمة جديد', 'New service type')
                      : s.t('تعديل نوع الخدمة', 'Edit service type'),
                  style: context.text.screenTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.t(
                    'العائلة التي تُصنَّف تحتها خدمات الورش — "صيانة كاملة"، '
                        '"إطارات". الورشة تُسعّر خدماتها داخله؛ أنت تحدّد النوع.',
                    'The family a workshop\'s services are filed under — "Major '
                        'service", "Tyres". Workshops price services inside it; '
                        'you define the type.',
                  ),
                  style: context.text.bodySecondary.copyWith(height: 1.5),
                ),

                // ---------------------------------------------- 1. the name
                const SizedBox(height: AppSpacing.sectionGap),
                _Step(
                  step: 1,
                  title: s.t('الاسم والأيقونة', 'Name and icon'),
                  hint: s.t(
                    'اللغتان مطلوبتان — كل عميل يرى واحدة منهما فقط.',
                    'Both languages are required — each customer sees only one.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _nameAr,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم (عربي)',
                    hintText: 'صيانة كاملة',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _nameEn,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'Name (English)',
                    hintText: 'Major service',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Label(s.t('الأيقونة', 'Icon')),
                const SizedBox(height: AppSpacing.sm),
                _IconGrid(
                  selected: _iconKey,
                  onSelect: (key) => setState(() => _iconKey = key),
                ),

                // ---------------------------------------------- 2. the slug
                const SizedBox(height: AppSpacing.sectionGap),
                _Step(
                  step: 2,
                  title: s.t('المفتاح البرمجي', 'The behaviour key'),
                  hint: s.t(
                    'ليس نصاً يراه العميل — التطبيق نفسه يقرأه.',
                    'Not wording a customer sees — the app itself reads it.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _slug,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                  ],
                  decoration: InputDecoration(
                    labelText: s.t('المفتاح', 'Key'),
                    hintText: 'ev-check',
                    helperMaxLines: 3,
                    helperText: s.t(
                      'حروف صغيرة وأرقام وشرطات، ويجب أن يكون فريداً.',
                      'Lower-case letters, digits and hyphens. Must be unique.',
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (losing != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Notice(
                    danger: true,
                    icon: LucideIcons.triangleAlert,
                    title: s.t(
                      'تغيير المفتاح يوقف سلوكاً قائماً',
                      'Changing this key switches off existing behaviour',
                    ),
                    body: s.t(
                      'المفتاح الحالي "${widget.existing!.slug}" ${losing.$1}. '
                          'بعد الحفظ لن يفعل ذلك، وستتأثر الحجوزات التالية تحت '
                          'هذا النوع.',
                      'The current key "${widget.existing!.slug}" ${losing.$2}. '
                          'After saving it will not, and bookings made under '
                          'this type from now on are affected.',
                    ),
                  ),
                ],
                if (gaining != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Notice(
                    icon: LucideIcons.info,
                    title: s.t(
                      'هذا المفتاح يشغّل سلوكاً',
                      'This key switches behaviour on',
                    ),
                    body: s.t(
                      '"$_slugText" ${gaining.$1}.',
                      '"$_slugText" ${gaining.$2}.',
                    ),
                  ),
                ],

                // ------------------------------------------ 3. how it shows
                const SizedBox(height: AppSpacing.sectionGap),
                _Step(
                  step: 3,
                  title: s.t('كيف يظهر، ولمن', 'How it shows, and to whom'),
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.t('بطاقة كبيرة', 'Big package card')),
                  subtitle: Text(
                    s.t(
                      'يظهر ضمن بطاقات "صيانة السيارات" الكبيرة بدل مربّعات '
                          '"خدمات أخرى".',
                      'Appears among the large "Car service" cards instead of '
                          'the small "Other services" tiles.',
                    ),
                    style: context.text.bodySecondary,
                  ),
                  value: _primary,
                  onChanged: (v) => setState(() => _primary = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.t('خدمة طوارئ', 'Emergency service')),
                  subtitle: Text(
                    s.t(
                      'يُرسم بالأحمر في القوائم. أما جعل الحجز نفسه طوارئ '
                          'فيتطلب المفتاح "sos".',
                      'Drawn in red in the lists. Making the *booking* an '
                          'emergency needs the key "sos".',
                    ),
                    style: context.text.bodySecondary,
                  ),
                  value: _emergency,
                  onChanged: (v) => setState(() => _emergency = v),
                ),
                const SizedBox(height: AppSpacing.md),
                _Label(
                  _powertrains.isEmpty
                      ? s.t('أنواع المحرّك — الكل', 'Powertrains — every car')
                      : s.t(
                          'أنواع المحرّك — ${_powertrains.length} مختارة',
                          'Powertrains — ${_powertrains.length} selected',
                        ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.t(
                    'اتركها فارغة ليظهر النوع لكل السيارات. تحديد نوع أو أكثر '
                        'يخفيه عن أصحاب السيارات الأخرى.',
                    'Leave empty to offer this to every car. Picking one or '
                        'more hides it from owners of the others.',
                  ),
                  style: context.text.bodySecondary.copyWith(height: 1.45),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: [
                    for (final p in Powertrain.values)
                      SelectChip(
                        label: p.label.of(s),
                        icon: p.icon,
                        selected: _powertrains.contains(p),
                        onTap: () => setState(() {
                          if (!_powertrains.add(p)) _powertrains.remove(p);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ProviderCapability?>(
                  initialValue: _requires,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: s.t(
                      'يتطلب اعتماداً من الورشة',
                      'Requires a workshop certification',
                    ),
                    helperMaxLines: 3,
                    helperText: s.t(
                      'الورش التي لا تحمله لن تستطيع بيع هذا النوع.',
                      'Workshops without it cannot sell this type.',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(s.t('لا شيء', 'None')),
                    ),
                    for (final c in ProviderCapability.values)
                      DropdownMenuItem(value: c, child: Text(c.label.of(s))),
                  ],
                  onChanged: (v) => setState(() => _requires = v),
                ),

                // ---------------------------------------------- 4. the note
                const SizedBox(height: AppSpacing.sectionGap),
                _Step(
                  step: 4,
                  title: s.t(
                    'ملاحظة السعر (اختيارية)',
                    'Price note (optional)',
                  ),
                  hint: s.t(
                    'تظهر على البطاقة حين لا يوجد سعر معلن.',
                    'Shown on the card when there is no published price.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _noteAr,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'الملاحظة (عربي)',
                    hintText: 'السعر بعد الفحص',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _noteEn,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'Note (English)',
                    hintText: 'quote after inspection',
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                // ------------------------------------------------- actions
                const SizedBox(height: AppSpacing.sectionGap),
                if (blocker != null) ...[
                  _Notice(icon: LucideIcons.info, body: blocker),
                  const SizedBox(height: AppSpacing.sm),
                ],
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: blocker == null && !_saving ? _submit : null,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isNew
                                ? s.t('إضافة النوع', 'Add service type')
                                : s.t('حفظ التعديل', 'Save changes'),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(s.t('إلغاء', 'Cancel')),
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

/// A numbered heading inside the editor — the same shape as the announcement
/// editor's, so the two founder forms read as one panel.
class _Step extends StatelessWidget {
  const _Step({required this.step, required this.title, this.hint});

  final int step;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: ak.primary, shape: BoxShape.circle),
          child: Text(
            '$step',
            style: context.text.labelStrong.copyWith(color: ak.onPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.cardTitle),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: context.text.bodySecondary.copyWith(height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.bodySecondary.copyWith(
      fontWeight: FontWeight.w700,
      color: AkColors.of(context).ink,
    ),
  );
}

/// An inline explainer. Amber for the ordinary kind, red for the one saying a
/// save is about to switch a behaviour off — those are not the same weight of
/// message and should not look like it.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.body,
    this.title,
    this.danger = false,
  });

  final IconData icon;
  final String body;
  final String? title;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final bg = danger ? ak.dangerSoft : ak.amberBgSoft;
    final border = danger ? ak.dangerBorder : ak.amberBorder;
    final fg = danger ? ak.dangerText : ak.amberDeep;
    final strong = danger ? ak.dangerText : ak.amberText;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: strong),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: context.text.bodySecondary.copyWith(
                      fontWeight: FontWeight.w700,
                      color: strong,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  body,
                  style: context.text.bodySecondary.copyWith(
                    color: fg,
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

/// The service icons, as icons.
class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in _categoryIcons.entries)
          _IconChoice(
            icon: IconCodec.decode(entry.key),
            label: s.t(entry.value.$1, entry.value.$2),
            active: entry.key == selected,
            ak: ak,
            onTap: () => onSelect(entry.key),
          ),
      ],
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.label,
    required this.active,
    required this.ak,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final AkColors ak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 94,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm + 2,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: active ? ak.primary : ak.surface,
        border: Border.all(color: active ? ak.primary : ak.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: active ? ak.onPrimary : ak.ink),
          const SizedBox(height: AppSpacing.xs + 1),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySecondary.copyWith(
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: active ? ak.onPrimary : ak.inkSub,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Confirms removing a service type, and refuses early when offerings are still
/// filed under it.
///
/// The count comes from the warm catalogue rather than from the server's
/// refusal, so the founder is told *before* pressing delete rather than after.
/// The API still enforces it; this only saves a round trip that could come back
/// nothing but "no".
Future<void> confirmDeleteCategory(
  BuildContext context,
  WidgetRef ref,
  ServiceCategory category,
) async {
  final s = S.of(context);
  final admin = ref.read(categoryBadgeAdminProvider);
  final inUse = admin.offeringCount(category.id);
  final name = category.name.of(s).replaceAll('\n', ' ');

  if (inUse > 0) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('لا يمكن حذف "$name"', 'Cannot delete "$name"')),
        content: Text(
          s.t(
            'ما زالت $inUse خدمة مُسعّرة مصنّفة تحت هذا النوع. انقلها إلى نوع '
                'آخر أو احذفها من الورش أولاً — حذف النوع الآن يترك تلك الخدمات '
                'بلا تصنيف.',
            '$inUse priced service(s) are still filed under this type. Move '
                'them to another type, or remove them from the workshops first '
                '— deleting it now would leave those services uncategorised.',
          ),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(s.t('حسناً', 'OK')),
          ),
        ],
      ),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.t('حذف "$name"؟', 'Delete "$name"?')),
      content: Text(
        s.t(
          'سيختفي النوع من الرئيسية وصفحة الخدمات فوراً، ولا يمكن التراجع.',
          'The type disappears from Home and Services immediately, and this '
              'cannot be undone.',
        ),
        style: const TextStyle(height: 1.5),
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
    await admin.delete(category.id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('تعذّر الحذف.', 'Could not delete.'))),
      );
    }
  }
}
