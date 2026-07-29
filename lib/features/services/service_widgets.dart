import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

final _money = intl.NumberFormat('#,##0.##', 'en');

/// A price, with its fractional rials only when it has them.
///
/// The lists used to print `toStringAsFixed(0)`, which was harmless while
/// every published price was a whole number. A discounted price is not: a
/// service reduced to 4.5 rendered as "5", which is a wrong price on a screen
/// the customer books from.
String omrAmount(double value) => _money.format(value);

/// Offerings split by whether their provider sits in the selected [region].
///
/// [local] is what the region filter selects — it is the only group shown
/// unless the user asks to widen the search. [nearby] is everything else,
/// closest-first, so widening reads as "a bit further out" rather than a
/// random national list.
typedef RegionSplit = ({
  List<ServiceOffering> local,
  List<ServiceOffering> nearby,
});

RegionSplit splitByRegion(Iterable<ServiceOffering> offerings, String region) {
  int byPrice(ServiceOffering a, ServiceOffering b) =>
      (a.price ?? 999).compareTo(b.price ?? 999);

  final local = <ServiceOffering>[];
  final nearby = <ServiceOffering>[];
  for (final offering in offerings) {
    (offering.provider.region == region ? local : nearby).add(offering);
  }
  local.sort((a, b) {
    final price = byPrice(a, b);
    return price != 0
        ? price
        : a.provider.distanceKm.compareTo(b.provider.distanceKm);
  });
  nearby.sort((a, b) {
    final distance = a.provider.distanceKm.compareTo(b.provider.distanceKm);
    return distance != 0 ? distance : byPrice(a, b);
  });
  return (local: local, nearby: nearby);
}

