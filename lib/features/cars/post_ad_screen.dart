import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_state.dart';
import '../../data/car_catalog.dart';
import '../../data/car_spec_options.dart';
import '../../data/gallery_data.dart';
import '../../data/oman_locations.dart';

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
        'SUV' => Icons.airport_shuttle_rounded,
        'Pickup' => Icons.local_shipping_rounded,
        _ => Icons.directions_car_filled_rounded,
      };

  void _publish() {
    if (!_canPublish) return;
    final profile = ref.read(authProvider).profile;
    final ad = GalleryListing(
      id: 'my-${DateTime.now().millisecondsSinceEpoch}',
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
    ref.read(notificationsProvider.notifier).push(
          title: 'Your ad is live',
          body: '${_year!} ${_make!.name} $_model is now in the gallery.',
          icon: Icons.campaign_outlined,
          route: '/cars/listing/${ad.id}',
        );
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
    final chosen =
        await _pickFromList<SpecOption<T>>(title, options, (o) => o.en);
    return chosen?.value;
  }

  Future<void> _pickColor(String title, bool exterior) async {
    final chosen = await _pickFromList<SpecOption<String>>(
      title,
      CarSpecs.colors,
      (o) => o.en,
      leading: (o) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: CarSpecs.swatchOf(o.value),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
    if (chosen == null) return;
    setState(() {
      if (exterior) {
        _exteriorColor = chosen.value;
        _exteriorSwatch = CarSpecs.swatchOf(chosen.value);
      } else {
        _interiorColor = chosen.value;
        _interiorSwatch = CarSpecs.swatchOf(chosen.value);
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
                const Icon(Icons.expand_more_rounded,
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
    final enough = _photos.length >= _minPhotos;
    final canAdd = _photos.length < _maxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Photos (${_photos.length}/$_maxPhotos)',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink2)),
            ),
            Text(
              enough ? 'Ready' : 'Add ${_minPhotos - _photos.length} more',
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
                      Icon(Icons.add_a_photo_outlined,
                          size: 22, color: AppColors.brand),
                      const SizedBox(height: 5),
                      const Text('Add photo',
                          style: TextStyle(
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
              ? 'Add at least $_minPhotos photos (up to $_maxPhotos). '
                  'Uploads connect to storage in Phase 4.'
              : 'First photo is used as the cover.',
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
            child: Icon(Icons.directions_car_filled_rounded,
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
              child: const Text('Cover',
                  style: TextStyle(
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
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a car ad')),
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
                  _sectionTitle('VEHICLE'),
                  _field(
                    Icons.factory_outlined,
                    'Make',
                    _make?.name,
                    () async {
                      final m = await _pickFromList(
                          'Pick a make', CarCatalog.makes, (m) => m.name);
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
                    Icons.directions_car_outlined,
                    'Model',
                    _model,
                    () async {
                      final m = await _pickFromList('Choose model',
                          _make?.models ?? const <String>[], (m) => m);
                      if (m != null) {
                        setState(() {
                          _model = m;
                          _trim = null;
                        });
                      }
                    },
                    enabled: _make != null,
                    hint: _make == null ? 'Select make first' : 'Model',
                  ),
                  _field(
                    Icons.layers_outlined,
                    'Sub-model',
                    _trim,
                    () async {
                      final trims = GalleryData.trimsFor(_model ?? '');
                      final t = await _pickFromList(
                          'Sub-model — $_model', trims, (t) => t);
                      if (t != null) setState(() => _trim = t);
                    },
                    enabled: _model != null &&
                        GalleryData.trimsFor(_model ?? '').isNotEmpty,
                    hint: _model == null
                        ? 'Select model first'
                        : (GalleryData.trimsFor(_model!).isEmpty
                            ? 'No sub-models'
                            : 'Optional'),
                  ),
                  _field(
                    Icons.calendar_today_outlined,
                    'Year',
                    _year == null ? null : '$_year',
                    () async {
                      final y = await _pickFromList(
                          'Made year', CarCatalog.years, (y) => '$y');
                      if (y != null) setState(() => _year = y);
                    },
                  ),
                  const SizedBox(height: 6),
                  // ----------------------------------------- specifications
                  _sectionTitle('SPECIFICATIONS'),
                  _field(
                    Icons.auto_awesome_outlined,
                    'Condition',
                    _condition,
                    () async {
                      final v =
                          await _pickSpec('Condition', CarSpecs.conditions);
                      if (v != null) setState(() => _condition = v);
                    },
                  ),
                  _field(
                    Icons.directions_car_filled_outlined,
                    'Body type',
                    _bodyType,
                    () async {
                      final v =
                          await _pickSpec('Body type', CarSpecs.bodyTypes);
                      if (v != null) setState(() => _bodyType = v);
                    },
                  ),
                  _field(
                    Icons.public_outlined,
                    'Regional spec',
                    _regionalSpec,
                    () async {
                      final v =
                          await _pickSpec('Regional spec', CarSpecs.regionalSpecs);
                      if (v != null) setState(() => _regionalSpec = v);
                    },
                  ),
                  _field(
                    Icons.settings_outlined,
                    'Transmission',
                    _transmission,
                    () async {
                      final v = await _pickSpec(
                          'Transmission', CarSpecs.transmissions);
                      if (v != null) setState(() => _transmission = v);
                    },
                  ),
                  _field(
                    Icons.open_with_rounded,
                    'Drive line',
                    _drivetrain,
                    () async {
                      final v =
                          await _pickSpec('Drive line', CarSpecs.drivetrains);
                      if (v != null) setState(() => _drivetrain = v);
                    },
                  ),
                  _field(
                    Icons.local_gas_station_outlined,
                    'Fuel type',
                    _fuel,
                    () async {
                      final v = await _pickSpec('Fuel type', CarSpecs.fuels);
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
                        decoration: const InputDecoration(
                          hintText: 'Engine size, e.g. 2.5',
                          suffixText: 'L',
                          prefixIcon: Icon(Icons.settings_suggest_outlined),
                        ),
                      ),
                    ),
                    _field(
                      Icons.settings_input_component_outlined,
                      'Cylinders',
                      _cylinders == null
                          ? null
                          : '$_cylinders ${_cylinders == 1 ? 'cylinder' : 'cylinders'}',
                      () async {
                        final v = await _pickSpec('Cylinders',
                            CarSpecs.cylinders.where((o) => o.value > 0).toList());
                        if (v != null) setState(() => _cylinders = v);
                      },
                    ),
                  ],
                  _field(
                    Icons.sensor_door_outlined,
                    'Doors',
                    _doors == null ? null : '$_doors doors',
                    () async {
                      final v = await _pickSpec('Doors', CarSpecs.doors);
                      if (v != null) setState(() => _doors = v);
                    },
                  ),
                  _field(
                    Icons.event_seat_outlined,
                    'Seats',
                    _seats == null
                        ? null
                        : (_seats == 8 ? '8+ seats' : '$_seats seats'),
                    () async {
                      final v = await _pickSpec('Seats', CarSpecs.seats);
                      if (v != null) setState(() => _seats = v);
                    },
                  ),
                  _WarrantyToggle(
                    value: _hasWarranty,
                    onChanged: (v) => setState(() => _hasWarranty = v),
                  ),
                  const SizedBox(height: 6),
                  // ------------------------------------------------ colors
                  _sectionTitle('COLORS'),
                  _field(
                    Icons.palette_outlined,
                    'Exterior color',
                    _exteriorColor,
                    () => _pickColor('Exterior color', true),
                    swatch: _exteriorSwatch,
                  ),
                  _field(
                    Icons.chair_outlined,
                    'Interior color',
                    _interiorColor,
                    () => _pickColor('Interior color', false),
                    swatch: _interiorSwatch,
                  ),
                  const SizedBox(height: 6),
                  // ---------------------------------------- location & deal
                  _sectionTitle('LOCATION & DEAL'),
                  _field(
                    Icons.map_outlined,
                    'Governorate',
                    _governorate,
                    () async {
                      final g = await _pickFromList(
                          'Governorate',
                          OmanLocations.governorates.keys.toList(),
                          (g) => g);
                      if (g != null) {
                        setState(() {
                          _governorate = g;
                          _wilayat = null;
                        });
                      }
                    },
                  ),
                  _field(
                    Icons.location_on_outlined,
                    'Wilayat',
                    _wilayat,
                    () async {
                      final w = await _pickFromList(
                          'Wilayat — $_governorate',
                          OmanLocations.wilayatsOf(_governorate ?? ''),
                          (w) => w);
                      if (w != null) setState(() => _wilayat = w);
                    },
                    enabled: _governorate != null,
                    hint: _governorate == null
                        ? 'Select governorate first'
                        : 'Wilayat',
                  ),
                  _field(
                    Icons.swap_horiz_rounded,
                    'Deal type',
                    _dealType,
                    () async {
                      final v =
                          await _pickSpec('Deal type', CarSpecs.dealTypes);
                      if (v != null) setState(() => _dealType = v);
                    },
                  ),
                  _field(
                    Icons.storefront_outlined,
                    'Seller type',
                    _sellerType,
                    () async {
                      final v =
                          await _pickSpec('Seller type', CarSpecs.sellerTypes);
                      if (v != null) setState(() => _sellerType = v);
                    },
                  ),
                  const SizedBox(height: 6),
                  // -------------------------------------- price & details
                  _sectionTitle('PRICE & DETAILS'),
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
                                ? 'Buyers will ask you'
                                : 'Price (OMR)',
                            prefixIcon:
                                const Icon(Icons.payments_outlined),
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
                            'Ask for price',
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
                    decoration: const InputDecoration(
                      hintText: 'Mileage (km)',
                      prefixIcon: Icon(Icons.speed_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Description — condition, options, service history…',
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
                    ? 'Publish ad'
                    : _photos.length < _minPhotos
                        ? 'Add at least $_minPhotos photos'
                        : 'Complete the details above'),
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
              Icon(Icons.verified_user_outlined,
                  size: 18, color: value ? AppColors.brand : AppColors.ink3),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Still under warranty',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
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
