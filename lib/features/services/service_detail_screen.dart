import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// Selected add-ons for the in-flight booking (shared with BookingScreen).
final selectedAddOnsProvider = StateProvider<Set<String>>((ref) => {});

/// Rule 7: service details + the provider's suggested services and parts.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.offeringId});

  final String offeringId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final locations = ref.watch(locationCatalogProvider);
    final offering = marketplace.offeringById(offeringId);
    if (offering == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(s.t('الخدمة غير متاحة', 'Service unavailable'))),
      );
    }
    final provider = offering.provider;
    final car = ref.watch(primaryCarProvider);
    final selected = ref.watch(selectedAddOnsProvider);
    final addOns = marketplace.addOnsFor(provider.id);
    final services = addOns.where((a) => !a.isPart).toList();
    final parts = addOns.where((a) => a.isPart).toList();

    final addOnTotal = addOns
        .where((a) => selected.contains(a.id))
        .fold<double>(0, (sum, a) => sum + a.price);
    final total = (offering.price ?? 0) + addOnTotal;

    return Scaffold(
      appBar: AppBar(title: Text(offering.name.of(s))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const IconTile(Icons.storefront_rounded,
                                radius: 999),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          provider.name.of(s),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w700),
                                        ),
                                      ),
                                      if (provider.verified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified_rounded,
                                            size: 15,
                                            color: AppColors.brand),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '${locations.localized(provider.area, s.isAr)}${s.t('، ', ', ')}${locations.localized(provider.region, s.isAr)} · ${provider.distanceKm} ${s.km}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.ink3),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge.good(s.t('مفتوح', 'Open')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Stat(
                              value: offering.price != null
                                  ? '${s.omr} ${offering.price!.toStringAsFixed(0)}'
                                  : s.t('عرض سعر', 'Quote'),
                              label: offering.price != null
                                  ? s.t('سعر ثابت', 'Fixed price')
                                  : s.t('بعد الفحص', 'After inspection'),
                            ),
                            const SizedBox(width: 8),
                            _Stat(
                              value: offering.durationMin != null
                                  ? s.t('${offering.durationMin} دقيقة',
                                      '${offering.durationMin} min')
                                  : '—',
                              label: s.t('المدة', 'Duration'),
                            ),
                            const SizedBox(width: 8),
                            _Stat(
                              value: car != null
                                  ? s.t('✓ مناسبة', '✓ Fits')
                                  : s.t('أي سيارة', 'Any car'),
                              label: car?.label ??
                                  s.t('اختر عند الحجز', 'Select at booking'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            offering.description.of(s),
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.ink2,
                                height: 1.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionHeader(s.t('أيضاً من هذا المزود',
                        'Also from this provider')),
                    const SizedBox(height: 8),
                    _AddOnRow(addOns: services, selected: selected, ref: ref),
                  ],
                  if (parts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionHeader(s.t('قطع متوفرة لسيارتك',
                        'Parts they stock for your car')),
                    const SizedBox(height: 8),
                    _AddOnRow(addOns: parts, selected: selected, ref: ref),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                onPressed: () {
                  // Rule 4: registration gate before any service request.
                  if (!ensureRegistered(context, ref)) return;
                  context.push('/book/${offering.id}');
                },
                child: Text(
                  offering.price != null
                      ? s.t(
                          'اختر الوقت والمكان — ${total.toStringAsFixed(2)} ر.ع',
                          'Choose time & place — OMR ${total.toStringAsFixed(2)}')
                      : s.t('اطلب فحصاً وعرض سعر',
                          'Request inspection & quote'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 10.5, color: AppColors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOnRow extends StatelessWidget {
  const _AddOnRow({
    required this.addOns,
    required this.selected,
    required this.ref,
  });

  final List<AddOn> addOns;
  final Set<String> selected;
  final WidgetRef ref;

  /// Widest a card may get before a second column is worth having, and the
  /// narrowest it may be squeezed to before the price and the "+ Add" badge
  /// stop fitting on one line.
  static const _gap = 9.0;
  static const _minCardWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    // A provider can stock any number of extras, so the row wraps rather than
    // laying every card side by side — three `Expanded` cards on a phone
    // overflowed, and the count is the API's to decide, not ours.
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits =
            ((constraints.maxWidth + _gap) / (_minCardWidth + _gap)).floor();
        final columns = fits.clamp(1, 2).clamp(1, addOns.length);
        final width =
            (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final a in addOns)
              SizedBox(width: width, child: _card(context, a)),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, AddOn a) {
    final s = S.of(context);
    final isSelected = selected.contains(a.id);
    return AppCard(
      padding: const EdgeInsets.all(11),
      onTap: () {
        final next = Set<String>.from(selected);
        if (!next.add(a.id)) next.remove(a.id);
        ref.read(selectedAddOnsProvider.notifier).state = next;
      },
      border: Border.all(
        color: isSelected ? AppColors.brand : Colors.transparent,
        width: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.name.of(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('+ ${s.omr} ${a.price.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.ink3)),
              ),
              const SizedBox(width: 4),
              isSelected
                  ? StatusBadge.good(s.t('✓ أضيفت', '✓ Added'))
                  : StatusBadge(s.t('+ إضافة', '+ Add')),
            ],
          ),
        ],
      ),
    );
  }
}