void _openCategory(BuildContext context, WidgetRef ref,
    ServiceCategory category) {
  HapticFeedback.selectionClick();
  final region = ref.read(regionProvider);
  final split = splitByRegion(
    ref.read(serviceMarketplaceRepositoryProvider).offeringsFor(category.id),
    region,
  );
  if (split.local.isEmpty && split.nearby.isEmpty) return;
  if (split.local.length == 1 && split.nearby.isEmpty) {
    context.push('/service/${split.local.first.id}');
    return;
  }
  // Multiple workshops offer this — let the user compare.
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final s = S.of(sheetContext);
      final ak = AkColors.of(sheetContext);
      final regionLabel = ref
          .read(locationCatalogProvider)
          .localized(region, s.isAr);
      // With nothing in the selected governorate there is no filter left to
      // honour, so the wider list opens straight away.
      var widened = split.local.isEmpty;
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final shown = widened
              ? [...split.local, ...split.nearby]
              : split.local;
          // Rows are offers; the headline counts the workshops behind them,
          // which is what the chip and the region picker also count.
          final workshops =
              shown.map((o) => o.provider.id).toSet().length;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name.of(s).replaceAll('\n', ' '),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widened
                          ? s.t('${s.workshops(workshops)} في $regionLabel وما حولها',
                              '${s.workshops(workshops)} in and around $regionLabel')
                          : s.t('${s.workshops(workshops)} في $regionLabel',
                              '${s.workshops(workshops)} in $regionLabel'),
                      style: TextStyle(fontSize: 12, color: ak.inkSub),
                    ),
                    // Why this shortlist is shorter than the others: the
                    // category needs a capability, and only some workshops
                    // hold it. Stating it beats looking like missing data.
                    if (category.requires case final capability?) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(capability.icon, size: 14, color: ak.inkSub),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.t(
                                  'تظهر هنا الورش الحاملة لصفة: '
                                      '${capability.label.ar}',
                                  'Only workshops that are '
                                      '${capability.label.en.toLowerCase()} '
                                      'are listed'),
                              style:
                                  TextStyle(fontSize: 11, color: ak.inkSub),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, i) => _ProviderOfferRow(
                          offering: shown[i],
                          cheapest: i == 0 && shown[i].price != null,
                          outsideRegion: shown[i].provider.region != region,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            context.push('/service/${shown[i].id}');
                          },
                        ),
                      ),
                    ),
                    if (split.nearby.isNotEmpty && !widened) ...[
                      const SizedBox(height: 6),
                      WidenSearchButton(
                        workshops: split.nearby
                            .map((o) => o.provider.id)
                            .toSet()
                            .length,
                        regionLabel: regionLabel,
                        onTap: () => setSheetState(() => widened = true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// "Look beyond {region}" call to action — the single, explicit way results
/// from another governorate ever enter a list.
class WidenSearchButton extends StatelessWidget {
  const WidenSearchButton({
    super.key,
    required this.workshops,
    required this.regionLabel,
    required this.onTap,
  });

  /// Distinct workshops that widening would add — not offers, so the number
  /// matches what the region chip and picker count.
  final int workshops;
  final String regionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ak.surfaceDim,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ak.border),
        ),
        child: Row(
          children: [
            Icon(Icons.travel_explore_rounded, size: 18, color: ak.inkSub),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.t('ابحث خارج $regionLabel · ${s.workshops(workshops)} أخرى',
                    'Look beyond $regionLabel · ${s.workshops(workshops)} more'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ak.inkSub,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: ak.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _ProviderOfferRow extends ConsumerWidget {
  const _ProviderOfferRow({
    required this.offering,
    required this.onTap,
    this.cheapest = false,
    this.outsideRegion = false,
  });

  final ServiceOffering offering;
  final VoidCallback onTap;
  final bool cheapest;

  /// Marks a row the region filter did not select, so a widened list still
  /// reads clearly row by row.
  final bool outsideRegion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final locations = ref.watch(locationCatalogProvider);
    final p = offering.provider;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ak.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cheapest ? ak.ink : ak.border,
            width: cheapest ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name.of(s),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (p.verified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified_rounded,
                            size: 14, color: ak.ink),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (outsideRegion) ...[
                        Icon(Icons.explore_outlined,
                            size: 12, color: ak.inkFaint),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          '${locations.localized(p.area, s.isAr)}${s.t('، ', ', ')}${locations.localized(p.region, s.isAr)}'
                          ' · ${p.distanceKm.toStringAsFixed(0)} ${s.km}'
                          '${offering.durationMin != null ? s.t(' · ${offering.durationMin} دقيقة', ' · ${offering.durationMin} min') : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: ak.inkFaint),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      for (final f in p.fulfillments) ...[
                        Icon(f.icon, size: 13, color: ak.inkFaint),
                        const SizedBox(width: 6),
                      ],
                      if (cheapest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ak.successSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            s.t('أفضل سعر', 'Best price'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: ak.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  offering.price != null
                      ? '${s.omr} ${omrAmount(offering.price!)}'
                      : s.t('عرض سعر', 'Quote'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ak.ink,
                  ),
                ),
                // The price above is already the discounted one; this says why
                // it is lower than the workshop's published price, so the row
                // and the service page tell the same story.
                if (ref
                    .watch(serviceMarketplaceRepositoryProvider)
                    .offerFor(offering.id)
                    case final offer?)
                  Text(
                    '${s.omr} ${omrAmount(offer.referencePrice)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: ak.inkFaint,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Big "Car service" package card (reference style) — the first card is
/// brand-filled and can carry a promo ribbon like "FREE OIL".
class ServicePackageCard extends ConsumerWidget {
  const ServicePackageCard({
    super.key,
    required this.category,
    this.filled = false,
    this.height = 150,
  });

  final ServiceCategory category;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    // Scoped to the selected governorate so the card agrees with the chip
    // above it and with the sheet it opens. A category nobody local offers
    // says so rather than quoting a price the user cannot actually book.
    final region = ref.watch(regionProvider);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final providerCount =
        marketplace.providerCountFor(category.id, region: region);
    final local = providerCount > 0;
    final fromPrice = marketplace.fromPriceFor(category.id,
        region: local ? region : null);
    return GestureDetector(
      onTap: () => _openCategory(context, ref, category),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 148,
            height: height,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: filled ? ak.primary : ak.surface,
              borderRadius: BorderRadius.circular(20),
              border:
                  filled ? null : Border.all(color: ak.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(category.icon,
                    size: 22,
                    color: filled
                        ? ak.onPrimary.withValues(alpha: 0.7)
                        : ak.ink),
                const Spacer(),
                // The card is a fixed 148×150, so the two-line title has to
                // be allowed to shrink rather than push past the bottom.
                Flexible(
                  child: Text(
                    category.name.of(s),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: filled ? ak.onPrimary : ak.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (fromPrice != null)
                      s.t('من ${omrAmount(fromPrice)} ${s.omr}',
                          'from ${s.omr} ${omrAmount(fromPrice)}')
                    else if (category.note != null)
                      category.note!.of(s),
                    if (local)
                      s.workshops(providerCount)
                    else
                      s.t('خارج المحافظة', 'outside your area'),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: filled
                        ? ak.onPrimary.withValues(alpha: 0.7)
                        : ak.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          if (category.badge != null)
            PositionedDirectional(
              top: -10,
              end: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ak.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.badge!.of(s),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF1D1B17),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small "Other service" tile — icon that visualises the service + label.
class OtherServiceTile extends ConsumerWidget {
  const OtherServiceTile({super.key, required this.category});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final danger = category.emergency;
    return GestureDetector(
      onTap: () => _openCategory(context, ref, category),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: ak.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: danger ? ak.dangerBorder : ak.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon,
                size: 30, color: danger ? ak.danger : ak.ink),
            const SizedBox(height: 8),
            Text(
              category.name.of(s).replaceAll('\n', ' '),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: danger ? ak.danger : ak.inkSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Car service" + "Other service" rails, shared by Home and Services.
///
/// A third rail carries the electric-car services. It moves to the top when
/// the saved car plugs in — an EV owner's own services should not sit below
/// two rails of engine work — and stays at the bottom, labelled for whom it
/// is, for everyone else.
class ServiceRails extends ConsumerWidget {
  const ServiceRails({super.key, this.packageHeight = 150});

  final double packageHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final primaries = marketplace.primaryCategories;
    final others = marketplace.otherCategories;
    final evCategories = marketplace.evCategories;
    final car = ref.watch(primaryCarProvider);
    final evFirst = car?.plugsIn ?? false;

    final evRail = evCategories.isEmpty
        ? const SizedBox.shrink()
        : _TileRail(
            title: evFirst
                ? s.t('عناية سيارتك الكهربائية', 'Care for your EV')
                : s.t('خدمات السيارات الكهربائية', 'Electric-car services'),
            subtitle: car != null && evFirst
                ? s.t('مخصصة لـ ${car.displayName}',
                    'Picked for your ${car.displayName}')
                : s.t('للسيارات الكهربائية والهجينة القابلة للشحن',
                    'For electric and plug-in hybrid cars'),
            categories: evCategories,
          );

    final packagesRail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(s.t('صيانة السيارات', 'Car service'),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: packageHeight + 4,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: primaries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => ServicePackageCard(
              category: primaries[i],
              filled: i == 0,
              height: packageHeight,
            ),
          ),
        ),
      ],
    );

    final othersRail = _TileRail(
      title: s.t('خدمات أخرى', 'Other services'),
      categories: others,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, section) in (evFirst
                ? [evRail, packagesRail, othersRail]
                : [packagesRail, othersRail, evRail])
            .indexed) ...[
          if (i > 0) const SizedBox(height: 20),
          section,
        ],
      ],
    );
  }
}

/// One horizontal rail of [OtherServiceTile]s under a heading.
class _TileRail extends StatelessWidget {
  const _TileRail({
    required this.title,
    required this.categories,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<ServiceCategory> categories;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              if (subtitle case final line?) ...[
                const SizedBox(height: 2),
                Text(line,
                    style: TextStyle(fontSize: 11.5, color: ak.inkSub)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) =>
                OtherServiceTile(category: categories[i]),
          ),
        ),
      ],
    );
  }
}
