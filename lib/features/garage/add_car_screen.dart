import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/oman_plate_input.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// Add / edit a car — everything on ONE page. Each detail opens a popup
/// picker: make (logo grid), model, trim, year, colour, plate with 1–2
/// letters, and governorate → wilayat cascading selection.
///
/// Pass [carId] to edit a saved car instead of registering a new one. The
/// two modes share this screen deliberately: the fields, the validation and
/// the pickers are identical, and a separate editor would drift out of step
/// the first time a field is added.
class AddCarScreen extends ConsumerStatefulWidget {
  const AddCarScreen({super.key, this.carId});

  /// Id of the car being edited, or null when registering a new one.
  final String? carId;

  bool get isEditing => carId != null;

  @override
  ConsumerState<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends ConsumerState<AddCarScreen> {
  VehicleCatalog get _vehicles => ref.read(vehicleCatalogProvider);
  LocationCatalog get _locations => ref.read(locationCatalogProvider);
  SpecCatalog get _specs => ref.read(specCatalogProvider);

  CarMake? _make;
  String? _model;
  String? _trim;
  int? _year;
  String? _color;
  Powertrain? _powertrain;
  String? _governorate;
  String? _wilayat;

  final _nickname = TextEditingController();
  final _plateNumber = TextEditingController();
  final _odometer = TextEditingController();
  String _plateLetters = 'A';

  /// The car as it was when the editor opened, so Save can tell whether
  /// anything actually changed.
  Car? _original;

  @override
  void initState() {
    super.initState();
    final id = widget.carId;
    if (id == null) return;
    final car = ref.read(carByIdProvider(id));
    if (car == null) return;
    _original = car;
    _make = _vehicles.makeNamed(car.make) ?? CarMake(car.make, [car.model]);
    _model = car.model;
    _trim = car.trim;
    _year = car.year;
    _color = car.color;
    _powertrain = car.powertrain;
    _governorate = car.governorate;
    _wilayat = car.wilayat;
    _nickname.text = car.nickname ?? '';
    _odometer.text = car.odometerKm?.toString() ?? '';
    final (number, letters) = OmanPlateInput.parse(car.plate);
    _plateNumber.text = number;
    _plateLetters = letters;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _plateNumber.dispose();
    _odometer.dispose();
    super.dispose();
  }

  /// Only make, model and year are required — the rest can be filled in
  /// later from the garage, so registering a car stays a 30-second job.
  bool get _canSave => _make != null && _model != null && _year != null;

  String? get _plate {
    final number = _plateNumber.text.trim();
    return number.isEmpty ? null : '$number $_plateLetters';
  }

  Car _compose(String id) => Car(
        id: id,
        make: _make!.name,
        model: _model!,
        year: _year!,
        nickname: _nickname.text.trim().isEmpty ? null : _nickname.text.trim(),
        trim: _trim,
        color: _color,
        // Optional, and never guessed from the model name: the app changes
        // what it shows for an electric car, so it may only act on what the
        // owner actually told it.
        powertrain: _powertrain,
        plate: _plate,
        odometerKm: int.tryParse(_odometer.text.trim()),
        governorate: _governorate,
        wilayat: _wilayat,
        // serviceDueKm stays whatever the record already had: the garage
        // computes what is due from real odometer + service history, it is
        // not a number this form gets to invent.
        serviceDueKm: _original?.serviceDueKm,
      );

  void _save() {
    if (!_canSave) return;
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.heavyImpact();

    if (widget.isEditing) {
      final updated = _compose(widget.carId!);
      ref.read(garageProvider.notifier).update(updated);
      _syncOdometer(updated);
      context.pop(true);
      messenger.showSnackBar(SnackBar(
        content: Text(s.t('تم تحديث ${updated.displayName}',
            '${updated.displayName} updated')),
      ));
      return;
    }

    final wasEmpty = ref.read(garageProvider).isEmpty;
    final car = _compose(DateTime.now().millisecondsSinceEpoch.toString());
    ref.read(garageProvider.notifier).add(car);
    _syncOdometer(car);
    // Only the first car sets the service region — registering a second car
    // used to silently move the region the whole app searches in.
    if (wasEmpty && _governorate != null) {
      ref.read(regionProvider.notifier).state = _governorate!;
    }
    ref.read(authProvider.notifier).markStartChoiceMade();
    // Pops with `true` so the caller knows a car was actually saved. The
    // start-choice screen needs that: it pushed this screen and is still
    // underneath, so a bare pop would drop the user back onto the "how do
    // you want to start?" question they just answered — which read as the
    // Finish button doing nothing at all. Deep-linked straight to /add-car
    // (nothing to pop) → land on the app's first tab instead.
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(AppFlags.startLocation);
    }
    messenger.showSnackBar(SnackBar(
      content: Text(s.t('تمت إضافة ${car.label} إلى مرآبك',
          '${car.label} added to your garage')),
    ));
  }

