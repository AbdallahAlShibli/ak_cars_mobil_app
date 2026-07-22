import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/widgets.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// Rule 12: filter by car, category, provider, price and region.
/// The car is selected exactly like registering a car — popup pickers
/// for make (logo grid), model and year.
class ShopFilterSheet extends ConsumerStatefulWidget {
  const ShopFilterSheet({super.key});

  @override
  ConsumerState<ShopFilterSheet> createState() => _ShopFilterSheetState();
}

class _ShopFilterSheetState extends ConsumerState<ShopFilterSheet> {
  late ShopFilter _draft;
  CarMake? _make;
  String? _model;
  int? _fromYear;
  int? _toYear;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(shopFilterProvider);
    final car = _draft.car;
    if (car != null) {
      _make = _makes.where((m) => m.name == car.make).firstOrNull;
      _model = car.model;
      _fromYear = car.year;
    }
  }

  Car? get _selectedCar =>
      (_make != null && _model != null)
          ? Car(
              id: 'filter',
              make: _make!.name,
              model: _model!,
              year: _fromYear ?? DateTime.now().year,
            )
          : null;

  void _apply() {
    ref
        .read(shopFilterProvider.notifier)
        .set(_draft.copyWith(car: () => _selectedCar));
    Navigator.pop(context);
  }

  /// Live count for the "Show N results" button. Uses the same filter the
  /// shop applies, against the draft's currently picked car.
  int get _resultCount => ref
      .read(shopRepositoryProvider)
      .filter(_draft.copyWith(car: () => _selectedCar))
      .length;

  List<CarMake> get _makes => ref.read(vehicleCatalogProvider).makes;

  /// ------------------------------------------------ popup pickers
  /// (same experience as registering a new car)

  Future<void> _pickMake() async {
    HapticFeedback.selectionClick();
    final make = await showModalBottomSheet<CarMake>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PickerSheet<CarMake>(
        title: S.of(context).t('اختر الشركة المصنعة', 'Pick a make'),
        searchable: true,
        optionsOf: (query) => _makes
            .where((m) => m.name.toLowerCase().contains(query))
            .toList(),
        itemBuilder: (context, make, onPick) => GestureDetector(
          onTap: onPick,
          child: Container(
            decoration: BoxDecoration(
              color: AkColors.of(context).surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _make == make
                    ? AkColors.of(context).ink
                    : AkColors.of(context).border,
                width: _make == make ? 2 : 1,
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MakeLogo(make: make, size: 36),
                const SizedBox(height: 6),
                Text(
                  make.name,
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
        grid: true,
      ),
    );
    if (make != null) {
      setState(() {
        _make = make;
        _model = null;
      });
    }
  }

  Future<void> _pickModel() async {
    if (_make == null) return;
    HapticFeedback.selectionClick();
    final model = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PickerSheet<String>(
        title: S.of(context).t('اختر الموديل — ${_make!.name}',
            'Choose model — ${_make!.name}'),
        searchable: true,
        optionsOf: (query) => _make!.models
            .where((m) => m.toLowerCase().contains(query))
            .toList(),
        itemBuilder: (context, model, onPick) => _OptionRow(
          label: model,
          icon: Icons.directions_car_outlined,
          selected: _model == model,
          onTap: onPick,
        ),
      ),
    );
    if (model != null) setState(() => _model = model);
  }

  Future<void> _pickYear({required bool isFrom}) async {
    HapticFeedback.selectionClick();
    // Rule: "To" can never be older than "From".
    final options = ref.read(vehicleCatalogProvider).years.where((y) {
      if (isFrom) return _toYear == null || y <= _toYear!;
      return _fromYear == null || y >= _fromYear!;
    }).toList();
    final year = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PickerSheet<int>(
        title: isFrom
            ? S.of(context).t('سنة الصنع — من', 'Made year — from')
            : S.of(context).t('سنة الصنع — إلى', 'Made year — to'),
        optionsOf: (_) => options,
        itemBuilder: (context, year, onPick) => _OptionRow(
          label: '$year',
          icon: Icons.calendar_today_outlined,
          selected: (isFrom ? _fromYear : _toYear) == year,
          onTap: onPick,
        ),
      ),
    );
    if (year == null) return;
    setState(() {
      if (isFrom) {
        _fromYear = year;
        if (_toYear != null && _toYear! < year) _toYear = year;
      } else {
        _toYear = year;
        if (_fromYear != null && _fromYear! > year) _fromYear = year;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final myCar = ref.watch(primaryCarProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.t('التصفية', 'Filters'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _draft = const ShopFilter();
                    _make = null;
                    _model = null;
                    _fromYear = null;
                    _toYear = null;
                  }),
                  child: Text(s.t('إعادة تعيين', 'Reset')),
                ),
              ],
            ),
            Text(s.t('التسوق لسيارة', 'Shopping for car'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (myCar != null)
                  SelectChip(
                    label: s.t('سيارتي ${myCar.label}', 'My ${myCar.label}'),
                    selected: _make?.name == myCar.make &&
                        _model == myCar.model,
                    onTap: () => setState(() {
                      _make =
                          _makes.where((m) => m.name == myCar.make).firstOrNull;
                      _model = myCar.model;
                      _fromYear = myCar.year;
                      _toYear = null;
                    }),
                  ),
                SelectChip(
                  label: s.t('أي سيارة', 'Any car'),
                  selected: _make == null,
                  onTap: () => setState(() {
                    _make = null;
                    _model = null;
                    _fromYear = null;
                    _toYear = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PickerField(
              icon: Icons.factory_outlined,
              label: s.t('الشركة المصنعة', 'Make'),
              value: _make?.name,
              onTap: _pickMake,
            ),
            _PickerField(
              icon: Icons.directions_car_outlined,
              label: s.t('الموديل', 'Model'),
              value: _model,
              hint: _make == null
                  ? s.t('اختر الشركة أولاً', 'Select make first')
                  : null,
              enabled: _make != null,
              onTap: _pickModel,
            ),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    icon: Icons.calendar_today_outlined,
                    label: s.t('السنة من', 'Year from'),
                    value: _fromYear == null ? null : '$_fromYear',
                    hint: s.t('اختياري', 'Optional'),
                    onTap: () => _pickYear(isFrom: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerField(
                    icon: Icons.event_outlined,
                    label: s.t('السنة إلى', 'Year to'),
                    value: _toYear == null ? null : '$_toYear',
                    hint: s.t('اختياري', 'Optional'),
                    onTap: () => _pickYear(isFrom: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(s.t('الفئة', 'Category'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                SelectChip(
                  label: s.t('الكل', 'All'),
                  selected: _draft.categoryId == null,
                  onTap: () => setState(() =>
                      _draft = _draft.copyWith(categoryId: () => null)),
                ),
                for (final e in ref.watch(partCategoriesProvider).entries)
                  SelectChip(
                    label: e.value.of(s),
                    selected: _draft.categoryId == e.key,
                    onTap: () => setState(() =>
                        _draft = _draft.copyWith(categoryId: () => e.key)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(s.t('المزود / المتجر', 'Provider / store'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                SelectChip(
                  label: s.t('أي', 'Any'),
                  selected: _draft.providerId == null,
                  onTap: () => setState(() =>
                      _draft = _draft.copyWith(providerId: () => null)),
                ),
                for (final p in ref.watch(shopSellersProvider).take(4))
                  SelectChip(
                    label: p.name.of(s),
                    selected: _draft.providerId == p.id,
                    onTap: () => setState(() =>
                        _draft = _draft.copyWith(providerId: () => p.id)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.t('نطاق السعر', 'Price range'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Text(
                  '${s.omr} ${_draft.minPrice.round()} — ${_draft.maxPrice.round()}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AkColors.of(context).ink),
                ),
              ],
            ),
            RangeSlider(
              values: RangeValues(_draft.minPrice, _draft.maxPrice),
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: AkColors.of(context).primary,
              onChanged: (v) => setState(() => _draft =
                  _draft.copyWith(minPrice: v.start, maxPrice: v.end)),
            ),
            Text(s.t('المنطقة', 'Region'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                SelectChip(
                  label: s.t('كل عُمان', 'All Oman'),
                  selected: _draft.region == null,
                  onTap: () => setState(
                      () => _draft = _draft.copyWith(region: () => null)),
                ),
                for (final r in ref.watch(serviceRegionsProvider))
                  SelectChip(
                    label:
                        ref.watch(locationCatalogProvider).localized(r, s.isAr),
                    selected: _draft.region == r,
                    onTap: () => setState(
                        () => _draft = _draft.copyWith(region: () => r)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _apply,
              child: Text(s.t('عرض $_resultCount نتيجة',
                  'Show $_resultCount results')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable field row that opens a popup picker (same as add-car).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.hint,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? hint;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
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
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: ak.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled ? ak.ink : ak.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: filled ? ak.ink : ak.inkFaint),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: filled ? 10.5 : 13,
                          color: ak.inkFaint,
                          fontWeight: FontWeight.w600,
                        ),
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
                          style: TextStyle(
                              fontSize: 11, color: ak.inkFaint),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.expand_more_rounded, color: ak.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: ak.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? ak.ink : ak.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 17,
                color: selected ? ak.ink : ak.inkFaint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 18, color: ak.ink),
          ],
        ),
      ),
    );
  }
}

/// Generic popup picker sheet (title + optional search + list/grid).
class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.optionsOf,
    required this.itemBuilder,
    this.searchable = false,
    this.grid = false,
  });

  final String title;
  final List<T> Function(String query) optionsOf;
  final Widget Function(BuildContext, T, VoidCallback onPick) itemBuilder;
  final bool searchable;
  final bool grid;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final options = widget.optionsOf(_query);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
                    hintText: S.of(context).t('ابحث…', 'Search…'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Flexible(
                child: widget.grid
                    ? GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 9,
                          crossAxisSpacing: 9,
                          childAspectRatio: 0.86,
                        ),
                        itemCount: options.length,
                        itemBuilder: (context, i) => widget.itemBuilder(
                          context,
                          options[i],
                          () => Navigator.pop(context, options[i]),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, i) => widget.itemBuilder(
                          context,
                          options[i],
                          () => Navigator.pop(context, options[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
