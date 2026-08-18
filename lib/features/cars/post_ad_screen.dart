import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/guid.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/rial_symbol.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// Post a car ad — collects the full set of details the cars filter facets
/// on (make/model/sub-model, condition, body, year, specs, transmission,
/// drive line, fuel, engine, cylinders, doors/seats, warranty, seller type,
/// colors, region/city, deal type, mileage, price) plus a 5–15 photo
/// gallery. Publishes into the gallery feed.
///
/// Every option list comes from [CarSpecs] — the same catalog the filter
/// renders — so a seller can never publish a value buyers cannot filter by.
class PostAdScreen extends ConsumerStatefulWidget {
  const PostAdScreen({super.key});

  @override
  ConsumerState<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends ConsumerState<PostAdScreen> {
  /// Reference catalogs, warmed at bootstrap.
  SpecCatalog get _specs => ref.read(specCatalogProvider);
  VehicleCatalog get _vehicles => ref.read(vehicleCatalogProvider);
  LocationCatalog get _locations => ref.read(locationCatalogProvider);

  // ---- photos (5 min / 15 max) ------------------------------------------
  static const int _minPhotos = 5;
  static const int _maxPhotos = 15;
  // Placeholder tints standing in for real uploads (wired to storage in
  // Phase 4). Each "added photo" cycles through this palette.
  static const _photoTints = [
    Color(0xFF41536B), Color(0xFF7B2D3B), Color(0xFF3F4756),
    Color(0xFF64748B), Color(0xFF8A5560), Color(0xFF4E6151),
    Color(0xFF6B4A2F), Color(0xFF41536B), Color(0xFF7C8899),
  ];
  final List<Color> _photos = [];

  // ---- vehicle ----------------------------------------------------------
  CarMake? _make;
  String? _model;
  String? _trim;
  int? _year;

  // ---- specifications (mirror the filter facets) ------------------------
  String? _condition;
  String? _bodyType;
  String? _regionalSpec;
  String? _transmission;
  String? _drivetrain;
  String? _fuel;
  int? _cylinders;
  int? _doors;
  int? _seats;
  bool _hasWarranty = false;
  String? _sellerType;

  // ---- colors -----------------------------------------------------------
  String? _exteriorColor;
  Color? _exteriorSwatch;
  String? _interiorColor;
  Color? _interiorSwatch;

  // ---- location & deal --------------------------------------------------
  String? _governorate;
  String? _wilayat;
  String? _dealType;
  bool _askForPrice = false;

  final _price = TextEditingController();
  final _mileage = TextEditingController();
  final _engine = TextEditingController();
  final _description = TextEditingController();

  /// Engine displacement in litres; a pure EV has none.
  double? get _engineLitres {
    if (_fuel == 'Electric') return 0.0;
    final text = _engine.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0 || value > 12) return null;
    return value;
  }