  /// Puts the mileage typed on this form into the car's maintenance book too.
  ///
  /// The form and the maintenance page must never be able to show two
  /// different readings for the same car, and the book is what every countdown
  /// on that car is measured from — a reading entered here has to reach it.
  void _syncOdometer(Car car) {
    final km = car.odometerKm;
    if (km == null || km <= 0) return;
    if (km == ref.read(maintenanceBookProvider(car.id)).currentOdometerKm) {
      return;
    }
    ref.read(garageProvider.notifier).setOdometer(car.id, km);
  }

  Future<void> _confirmDelete() async {
    final car = _original;
    if (car == null) return;
    final s = S.of(context);
    final ak = AkColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.t('حذف السيارة؟', 'Remove car?')),
        content: Text(s.t('سيتم حذف ${car.displayName} من مرآبك.',
            '${car.displayName} will be removed from your garage.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ak.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.t('حذف', 'Remove')),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    HapticFeedback.mediumImpact();
    ref.read(garageProvider.notifier).remove(car.id);
    context.pop();
  }

  /// -------------------------------------------------------------- popups

  Future<void> _pickMake() async {
    final ak = AkColors.of(context);
    final make = await _showPopup<CarMake>(
      title: S.of(context).t('اختر الشركة المصنعة', 'Pick a make'),
      builder: (context, query) {
        final makes = _vehicles.makes
            .where((m) => m.name.toLowerCase().contains(query))
            .toList();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 0.86,
          ),
          itemCount: makes.length,
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => Navigator.pop(context, makes[i]),
            child: Container(
              decoration: BoxDecoration(
                color: ak.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _make == makes[i] ? ak.primary : ak.border,
                  width: _make == makes[i] ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MakeLogo(make: makes[i], size: 36),
                  const SizedBox(height: 6),
                  Text(
                    makes[i].name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      searchable: true,
    );
    if (make != null) {
      setState(() {
        _make = make;
        _model = null;
        _trim = null;
      });
    }
  }

  Future<void> _pickModel() async {
    if (_make == null) return;
    final model = await _showPopup<String>(
      title: S.of(context).t(
          'اختر الموديل — ${_make!.name}', 'Choose model — ${_make!.name}'),
      searchable: true,
      builder: (context, query) {
        final models = _make!.models
            .where((m) => m.toLowerCase().contains(query))
            .toList();
        return _OptionList(
          options: models,
          selected: _model,
          icon: LucideIcons.car,
        );
      },
    );
    if (model != null) {
      setState(() {
        _model = model;
        _trim = null; // cascade reset
      });
    }
  }

  Future<void> _pickTrim() async {
    if (_model == null) return;
    final trims = _vehicles.trimsFor(_model!);
    if (trims.isEmpty) return;
    final trim = await _showPopup<String>(
      title: S.of(context).t('الفئة — $_model', 'Trim — $_model'),
      builder: (context, _) => _OptionList(
        options: trims,
        selected: _trim,
        icon: LucideIcons.slidersHorizontal,
      ),
    );
    if (trim != null) setState(() => _trim = trim);
  }

  Future<void> _pickYear() async {
    final year = await _showPopup<int>(
      title: S.of(context).t('سنة الصنع', 'Made year'),
      builder: (context, _) => _OptionList(
        options: [for (final y in _vehicles.years) '$y'],
        selected: '${_year ?? ''}',
        icon: LucideIcons.calendar,
        onPick: (v) => Navigator.pop(context, int.parse(v)),
      ),
    );
    if (year != null) setState(() => _year = year);
  }

  Future<void> _pickColor() async {
    final s = S.of(context);
    final color = await _showPopup<String>(
      title: s.t('اللون', 'Colour'),
      builder: (context, _) => _OptionList(
        options: [for (final c in _specs.colors) c.value],
        selected: _color,
        icon: LucideIcons.palette,
        labelOf: (c) => _specs.localized(c, s.isAr),
        swatchOf: _specs.swatchOf,
      ),
    );
    if (color != null) setState(() => _color = color);
  }

  Future<void> _pickGovernorate() async {
    final s = S.of(context);
    final gov = await _showPopup<String>(
      title: s.t('المحافظة', 'Governorate'),
      searchable: true,
      builder: (context, query) => _OptionList(
        options: _locations.governorates.keys
            .where((g) =>
                g.toLowerCase().contains(query) ||
                _locations.localized(g, true).contains(query))
            .toList(),
        selected: _governorate,
        icon: LucideIcons.map,
        labelOf: (g) => _locations.localized(g, s.isAr),
      ),
    );
    if (gov != null) {
      setState(() {
        _governorate = gov;
        _wilayat = null; // cascade reset
      });
    }
  }

  Future<void> _pickWilayat() async {
    if (_governorate == null) return;
    final s = S.of(context);
    final wilayat = await _showPopup<String>(
      title: s.t('الولاية — ${_locations.localized(_governorate!, s.isAr)}',
          'Wilayat — $_governorate'),
      searchable: true,
      builder: (context, query) => _OptionList(
        options: _locations
            .wilayatsOf(_governorate!)
            .where((w) =>
                w.toLowerCase().contains(query) ||
                _locations.localized(w, true).contains(query))
            .toList(),
        selected: _wilayat,
        icon: LucideIcons.mapPin,
        labelOf: (w) => _locations.localized(w, s.isAr),
      ),
    );
    if (wilayat != null) setState(() => _wilayat = wilayat);
  }

  Future<void> _pickPlateLetters() async {
    final letters = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => PlateLettersPicker(initial: _plateLetters),
    );
    if (letters != null && letters.isNotEmpty) {
      setState(() => _plateLetters = letters);
    }
  }

  Future<T?> _showPopup<T>({
    required String title,
    required Widget Function(BuildContext context, String query) builder,
    bool searchable = false,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PopupScaffold(
        title: title,
        searchable: searchable,
        builder: builder,
      ),
    );
  }

  /// --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final trims = _model == null ? const <String>[] : _vehicles.trimsFor(_model!);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(
        title: Text(widget.isEditing
            ? s.t('تعديل السيارة', 'Edit car')
            : s.t('أضف سيارتك', 'Add your car')),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: s.t('حذف', 'Remove'),
              icon: Icon(LucideIcons.trash2, color: ak.danger),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  Text(
                    widget.isEditing
                        ? s.t('حدّث أي تفصيل — يُحفظ على سيارتك مباشرة.',
                            'Update any detail — it saves straight to your car.')
                        : s.t('اضغط على كل حقل للاختيار من القائمة.',
                            'Tap each field to choose from the list.'),
                    style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                  ),
                  const SizedBox(height: 14),
                  _SectionLabel(s.t('السيارة', 'The car')),
                  _PickerField(
                    icon: LucideIcons.factory,
                    label: s.t('الشركة المصنعة', 'Make'),
                    value: _make?.name,
                    onTap: _pickMake,
                  ),
                  _PickerField(
                    icon: LucideIcons.car,
                    label: s.t('الموديل', 'Model'),
                    value: _model,
                    hint: _make == null
                        ? s.t('اختر الشركة أولاً', 'Select make first')
                        : null,
                    enabled: _make != null,
                    onTap: _pickModel,
                  ),
                  // Live preview — the car photo changes with the
                  // selected make & model.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: (_make != null && _model != null)
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Column(
                                children: [
                                  CarImage(
                                      make: _make!.name,
                                      model: _model!,
                                      color: _color,
                                      height: 110),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_make!.name} $_model',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: ak.inkSub),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (trims.isNotEmpty)
                    _PickerField(
                      icon: LucideIcons.slidersHorizontal,
                      label: s.t('الفئة', 'Trim'),
                      value: _trim,
                      optional: true,
                      onTap: _pickTrim,
                    ),
                  _PickerField(
                    icon: LucideIcons.calendar,
                    label: s.t('سنة الصنع', 'Made year'),
                    value: _year == null ? null : '$_year',
                    onTap: _pickYear,
                  ),
                  _PickerField(
                    icon: LucideIcons.palette,
                    label: s.t('اللون', 'Colour'),
                    value: _color == null
                        ? null
                        : _specs.localized(_color!, s.isAr),
                    swatch: _color == null ? null : _specs.swatchOf(_color!),
                    optional: true,
                    onTap: _pickColor,
                  ),
                  // One tap, five options, skippable — the point of asking is
                  // that an electric car gets EV maintenance and EV services
                  // instead of oil-change reminders, and that is worth exactly
                  // one tap of the owner's time.
                  _PowertrainField(
                    selected: _powertrain,
                    onSelected: (p) => setState(
                        () => _powertrain = _powertrain == p ? null : p),
                  ),
                  _TextField(
                    icon: LucideIcons.idCard,
                    label: s.t('اسم مختصر', 'Nickname'),
                    hint: s.t('مثال: سيارة الوالد', 'e.g. Dad\'s car'),
                    controller: _nickname,
                    optional: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  _SectionLabel(s.t('الاستخدام والموقع', 'Usage & location')),
                  _TextField(
                    icon: LucideIcons.gauge,
                    label: s.t('الممشى الحالي (كم)', 'Current mileage (km)'),
                    hint: '128450',
                    controller: _odometer,
                    optional: true,
                    numeric: true,
                    helper: s.t('يُستخدم لحساب مواعيد الصيانة القادمة.',
                        'Used to work out when your next service is due.'),
                    onChanged: (_) => setState(() {}),
                  ),
                  _PickerField(
                    icon: LucideIcons.map,
                    label: s.t('المحافظة', 'Governorate'),
                    value: _governorate == null
                        ? null
                        : _locations.localized(_governorate!, s.isAr),
                    optional: true,
                    onTap: _pickGovernorate,
                  ),
                  _PickerField(
                    icon: LucideIcons.mapPin,
                    label: s.t('الولاية', 'Wilayat'),
                    value: _wilayat == null
                        ? null
                        : _locations.localized(_wilayat!, s.isAr),
                    hint: _governorate == null
                        ? s.t('اختر المحافظة أولاً', 'Select governorate first')
                        : null,
                    enabled: _governorate != null,
                    optional: true,
                    onTap: _pickWilayat,
                  ),
                  const SizedBox(height: 10),
                  Text(s.t('رقم اللوحة العمانية', 'Oman plate number'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    s.t('اختياري الآن — مطلوب عند حجز خدمة. الحروف قد تكون حرفاً أو حرفين.',
                        'Optional now — required when booking a service. Letters can be one or two.'),
                    style: TextStyle(fontSize: 11.5, color: ak.inkFaint),
                  ),
                  const SizedBox(height: 10),
                  OmanPlateInput(
                    numberController: _plateNumber,
                    letters: _plateLetters,
                    onLettersTap: _pickPlateLetters,
                  ),
                  if (_canSave) ...[
                    const SizedBox(height: 16),
                    Entrance(
                      child: AppCard(
                        color: ak.successSoft,
                        border: Border.all(color: ak.successSoft),
                        child: Row(
                          children: [
                            Icon(LucideIcons.circleCheckBig,
                                color: ak.success, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _summary(s),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: ak.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(_saveLabel(s)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _saveLabel(S s) {
    if (!_canSave) {
      return s.t('أكمل التفاصيل أعلاه', 'Complete the details above');
    }
    if (widget.isEditing) return s.t('حفظ التعديلات', 'Save changes');
    return s.t('حفظ ${_make!.name} $_model', 'Save ${_make!.name} $_model');
  }

  /// One-line recap of everything filled in so far.
  String _summary(S s) {
    final parts = <String>[
      '${_make!.name} $_model${_trim == null ? '' : ' $_trim'} $_year',
      if (_color != null) _specs.localized(_color!, s.isAr),
      if (_powertrain != null) _powertrain!.label.of(s),
      if (_wilayat != null) _locations.localized(_wilayat!, s.isAr),
      ?_plate,
    ];
    return parts.join(s.t(' · ', ' · '));
  }
}

/// Powertrain row: a label, a one-line explanation of what changes, and five
/// chips. Deliberately not another popup picker — it is the one field on this
/// form whose answer changes the rest of the app, so it has to be cheaper to
/// answer than to skip.
class _PowertrainField extends StatelessWidget {
  const _PowertrainField({required this.selected, required this.onSelected});

  final Powertrain? selected;
  final ValueChanged<Powertrain> onSelected;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(selected?.icon ?? LucideIcons.fuel,
                  size: 17, color: ak.inkSub),
              const SizedBox(width: 8),
              Flexible(
                child: Text(s.t('نوع الوقود / المحرك', 'Fuel / powertrain'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Text(s.t('(اختياري)', '(optional)'),
                  style: TextStyle(fontSize: 11, color: ak.inkFaint)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.t('يحدد ما نعرضه لك: صيانة وخدمات وقطع سيارتك.',
                'Sets what we show you: maintenance, services and parts for '
                    'your car.'),
            style: TextStyle(fontSize: 11.5, color: ak.inkFaint),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final p in Powertrain.values)
                SelectChip(
                  label: p.label.of(s),
                  icon: p.icon,
                  selected: selected == p,
                  onTap: () => onSelected(p),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small uppercase group label separating the form's sections.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: ak.inkFaint,
        ),
      ),
    );
  }
}

/// Tappable field row that opens a popup picker.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.hint,
    this.swatch,
    this.enabled = true,
    this.optional = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? hint;

  /// Paint chip shown instead of the icon once a colour is picked.
  final Color? swatch;
  final bool enabled;

  /// Marks the field as skippable, so an empty one does not read as an error.
  final bool optional;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final filled = value != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: ak.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled ? ak.primary : ak.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                if (swatch != null)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(color: ak.border),
                    ),
                  )
                else
                  Icon(icon,
                      size: 18, color: filled ? ak.primary : ak.inkFaint),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: filled ? 10.5 : 13,
                                color: ak.inkSub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (optional && !filled) ...[
                            const SizedBox(width: 6),
                            Text(
                              s.t('اختياري', 'optional'),
                              style: TextStyle(
                                  fontSize: 10.5, color: ak.inkFaint),
                            ),
                          ],
                        ],
                      ),
                      if (filled)
                        Text(
                          value!,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700),
                        )
                      else if (hint != null)
                        Text(
                          hint!,
                          style: TextStyle(fontSize: 11, color: ak.inkFaint),
                        ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronDown, color: ak.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Free-text field styled to match [_PickerField] — used for the details the
/// user types rather than picks (nickname, odometer).
class _TextField extends StatelessWidget {
  const _TextField({
    required this.icon,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.numeric = false,
    this.optional = false,
    this.onChanged,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final bool numeric;
  final bool optional;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final filled = controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: BoxDecoration(
          color: ak.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: filled ? ak.primary : ak.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: filled ? ak.primary : ak.inkFaint),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: ak.inkSub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (optional && !filled) ...[
                            const SizedBox(width: 6),
                            Text(
                              s.t('اختياري', 'optional'),
                              style: TextStyle(
                                  fontSize: 10.5, color: ak.inkFaint),
                            ),
                          ],
                        ],
                      ),
                      TextField(
                        controller: controller,
                        onChanged: onChanged,
                        keyboardType:
                            numeric ? TextInputType.number : TextInputType.text,
                        inputFormatters: numeric
                            ? [FilteringTextInputFormatter.digitsOnly]
                            : null,
                        style: numeric
                            ? AppTheme.numeric(size: 14, color: ak.ink)
                            : const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          hintText: hint,
                          hintStyle:
                              TextStyle(fontSize: 13, color: ak.inkFaint),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (helper != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  helper!,
                  style: TextStyle(fontSize: 10.5, color: ak.inkFaint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet scaffold for popup pickers (title + optional search).
class _PopupScaffold extends StatefulWidget {
  const _PopupScaffold({
    required this.title,
    required this.builder,
    required this.searchable,
  });

  final String title;
  final Widget Function(BuildContext context, String query) builder;
  final bool searchable;

  @override
  State<_PopupScaffold> createState() => _PopupScaffoldState();
}

class _PopupScaffoldState extends State<_PopupScaffold> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (widget.searchable) ...[
                TextField(
                  autofocus: false,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: S.of(context).t('ابحث…', 'Search…'),
                    prefixIcon: const Icon(LucideIcons.search),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: widget.builder(context, _query),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple option list used inside popups; pops the tapped value.
class _OptionList extends StatelessWidget {
  const _OptionList({
    required this.options,
    required this.icon,
    this.selected,
    this.onPick,
    this.labelOf,
    this.swatchOf,
  });

  final List<String> options;
  final IconData icon;
  final String? selected;
  final void Function(String value)? onPick;

  /// Display label for an option (defaults to the option itself).
  final String Function(String value)? labelOf;

  /// Paint chip for an option, shown instead of [icon] (colour picker).
  final Color Function(String value)? swatchOf;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      children: [
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (onPick != null) {
                  onPick!(o);
                } else {
                  Navigator.pop(context, o);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: ak.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: selected == o ? ak.primary : ak.border,
                    width: selected == o ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (swatchOf != null)
                      Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: swatchOf!(o),
                          shape: BoxShape.circle,
                          border: Border.all(color: ak.border),
                        ),
                      )
                    else
                      Icon(icon,
                          size: 17,
                          color: selected == o ? ak.primary : ak.inkFaint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(labelOf?.call(o) ?? o,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ),
                    if (selected == o)
                      Icon(LucideIcons.check, size: 18, color: ak.primary),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
