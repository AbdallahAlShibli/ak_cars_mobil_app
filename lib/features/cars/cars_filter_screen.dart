import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/car_media.dart';
import '../../data/app_state.dart';
import '../../data/car_catalog.dart';
import '../../data/gallery_data.dart';

/// Collapsible filter sections, in display order — modelled on the
/// sooq-cars marketplace filter (accordion of Make&Model, Sub-Model, Year,
/// Specs, … Region, City), extended with the extra facets our listing data
/// supports (body type, mileage, deal type, sort).
enum _Section {
  makeModel,
  subModel,
  bodyType,
  year,
  specs,
  transmission,
  driveLine,
  fuel,
  cylinders,
  mileage,
  price,
  exteriorColor,
  interiorColor,
  region,
  city,
  dealType,
  sort,
}

/// Modern accordion car filter (sooq-cars pattern), Sand & Ink themed and
/// dark-mode-correct. "Make and Model" is a combined section with a
/// selected-car card + a register-a-car-style "Select Car" picker (make
/// logo grid → model list). Pops with the chosen [CarsFilter].
class CarsFilterScreen extends ConsumerStatefulWidget {
  const CarsFilterScreen({super.key, required this.initial});

  final CarsFilter initial;

  @override
  ConsumerState<CarsFilterScreen> createState() => _CarsFilterScreenState();
}

class _CarsFilterScreenState extends ConsumerState<CarsFilterScreen> {
  late CarsFilter _draft;
  // Accordion allows several open at once (like the reference).
  final Set<_Section> _open = {_Section.makeModel};

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  CarMake? get _make =>
      CarCatalog.makes.firstWhereOrNull((m) => m.name == _draft.make);

  // ---------------------------------------------------------------- pickers
  Future<void> _selectCar() async {
    final make = await _pickMake();
    if (make == null) return;
    setState(() => _draft = _draft.copyWith(
        make: () => make.name, model: () => null, trims: const {}));
    final model = await _pickModel(make);
    if (model != null) {
      setState(() => _draft = _draft.copyWith(model: () => model));
    }
  }

