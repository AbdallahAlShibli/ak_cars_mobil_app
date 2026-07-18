import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/car_catalog.dart';
import '../../data/gallery_data.dart';
import '../../data/oman_locations.dart';

/// Post a car ad — popup pickers (same UX as add-car), price or
/// "ask for price", mileage, description. Publishes into the gallery feed.
class PostAdScreen extends ConsumerStatefulWidget {
  const PostAdScreen({super.key});

  @override
  ConsumerState<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends ConsumerState<PostAdScreen> {
  CarMake? _make;
  String? _model;
  int? _year;
  String? _governorate;
  String? _wilayat;
  bool _askForPrice = false;

  final _price = TextEditingController();
  final _mileage = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    _mileage.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _canPublish =>
      _make != null &&
      _model != null &&
      _year != null &&
      _governorate != null &&
      _wilayat != null &&
      (_askForPrice || _price.text.trim().isNotEmpty);

  void _publish() {
    if (!_canPublish) return;
    final profile = ref.read(authProvider).profile;
    final ad = GalleryListing(
      id: 'my-${DateTime.now().millisecondsSinceEpoch}',
      make: _make!.name,
      model: _model!,
      trim: '',
      year: _year!,
      price: _askForPrice ? null : double.tryParse(_price.text.trim()),
      mileage: _mileage.text.trim().isEmpty ? '—' : _mileage.text.trim(),
      bodyType: 'Sedan',
      cylinders: 4,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      specGrade: 'First grade',
      keys: 2,
      exteriorColor: 'White',
      exteriorSwatch: const Color(0xFFF3F4F6),
      interiorColor: 'Black',
      interiorSwatch: const Color(0xFF17181A),
      region: '$_wilayat, $_governorate',
      postedMinutesAgo: 0,
      dealType: 'Sale only',
      photoCount: 1,
      icon: Icons.directions_car_filled_rounded,
      tint: const Color(0xFF41536B),
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

  Future<T?> _pickFromList<T>(
      String title, List<T> options, String Function(T) label) {
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
                        child: Text(label(options[i]),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
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

  Widget _field(IconData icon, String label, String? value,
      VoidCallback onTap,
      {bool enabled = true, String? hint}) {
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
                Icon(icon,
                    size: 18,
                    color: filled ? AppColors.brand : AppColors.ink3),
                const SizedBox(width: 10),
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
                    color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ),
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
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 9),
                        Expanded(
                          child: Container(
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.border,
                                  width: i == 0 ? 1 : 1),
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                    i == 0
                                        ? Icons.add_a_photo_outlined
                                        : Icons.image_outlined,
                                    size: 20,
                                    color: AppColors.ink3),
                                const SizedBox(height: 4),
                                Text(i == 0 ? 'Add photos' : 'Photo',
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.ink3,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Photo upload connects to storage in Phase 4.',
                    style: TextStyle(fontSize: 11, color: AppColors.ink3),
                  ),
                  const SizedBox(height: 14),
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
                      if (m != null) setState(() => _model = m);
                    },
                    enabled: _make != null,
                    hint: _make == null ? 'Select make first' : 'Model',
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
                    : 'Complete the details above'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