  @override
  void dispose() {
    _price.dispose();
    _mileage.dispose();
    _engine.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _canPublish =>
      _photos.length >= _minPhotos &&
      _make != null &&
      _model != null &&
      _year != null &&
      _condition != null &&
      _bodyType != null &&
      _regionalSpec != null &&
      _transmission != null &&
      _drivetrain != null &&
      _fuel != null &&
      _cylinders != null &&
      _engineLitres != null &&
      _doors != null &&
      _seats != null &&
      _sellerType != null &&
      _exteriorColor != null &&
      _interiorColor != null &&
      _governorate != null &&
      _wilayat != null &&
      _dealType != null &&
      _mileage.text.trim().isNotEmpty &&
      (_askForPrice || _price.text.trim().isNotEmpty);

  IconData _iconForBody(String body) => switch (body) {
        'SUV' => LucideIcons.bus,
        'Pickup' => LucideIcons.truck,
        _ => LucideIcons.carFront,
      };

  Future<void> _publish() async {
    if (!_canPublish) return;
    final profile = ref.read(authProvider).profile;
    final ad = GalleryListing(
      id: newGuid(),
      make: _make!.name,
      model: _model!,
      trim: _trim ?? '',
      year: _year!,
      price: _askForPrice ? null : double.tryParse(_price.text.trim()),
      mileage: _mileage.text.trim().isEmpty ? '—' : _mileage.text.trim(),
      bodyType: _bodyType!,
      condition: _condition!,
      cylinders: _cylinders!,
      engineLitres: _engineLitres!,
      transmission: _transmission!,
      fuel: _fuel!,
      drivetrain: _drivetrain!,
      doors: _doors!,
      seats: _seats!,
      regionalSpec: _regionalSpec!,
      hasWarranty: _hasWarranty,
      sellerType: _sellerType!,
      keys: 2,
      exteriorColor: _exteriorColor!,
      exteriorSwatch: _exteriorSwatch!,
      interiorColor: _interiorColor!,
      interiorSwatch: _interiorSwatch!,
      region: '$_wilayat, $_governorate',
      postedMinutesAgo: 0,
      dealType: _dealType!,
      photoCount: _photos.length,
      icon: _iconForBody(_bodyType!),
      tint: _photos.first,
      sellerName: profile?.name ?? 'You',
      sellerJoined: 'today',
      sellerAds: 1,
      sellerFollowers: 0,
      description: _description.text.trim().isEmpty
          ? 'No description provided.'
          : _description.text.trim(),
    );
    ref.read(myAdsProvider.notifier).add(ad);
    ref.read(notificationsProvider.notifier).adopt(
          await ref.read(notificationRepositoryProvider).notifyAdPublished(ad),
        );
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    context.pushReplacement('/cars/listing/${ad.id}');
  }

  // ---------------------------------------------------------------- pickers
  Future<T?> _pickFromList<T>(
      String title, List<T> options, String Function(T) label,
      {Widget Function(T)? leading}) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () => Navigator.pop(context, options[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            if (leading != null) ...[
                              leading(options[i]),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Text(label(options[i]),
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Picks a value from the shared [CarSpecs] catalog.
  Future<T?> _pickSpec<T>(String title, List<SpecOption<T>> options) async {
    final s = S.of(context);
    final chosen = await _pickFromList<SpecOption<T>>(
        title, options, (o) => s.t(o.ar, o.en));
    return chosen?.value;
  }

  Future<void> _pickColor(String title, bool exterior) async {
    final s = S.of(context);
    final chosen = await _pickFromList<SpecOption<String>>(
      title,
      _specs.colors,
      (o) => s.t(o.ar, o.en),
      leading: (o) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _specs.swatchOf(o.value),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
    if (chosen == null) return;
    setState(() {
      if (exterior) {
        _exteriorColor = chosen.value;
        _exteriorSwatch = _specs.swatchOf(chosen.value);
      } else {
        _interiorColor = chosen.value;
        _interiorSwatch = _specs.swatchOf(chosen.value);
      }
    });
  }

  // ---------------------------------------------------------------- widgets
  Widget _field(IconData icon, String label, String? value, VoidCallback onTap,
      {bool enabled = true, String? hint, Color? swatch}) {
    final filled = value != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: filled ? AppColors.brand : AppColors.border,
                  width: 1.5),
            ),
            child: Row(
              children: [
                if (swatch != null)
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(icon,
                        size: 18,
                        color: filled ? AppColors.brand : AppColors.ink3),
                  ),
                Expanded(
                  child: Text(
                    value ?? hint ?? label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          filled ? FontWeight.w700 : FontWeight.w500,
                      color: filled ? AppColors.ink : AppColors.ink3,
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronDown,
                    color: Color(0xFFD8D1C4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink2,
                letterSpacing: 0.2)),
      );

  // ---------------------------------------------------------------- photos
  Widget _photosSection() {
    final s = S.of(context);
    final enough = _photos.length >= _minPhotos;
    final canAdd = _photos.length < _maxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  s.t('الصور (${_photos.length}/$_maxPhotos)',
                      'Photos (${_photos.length}/$_maxPhotos)'),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink2)),
            ),
            Text(
              enough
                  ? s.t('جاهز', 'Ready')
                  : s.t('أضف ${_minPhotos - _photos.length} صور أخرى',
                      'Add ${_minPhotos - _photos.length} more'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: enough ? AppColors.good : AppColors.ink3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          children: [
            if (canAdd)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _photos
                      .add(_photoTints[_photos.length % _photoTints.length]));
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: enough ? AppColors.border : AppColors.brand,
                        width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.camera,
                          size: 22, color: AppColors.brand),
                      const SizedBox(height: 5),
                      Text(s.t('أضف صورة', 'Add photo'),
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.ink3,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            for (var i = 0; i < _photos.length; i++)
              _photoTile(i),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _photos.isEmpty
              ? s.t('أضف $_minPhotos صور على الأقل (حتى $_maxPhotos). يتم ربط الرفع بالتخزين في المرحلة 4.',
                  'Add at least $_minPhotos photos (up to $_maxPhotos). '
                  'Uploads connect to storage in Phase 4.')
              : s.t('تُستخدم الصورة الأولى كصورة الغلاف.',
                  'First photo is used as the cover.'),
          style: const TextStyle(fontSize: 11, color: AppColors.ink3),
        ),
      ],
    );
  }

  Widget _photoTile(int i) {
    final tint = _photos[i];
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tint, Color.lerp(tint, Colors.black, 0.28)!],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Icon(LucideIcons.carFront,
                size: 26, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ),
        if (i == 0)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(S.of(context).t('الغلاف', 'Cover'),
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _photos.removeAt(i));
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.x,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String? spec(String? value) =>
        value == null ? null : _specs.localized(value, s.isAr);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('انشر إعلان سيارة', 'Post a car ad'))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  _photosSection(),
                  const SizedBox(height: 14),
                  // ---------------------------------------------- vehicle
                  _sectionTitle(s.t('السيارة', 'VEHICLE')),
                  _field(
                    LucideIcons.factory,
                    s.t('الشركة المصنعة', 'Make'),
                    _make?.name,
                    () async {
                      final m = await _pickFromList(
                          s.t('اختر الشركة المصنعة', 'Pick a make'),
                          _vehicles.makes,
                          (m) => m.name);
                      if (m != null) {
                        setState(() {
                          _make = m;
                          _model = null;
                          _trim = null;
                        });
                      }
                    },
                  ),
                  _field(
                    LucideIcons.car,
                    s.t('الموديل', 'Model'),
                    _model,
                    () async {
                      final m = await _pickFromList(
                          s.t('اختر الموديل', 'Choose model'),
                          _make?.models ?? const <String>[],
                          (m) => m);
                      if (m != null) {
                        setState(() {
                          _model = m;
                          _trim = null;
                        });
                      }
                    },
                    enabled: _make != null,
                    hint: _make == null
                        ? s.t('اختر الشركة أولاً', 'Select make first')
                        : s.t('الموديل', 'Model'),
                  ),
                  _field(
                    LucideIcons.layers,
                    s.t('الفئة الفرعية', 'Sub-model'),
                    _trim,
                    () async {
                      final trims = _vehicles.trimsFor(_model ?? '');
                      final t = await _pickFromList(
                          s.t('الفئة الفرعية — $_model',
                              'Sub-model — $_model'),
                          trims,
                          (t) => t);
                      if (t != null) setState(() => _trim = t);
                    },
                    enabled: _model != null &&
                        _vehicles.trimsFor(_model ?? '').isNotEmpty,
                    hint: _model == null
                        ? s.t('اختر الموديل أولاً', 'Select model first')
                        : (_vehicles.trimsFor(_model!).isEmpty
                            ? s.t('لا توجد فئات فرعية', 'No sub-models')
                            : s.t('اختياري', 'Optional')),
                  ),
                  _field(
                    LucideIcons.calendar,
                    s.t('سنة الصنع', 'Year'),
                    _year == null ? null : '$_year',
                    () async {
                      final y = await _pickFromList(
                          s.t('سنة الصنع', 'Made year'),
                          _vehicles.years,
                          (y) => '$y');
                      if (y != null) setState(() => _year = y);
                    },
                  ),
                  const SizedBox(height: 6),
                  // ----------------------------------------- specifications
                  _sectionTitle(s.t('المواصفات', 'SPECIFICATIONS')),
                  _field(
                    LucideIcons.sparkles,
                    s.t('الحالة', 'Condition'),
                    spec(_condition),
                    () async {
                      final v = await _pickSpec(
                          s.t('الحالة', 'Condition'), _specs.conditions);
                      if (v != null) setState(() => _condition = v);
                    },
                  ),
                  _field(
                    LucideIcons.carFront,
                    s.t('نوع الهيكل', 'Body type'),
                    spec(_bodyType),
                    () async {
                      final v = await _pickSpec(
                          s.t('نوع الهيكل', 'Body type'),
                          _specs.bodyTypes);
                      if (v != null) setState(() => _bodyType = v);
                    },
                  ),
                  _field(
                    LucideIcons.globe,
                    s.t('المواصفات الإقليمية', 'Regional spec'),
                    spec(_regionalSpec),
                    () async {
                      final v = await _pickSpec(
                          s.t('المواصفات الإقليمية', 'Regional spec'),
                          _specs.regionalSpecs);
                      if (v != null) setState(() => _regionalSpec = v);
                    },
                  ),
                  _field(
                    LucideIcons.settings2,
                    s.t('ناقل الحركة', 'Transmission'),
                    spec(_transmission),
                    () async {
                      final v = await _pickSpec(
                          s.t('ناقل الحركة', 'Transmission'),
                          _specs.transmissions);
                      if (v != null) setState(() => _transmission = v);
                    },
                  ),
                  _field(
                    LucideIcons.move,
                    s.t('نظام الدفع', 'Drive line'),
                    spec(_drivetrain),
                    () async {
                      final v = await _pickSpec(
                          s.t('نظام الدفع', 'Drive line'),
                          _specs.drivetrains);
                      if (v != null) setState(() => _drivetrain = v);
                    },
                  ),
                  _field(
                    LucideIcons.fuel,
                    s.t('نوع الوقود', 'Fuel type'),
                    spec(_fuel),
                    () async {
                      final v = await _pickSpec(
                          s.t('نوع الوقود', 'Fuel type'), _specs.fuels);
                      if (v == null) return;
                      setState(() {
                        _fuel = v;
                        if (v == 'Electric') {
                          _cylinders = 0;
                          _engine.clear();
                        } else if (_cylinders == 0) {
                          _cylinders = null;
                        }
                      });
                    },
                  ),
                  // An EV has no displacement and no cylinders — don't ask.
                  if (_fuel != 'Electric') ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _engine,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: s.t('سعة المحرك، مثال 2.5',
                              'Engine size, e.g. 2.5'),
                          suffixText: s.t('لتر', 'L'),
                          prefixIcon:
                              const Icon(LucideIcons.settings),
                        ),
                      ),
                    ),
                    _field(
                      LucideIcons.cable,
                      s.t('الإسطوانات', 'Cylinders'),
                      _cylinders == null
                          ? null
                          : s.t('$_cylinders إسطوانات',
                              '$_cylinders ${_cylinders == 1 ? 'cylinder' : 'cylinders'}'),
                      () async {
                        final v = await _pickSpec(
                            s.t('الإسطوانات', 'Cylinders'),
                            _specs.cylinders
                                .where((o) => o.value > 0)
                                .toList());
                        if (v != null) setState(() => _cylinders = v);
                      },
                    ),
                  ],
                  _field(
                    LucideIcons.doorOpen,
                    s.t('الأبواب', 'Doors'),
                    _doors == null
                        ? null
                        : s.t('$_doors أبواب', '$_doors doors'),
                    () async {
                      final v = await _pickSpec(
                          s.t('الأبواب', 'Doors'), _specs.doors);
                      if (v != null) setState(() => _doors = v);
                    },
                  ),
                  _field(
                    LucideIcons.armchair,
                    s.t('المقاعد', 'Seats'),
                    _seats == null
                        ? null
                        : (_seats == 8
                            ? s.t('8+ مقاعد', '8+ seats')
                            : s.t('$_seats مقاعد', '$_seats seats')),
                    () async {
                      final v = await _pickSpec(
                          s.t('المقاعد', 'Seats'), _specs.seats);
                      if (v != null) setState(() => _seats = v);
                    },
                  ),
                  _WarrantyToggle(
                    value: _hasWarranty,
                    onChanged: (v) => setState(() => _hasWarranty = v),
                  ),
                  const SizedBox(height: 6),
                  // ------------------------------------------------ colors
                  _sectionTitle(s.t('الألوان', 'COLORS')),
                  _field(
                    LucideIcons.palette,
                    s.t('اللون الخارجي', 'Exterior color'),
                    spec(_exteriorColor),
                    () => _pickColor(
                        s.t('اللون الخارجي', 'Exterior color'), true),
                    swatch: _exteriorSwatch,
                  ),
                  _field(
                    LucideIcons.armchair,
                    s.t('اللون الداخلي', 'Interior color'),
                    spec(_interiorColor),
                    () => _pickColor(
                        s.t('اللون الداخلي', 'Interior color'), false),
                    swatch: _interiorSwatch,
                  ),
                  const SizedBox(height: 6),
                  // ---------------------------------------- location & deal
                  _sectionTitle(s.t('الموقع والصفقة', 'LOCATION & DEAL')),
                  _field(
                    LucideIcons.map,
                    s.t('المحافظة', 'Governorate'),
                    _governorate == null
                        ? null
                        : _locations.localized(_governorate!, s.isAr),
                    () async {
                      final g = await _pickFromList(
                          s.t('المحافظة', 'Governorate'),
                          _locations.governorates.keys.toList(),
                          (g) => _locations.localized(g, s.isAr));
                      if (g != null) {
                        setState(() {
                          _governorate = g;
                          _wilayat = null;
                        });
                      }
                    },
                  ),
                  _field(
                    LucideIcons.mapPin,
                    s.t('الولاية', 'Wilayat'),
                    _wilayat == null
                        ? null
                        : _locations.localized(_wilayat!, s.isAr),
                    () async {
                      final w = await _pickFromList(
                          s.t('الولاية — ${_locations.localized(_governorate ?? '', s.isAr)}',
                              'Wilayat — $_governorate'),
                          _locations.wilayatsOf(_governorate ?? ''),
                          (w) => _locations.localized(w, s.isAr));
                      if (w != null) setState(() => _wilayat = w);
                    },
                    enabled: _governorate != null,
                    hint: _governorate == null
                        ? s.t('اختر المحافظة أولاً',
                            'Select governorate first')
                        : s.t('الولاية', 'Wilayat'),
                  ),
                  _field(
                    LucideIcons.arrowLeftRight,
                    s.t('نوع الصفقة', 'Deal type'),
                    spec(_dealType),
                    () async {
                      final v = await _pickSpec(
                          s.t('نوع الصفقة', 'Deal type'),
                          _specs.dealTypes);
                      if (v != null) setState(() => _dealType = v);
                    },
                  ),
                  _field(
                    LucideIcons.store,
                    s.t('نوع البائع', 'Seller type'),
                    spec(_sellerType),
                    () async {
                      final v = await _pickSpec(
                          s.t('نوع البائع', 'Seller type'),
                          _specs.sellerTypes);
                      if (v != null) setState(() => _sellerType = v);
                    },
                  ),
                  const SizedBox(height: 6),
                  // -------------------------------------- price & details
                  _sectionTitle(s.t('السعر والتفاصيل', 'PRICE & DETAILS')),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _price,
                          enabled: !_askForPrice,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: _askForPrice
                                ? s.t('سيسألك المشترون', 'Buyers will ask you')
                                : s.t('السعر', 'Price'),
                            prefixIcon: Center(
                              child: RialGlyph(
                                fontSize: 20,
                                color: AppColors.ink3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => setState(
                            () => _askForPrice = !_askForPrice),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 14),
                          decoration: BoxDecoration(
                            color: _askForPrice
                                ? AppColors.ink
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _askForPrice
                                    ? AppColors.ink
                                    : AppColors.border,
                                width: 1.5),
                          ),
                          child: Text(
                            s.t('اسأل عن السعر', 'Ask for price'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _askForPrice
                                  ? Colors.white
                                  : AppColors.ink2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mileage,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: s.t('الممشى (كم)', 'Mileage (km)'),
                      prefixIcon: const Icon(LucideIcons.gauge),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: s.t(
                          'الوصف — الحالة، الإضافات، سجل الصيانة…',
                          'Description — condition, options, service history…'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                onPressed: _canPublish ? _publish : null,
                child: Text(_canPublish
                    ? s.t('نشر الإعلان', 'Publish ad')
                    : _photos.length < _minPhotos
                        ? s.t('أضف $_minPhotos صور على الأقل',
                            'Add at least $_minPhotos photos')
                        : s.t('أكمل التفاصيل أعلاه',
                            'Complete the details above')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Still under warranty" — a yes/no fact buyers filter on, so it is a
/// switch, not something buried in the free-text description.
class _WarrantyToggle extends StatelessWidget {
  const _WarrantyToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: value ? AppColors.brand : AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.shieldCheck,
                  size: 18, color: value ? AppColors.brand : AppColors.ink3),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  S.of(context).t('لا تزال تحت الضمان',
                      'Still under warranty'),
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