  Future<CarMake?> _pickMake() {
    final s = S.of(context);
    return _showPopup<CarMake>(
      title: s.t('اختر المُصنع', 'Select make'),
      searchable: true,
      builder: (context, query) {
        final ak = AkColors.of(context);
        final makes = CarCatalog.makes
            .where((m) => m.name.toLowerCase().contains(query))
            .toList();
        return GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 0.8,
          children: [
            for (final m in makes)
              GestureDetector(
                onTap: () => Navigator.pop(context, m),
                child: Container(
                  decoration: BoxDecoration(
                    color: ak.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _draft.make == m.name ? ak.ink : ak.border,
                      width: _draft.make == m.name ? 2 : 1,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MakeLogo(make: m, size: 32),
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          m.name,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 9.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<String?> _pickModel(CarMake make) {
    final s = S.of(context);
    return _showPopup<String>(
      title: s.t('اختر الطراز — ${make.name}', 'Select model — ${make.name}'),
      searchable: true,
      builder: (context, query) => Column(
        children: [
          for (final model
              in make.models.where((m) => m.toLowerCase().contains(query)))
            _RadioRow(
              label: model,
              selected: _draft.model == model,
              onTap: () => Navigator.pop(context, model),
            ),
        ],
      ),
    );
  }

  Future<int?> _pickYear({required bool isFrom}) {
    final s = S.of(context);
    final options = CarCatalog.years.where((y) {
      if (isFrom) return _draft.toYear == null || y <= _draft.toYear!;
      return _draft.fromYear == null || y >= _draft.fromYear!;
    }).toList();
    return _showPopup<int>(
      title: isFrom ? s.t('من سنة', 'From year') : s.t('إلى سنة', 'To year'),
      builder: (context, _) => Column(
        children: [
          for (final y in options)
            _RadioRow(
              label: '$y',
              selected: (isFrom ? _draft.fromYear : _draft.toYear) == y,
              onTap: () => Navigator.pop(context, y),
            ),
        ],
      ),
    );
  }

  Future<T?> _showPopup<T>({
    required String title,
    required Widget Function(BuildContext, String query) builder,
    bool searchable = false,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _PopupScaffold(title: title, searchable: searchable, builder: builder),
    );
  }

  // ---------------------------------------------------------------- active
  bool _isActive(_Section s) => switch (s) {
        _Section.makeModel => _draft.make != null || _draft.model != null,
        _Section.subModel => _draft.trims.isNotEmpty,
        _Section.bodyType => _draft.bodyTypes.isNotEmpty,
        _Section.year => _draft.fromYear != null || _draft.toYear != null,
        _Section.specs => _draft.specGrades.isNotEmpty,
        _Section.transmission => _draft.transmissions.isNotEmpty,
        _Section.driveLine => _draft.drivetrains.isNotEmpty,
        _Section.fuel => _draft.fuels.isNotEmpty,
        _Section.cylinders => _draft.cylinders.isNotEmpty,
        _Section.mileage => _draft.maxMileage != null,
        _Section.price => _draft.minPrice != null || _draft.maxPrice != null,
        _Section.exteriorColor => _draft.exteriorColors.isNotEmpty,
        _Section.interiorColor => _draft.interiorColors.isNotEmpty,
        _Section.region => _draft.regions.isNotEmpty,
        _Section.city => _draft.cities.isNotEmpty,
        _Section.dealType => _draft.dealTypes.isNotEmpty,
        _Section.sort => _draft.sort != GallerySort.newest,
      };

  (String, IconData) _meta(_Section s, S l) => switch (s) {
        _Section.makeModel =>
          (l.t('المُصنع والطراز', 'Make and Model'), LucideIcons.car),
        _Section.subModel =>
          (l.t('الفئة الفرعية', 'Sub-Model'), LucideIcons.layers),
        _Section.bodyType =>
          (l.t('نوع الهيكل', 'Body Type'), LucideIcons.carFront),
        _Section.year => (l.t('السنة', 'Year'), LucideIcons.calendar),
        _Section.specs => (l.t('المواصفات', 'Specs'), LucideIcons.info),
        _Section.transmission =>
          (l.t('ناقل الحركة', 'Transmission'), LucideIcons.settings2),
        _Section.driveLine =>
          (l.t('نظام الدفع', 'Drive Line'), LucideIcons.move),
        _Section.fuel => (l.t('نوع الوقود', 'Fuel Type'), LucideIcons.fuel),
        _Section.cylinders =>
          (l.t('عدد الإسطوانات', 'Cylinders'), LucideIcons.cylinder),
        _Section.mileage => (l.t('الممشى', 'Mileage'), LucideIcons.gauge),
        _Section.price => (l.t('نطاق السعر', 'Price Range'), LucideIcons.tag),
        _Section.exteriorColor =>
          (l.t('اللون الخارجي', 'Exterior Color'), LucideIcons.palette),
        _Section.interiorColor =>
          (l.t('اللون الداخلي', 'Interior Color'), LucideIcons.armchair),
        _Section.region => (l.t('المنطقة', 'Region'), LucideIcons.mapPin),
        _Section.city => (l.t('المدينة', 'City'), LucideIcons.building2),
        _Section.dealType =>
          (l.t('نوع الصفقة', 'Deal Type'), LucideIcons.repeat),
        _Section.sort => (l.t('الترتيب', 'Sort'), LucideIcons.arrowUpDown),
      };

  Set<T> _toggle<T>(Set<T> set, T v) {
    final next = {...set};
    if (!next.add(v)) next.remove(v);
    return next;
  }

  List<T> _distinct<T extends Comparable>(
      List<GalleryListing> feed, T Function(GalleryListing) of) {
    final seen = <T>{};
    for (final l in feed) {
      seen.add(of(l));
    }
    return seen.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final feed = ref.watch(galleryFeedProvider);
    final resultCount = _draft.apply(feed).length;

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ------------------------------------------------ header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      s.t('الفلاتر', 'Filters'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  GestureDetector(
                    onTap: _draft.activeCount == 0
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() => _draft = const CarsFilter());
                          },
                    child: Text(
                      s.t('مسح الكل', 'Clear Filters'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _draft.activeCount == 0 ? ak.inkFaint : ak.amberText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: ak.border),
            // ------------------------------------------------ sections
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  for (final section in _Section.values)
                    _AccordionTile(
                      icon: _meta(section, s).$2,
                      title: _meta(section, s).$1,
                      active: _isActive(section),
                      expanded: _open.contains(section),
                      onToggle: () => setState(() {
                        if (!_open.remove(section)) _open.add(section);
                      }),
                      child: _body(section, s, feed),
                    ),
                ],
              ),
            ),
            // ------------------------------------------------ apply bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              decoration: BoxDecoration(
                color: ak.surface,
                border: Border(top: BorderSide(color: ak.border)),
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context, _draft);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: ak.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      s.t('عرض $resultCount نتيجة', 'Show $resultCount results'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ak.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bodies
  Widget _body(_Section section, S s, List<GalleryListing> feed) {
    switch (section) {
      case _Section.makeModel:
        return _makeModelBody(s);
      case _Section.subModel:
        final model = _draft.model;
        if (model == null) {
          return _hint(_draft.make == null
              ? s.t('اختر السيارة أولاً', 'Select a car first')
              : s.t('اختر الطراز أولاً', 'Select a model first'));
        }
        // Prefer the catalog's trim list; fall back to trims seen in the feed.
        var options = GalleryData.trimsFor(model);
        if (options.isEmpty) {
          options = feed
              .where((l) => l.model == model)
              .map((l) => l.trim)
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
        }
        if (options.isEmpty) {
          return _hint(s.t('لا فئات فرعية', 'No sub-models'));
        }
        // Display model-prefixed (e.g. "Camry LE"), store the raw trim.
        return _checks(options, _draft.trims, (v) => '$model $v',
            (set) => setState(() => _draft = _draft.copyWith(trims: set)));
      case _Section.bodyType:
        return _checks(_distinct(feed, (l) => l.bodyType), _draft.bodyTypes,
            (v) => _bodyLabel(s, v),
            (set) => setState(() => _draft = _draft.copyWith(bodyTypes: set)));
      case _Section.year:
        return _yearBody(s);
      case _Section.specs:
        return _checks(_distinct(feed, (l) => l.specGrade), _draft.specGrades,
            (v) => _specLabel(s, v),
            (set) => setState(() => _draft = _draft.copyWith(specGrades: set)));
      case _Section.transmission:
        return _checks(_distinct(feed, (l) => l.transmission),
            _draft.transmissions, (v) => _transmissionLabel(s, v),
            (set) =>
                setState(() => _draft = _draft.copyWith(transmissions: set)));
      case _Section.driveLine:
        return _checks(_distinct(feed, (l) => l.drivetrain), _draft.drivetrains,
            (v) => _drivetrainLabel(s, v),
            (set) => setState(() => _draft = _draft.copyWith(drivetrains: set)));
      case _Section.fuel:
        return _checks(_distinct(feed, (l) => l.fuel), _draft.fuels,
            (v) => _fuelLabel(s, v),
            (set) => setState(() => _draft = _draft.copyWith(fuels: set)));
      case _Section.cylinders:
        return _checks<int>(_distinct(feed, (l) => l.cylinders),
            _draft.cylinders, (v) => s.t('$v إسطوانات', '$v-cylinder'),
            (set) => setState(() => _draft = _draft.copyWith(cylinders: set)));
      case _Section.mileage:
        return _mileageBody(s, feed);
      case _Section.price:
        return _priceBody(s, feed);
      case _Section.exteriorColor:
        return _colorBody(s, feed, (l) => l.exteriorColor,
            (l) => l.exteriorSwatch, _draft.exteriorColors,
            (set) =>
                setState(() => _draft = _draft.copyWith(exteriorColors: set)));
      case _Section.interiorColor:
        return _colorBody(s, feed, (l) => l.interiorColor,
            (l) => l.interiorSwatch, _draft.interiorColors,
            (set) =>
                setState(() => _draft = _draft.copyWith(interiorColors: set)));
      case _Section.region:
        return _checks(_distinct(feed, (l) => l.governorate), _draft.regions,
            (v) => v,
            (set) => setState(() => _draft = _draft.copyWith(regions: set)));
      case _Section.city:
        return _checks(_distinct(feed, (l) => l.cityName), _draft.cities,
            (v) => v,
            (set) => setState(() => _draft = _draft.copyWith(cities: set)));
      case _Section.dealType:
        return _checks(_distinct(feed, (l) => l.dealType), _draft.dealTypes,
            (v) => _dealLabel(s, v),
            (set) => setState(() => _draft = _draft.copyWith(dealTypes: set)));
      case _Section.sort:
        return Column(
          children: [
            for (final sort in GallerySort.values)
              _RadioRow(
                label: _sortLabel(s, sort),
                selected: _draft.sort == sort,
                onTap: () =>
                    setState(() => _draft = _draft.copyWith(sort: sort)),
              ),
          ],
        );
    }
  }

  Widget _makeModelBody(S s) {
    final ak = AkColors.of(context);
    final make = _make;
    return Column(
      children: [
        if (make != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ak.surfaceDim,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ak.border),
            ),
            child: Row(
              children: [
                MakeLogo(make: make, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(make.name.toUpperCase(),
                          style: GoogleFonts.chakraPetch(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(
                        _draft.model ?? s.t('كل الطُرز', 'All models'),
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: ak.inkSub),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _selectCar,
                  child: Icon(LucideIcons.squarePen, size: 18, color: ak.inkSub),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _draft = _draft.copyWith(
                      make: () => null,
                      model: () => null,
                      trims: const {})),
                  child: Icon(LucideIcons.x, size: 18, color: ak.inkFaint),
                ),
              ],
            ),
          ),
        if (make != null) const SizedBox(height: 10),
        GestureDetector(
          onTap: _selectCar,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: ak.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ak.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.circlePlus, size: 17, color: ak.ink),
                const SizedBox(width: 8),
                Text(
                  make == null
                      ? s.t('اختر السيارة', 'Select Car')
                      : s.t('تغيير السيارة', 'Change Car'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _yearBody(S s) {
    return Row(
      children: [
        Expanded(
          child: _DropdownField(
            label: s.t('من', 'From'),
            value: _draft.fromYear?.toString(),
            onTap: () async {
              final y = await _pickYear(isFrom: true);
              if (y == null) return;
              setState(() => _draft = _draft.copyWith(
                    fromYear: () => y,
                    toYear: () => (_draft.toYear != null && _draft.toYear! < y)
                        ? y
                        : _draft.toYear,
                  ));
            },
            onClear: _draft.fromYear == null
                ? null
                : () => setState(
                    () => _draft = _draft.copyWith(fromYear: () => null)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DropdownField(
            label: s.t('إلى', 'To'),
            value: _draft.toYear?.toString(),
            onTap: () async {
              final y = await _pickYear(isFrom: false);
              if (y == null) return;
              setState(() => _draft = _draft.copyWith(
                    toYear: () => y,
                    fromYear: () =>
                        (_draft.fromYear != null && _draft.fromYear! > y)
                            ? y
                            : _draft.fromYear,
                  ));
            },
            onClear: _draft.toYear == null
                ? null
                : () => setState(
                    () => _draft = _draft.copyWith(toYear: () => null)),
          ),
        ),
      ],
    );
  }

  Widget _mileageBody(S s, List<GalleryListing> feed) {
    final ak = AkColors.of(context);
    final values = [for (final l in feed) l.mileageValue]..sort();
    final maxKm = values.isEmpty ? 0 : ((values.last / 10000).ceil() * 10000);
    if (maxKm == 0) return _hint(s.t('لا بيانات', 'No data'));
    final current = _draft.maxMileage ?? maxKm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _draft.maxMileage == null
              ? s.t('أي ممشى', 'Any mileage')
              : s.t('حتى ${_km(current)} كم', 'Up to ${_km(current)} km'),
          style: GoogleFonts.chakraPetch(
              fontSize: 13, fontWeight: FontWeight.w700, color: ak.ink),
        ),
        Slider(
          value: current.toDouble(),
          min: 10000,
          max: maxKm.toDouble(),
          divisions: (maxKm / 10000).round(),
          activeColor: ak.primary,
          onChanged: (v) => setState(() => _draft = _draft.copyWith(
              maxMileage: () => v.round() >= maxKm ? null : v.round())),
        ),
      ],
    );
  }

  Widget _priceBody(S s, List<GalleryListing> feed) {
    final ak = AkColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PriceRangeInput(
          min: _draft.minPrice,
          max: _draft.maxPrice,
          onChanged: (mn, mx) => setState(() => _draft = _draft.copyWith(
              minPrice: () => mn, maxPrice: () => mx)),
        ),
        if (_draft.minPrice != null || _draft.maxPrice != null) ...[
          const SizedBox(height: 8),
          Text(
            s.t('إعلانات «عند الطلب» تُخفى', '"Ask for price" ads are hidden'),
            style: TextStyle(fontSize: 10, color: ak.inkFaint),
          ),
        ],
      ],
    );
  }

  Widget _colorBody(
    S s,
    List<GalleryListing> feed,
    String Function(GalleryListing) colorOf,
    Color Function(GalleryListing) swatchOf,
    Set<String> selected,
    ValueChanged<Set<String>> onChanged,
  ) {
    final swatches = <String, Color>{};
    for (final l in feed) {
      swatches.putIfAbsent(colorOf(l), () => swatchOf(l));
    }
    final options = swatches.keys.toList()..sort();
    if (options.isEmpty) return _hint(s.t('لا خيارات', 'No options'));
    return Column(
      children: [
        for (final o in options)
          _CheckRow(
            label: _colorLabel(s, o),
            selected: selected.contains(o),
            swatch: swatches[o],
            onTap: () => onChanged(_toggle(selected, o)),
          ),
      ],
    );
  }

  Widget _checks<T>(
    List<T> options,
    Set<T> selected,
    String Function(T) labelOf,
    ValueChanged<Set<T>> onChanged,
  ) {
    if (options.isEmpty) {
      return _hint(S.of(context).t('لا خيارات', 'No options'));
    }
    return Column(
      children: [
        for (final o in options)
          _CheckRow(
            label: labelOf(o),
            selected: selected.contains(o),
            onTap: () => onChanged(_toggle(selected, o)),
          ),
      ],
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, color: AkColors.of(context).inkFaint)),
      );

  // -------------------------------------------------------------- labels
  String _dealLabel(S s, String v) => switch (v) {
        'Sale only' => s.t('بيع فقط', 'Sale only'),
        'Sale or exchange' => s.t('بيع أو تبديل', 'Sale or exchange'),
        _ => v,
      };
  String _bodyLabel(S s, String v) => switch (v) {
        'Sedan' => s.t('سيدان', 'Sedan'),
        'SUV' => s.t('دفع رباعي', 'SUV'),
        'Pickup' => s.t('بيك أب', 'Pickup'),
        _ => v,
      };
  String _specLabel(S s, String v) => switch (v) {
        'First grade' => s.t('الفئة الأولى', 'First grade'),
        'Second grade' => s.t('الفئة الثانية', 'Second grade'),
        _ => v,
      };
  String _transmissionLabel(S s, String v) => switch (v) {
        'Automatic' => s.t('أوتوماتيك', 'Automatic'),
        'Manual' => s.t('عادي', 'Manual'),
        _ => v,
      };
  String _drivetrainLabel(S s, String v) => switch (v) {
        'Front-wheel drive' => s.t('دفع أمامي', 'Front-wheel drive'),
        'Rear-wheel drive' => s.t('دفع خلفي', 'Rear-wheel drive'),
        'Four-wheel drive' => s.t('دفع رباعي', 'Four-wheel drive'),
        _ => v,
      };
  String _fuelLabel(S s, String v) => switch (v) {
        'Petrol' => s.t('بترول', 'Petrol'),
        'Diesel' => s.t('ديزل', 'Diesel'),
        'Electric' => s.t('كهرباء', 'Electric'),
        'Hybrid' => s.t('هجين', 'Hybrid'),
        _ => v,
      };
  String _colorLabel(S s, String v) => switch (v) {
        'Silver' => s.t('فضي', 'Silver'),
        'Black' => s.t('أسود', 'Black'),
        'White' => s.t('أبيض', 'White'),
        'Gray' => s.t('رمادي', 'Gray'),
        'Maroon' => s.t('كستنائي', 'Maroon'),
        'Beige' => s.t('بيج', 'Beige'),
        'Blue' => s.t('أزرق', 'Blue'),
        'Red' => s.t('أحمر', 'Red'),
        'Brown' => s.t('بني', 'Brown'),
        'Gold' => s.t('ذهبي', 'Gold'),
        _ => v,
      };
  String _sortLabel(S s, GallerySort sort) => switch (sort) {
        GallerySort.newest => s.t('الأحدث إلى الأقدم', 'Newest to oldest'),
        GallerySort.oldest => s.t('الأقدم إلى الأحدث', 'Oldest to newest'),
        GallerySort.priceLowHigh =>
          s.t('السعر من الأدنى إلى الأعلى', 'Price: low to high'),
        GallerySort.priceHighLow =>
          s.t('السعر من الأعلى إلى الأدنى', 'Price: high to low'),
      };

  static String _km(int v) {
    final str = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

// ------------------------------------------------------------- sub-widgets

/// One collapsible accordion section: tappable header (icon + title + green
/// active tick + rotating chevron) over an animated body.
class _AccordionTile extends StatelessWidget {
  const _AccordionTile({
    required this.icon,
    required this.title,
    required this.active,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final bool active;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                Icon(icon, size: 17, color: ak.inkSub),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style:
                        const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (active)
                  Container(
                    width: 17,
                    height: 17,
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    decoration:
                        BoxDecoration(color: ak.success, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.check,
                        size: 11, color: Colors.white),
                  ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: expanded ? 0.5 : 0,
                  child: Icon(LucideIcons.chevronDown,
                      size: 18, color: ak.inkSub),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                )
              : const SizedBox(width: double.infinity),
        ),
        Divider(height: 1, color: ak.divider),
      ],
    );
  }
}

/// Multi-select row: label (+ optional color swatch) with an ink check box.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.swatch,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: ak.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? ak.ink : ak.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (swatch != null) ...[
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: ak.border),
                ),
              ),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: selected ? ak.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: selected ? ak.primary : ak.inkFaint, width: 1.5),
              ),
              child: selected
                  ? Icon(LucideIcons.check, size: 13, color: ak.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Single-select row (trailing radio dot).
class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: ak.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? ak.ink : ak.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? ak.ink : ak.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// A dropdown-style field (label + value + chevron) — the Year From/To cells.
class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.onTap,
    this.value,
    this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final filled = value != null;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 10, 11),
        decoration: BoxDecoration(
          color: ak.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? ak.ink : ak.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                filled ? value! : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: filled
                    ? GoogleFonts.chakraPetch(
                        fontSize: 13, fontWeight: FontWeight.w700)
                    : TextStyle(fontSize: 12.5, color: ak.inkFaint),
              ),
            ),
            Icon(
              filled && onClear != null ? LucideIcons.x : LucideIcons.chevronDown,
              size: 15,
              color: ak.inkSub,
            ),
          ],
        ),
      ),
    );
  }
}

/// Two numeric OMR input fields (Min / Max) — the marketplace's price
/// range control. Syncs external resets (Clear Filters) back into the
/// fields without disturbing in-progress typing.
class _PriceRangeInput extends StatefulWidget {
  const _PriceRangeInput({
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double? min;
  final double? max;
  final void Function(double? min, double? max) onChanged;

  @override
  State<_PriceRangeInput> createState() => _PriceRangeInputState();
}

class _PriceRangeInputState extends State<_PriceRangeInput> {
  late final TextEditingController _minC =
      TextEditingController(text: widget.min?.round().toString() ?? '');
  late final TextEditingController _maxC =
      TextEditingController(text: widget.max?.round().toString() ?? '');

  double? _parse(String t) {
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : double.tryParse(digits);
  }

  @override
  void didUpdateWidget(covariant _PriceRangeInput old) {
    super.didUpdateWidget(old);
    if (_parse(_minC.text) != widget.min) {
      _minC.text = widget.min?.round().toString() ?? '';
    }
    if (_parse(_maxC.text) != widget.max) {
      _maxC.text = widget.max?.round().toString() ?? '';
    }
  }

  @override
  void dispose() {
    _minC.dispose();
    _maxC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Row(
      children: [
        Expanded(
          child: _field(ak, s, _minC, s.t('الأدنى', 'Min'),
              (v) => widget.onChanged(_parse(v), widget.max)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('—', style: TextStyle(color: ak.inkFaint)),
        ),
        Expanded(
          child: _field(ak, s, _maxC, s.t('الأعلى', 'Max'),
              (v) => widget.onChanged(widget.min, _parse(v))),
        ),
      ],
    );
  }

  Widget _field(AkColors ak, S s, TextEditingController controller,
      String hint, ValueChanged<String> onChanged) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: GoogleFonts.chakraPetch(
          fontSize: 13, fontWeight: FontWeight.w700, color: ak.ink),
      decoration: InputDecoration(
        hintText: hint,
        suffixText: s.omr,
        suffixStyle: TextStyle(fontSize: 11, color: ak.inkSub),
        isDense: true,
        filled: true,
        fillColor: ak.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: border(ak.border, 1),
        border: border(ak.border, 1),
        focusedBorder: border(ak.ink, 1.5),
      ),
    );
  }
}

/// Bottom-sheet scaffold for the make/model/year popup pickers.
class _PopupScaffold extends StatefulWidget {
  const _PopupScaffold({
    required this.title,
    required this.builder,
    required this.searchable,
  });

  final String title;
  final Widget Function(BuildContext, String query) builder;
  final bool searchable;

  @override
  State<_PopupScaffold> createState() => _PopupScaffoldState();
}

class _PopupScaffoldState extends State<_PopupScaffold> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: s.t('ابحث…', 'Search…'),
                    prefixIcon: const Icon(Icons.search_rounded),
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
