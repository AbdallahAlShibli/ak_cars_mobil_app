import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import 'service_widgets.dart';

/// Services — search across all workshops, "Car service" package cards,
/// "Other services" icon tiles, and popular offerings near you.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.initialQuery});

  /// Search text to open with (`/services?q=charging`). Lets a shortcut
  /// elsewhere in the app land on results instead of on an empty search box.
  final String? initialQuery;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  bool _loading = true;
  final _search = TextEditingController();
  String _query = '';

  /// The governorate the user explicitly asked to search beyond. Held as a
  /// region rather than a bool so changing the filter resets the widening —
  /// picking a new governorate always starts from "just this one".
  String? _widenedFrom;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery?.trim() ?? '';
    _search.text = _query;
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRegion() async {
    final locations = ref.read(locationCatalogProvider);
    final isAr = S.of(context).isAr;
    final marketplace = ref.read(serviceMarketplaceRepositoryProvider);
    // Only governorates the marketplace actually serves — offering an empty
    // one would leave the user with a filter that can never match.
    final regions = marketplace.providerRegions;
    final current = ref.read(regionProvider);
    final region = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final s = S.of(context);
        final ak = AkColors.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Text(
                  s.t('أين تحتاج الخدمة؟', 'Where do you need service?'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  s.t('سنعرض ورش هذه المحافظة فقط',
                      'We\'ll show workshops in this governorate only'),
                  style: TextStyle(fontSize: 12, color: ak.inkSub),
                ),
                const SizedBox(height: 14),
                for (final r in regions) ...[
                  _RegionOption(
                    label: locations.localized(r, isAr),
                    workshops: marketplace.providers
                        .where((p) => p.region == r)
                        .length,
                    selected: r == current,
                    onTap: () => Navigator.pop(context, r),
                  ),
                  const SizedBox(height: 9),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (region != null && region != ref.read(regionProvider)) {
      ref.read(regionProvider.notifier).state = region;
      // A new filter starts narrow again.
      setState(() => _widenedFrom = null);
    }
  }

  /// Offerings matching the search box, split into the selected [region] and
  /// the wider country. Only the first group is shown until the user taps
  /// "Look beyond", so the chip always describes what is on screen.
  ///
  /// Unsearched, the shortlist holds only what the saved car can actually be
  /// booked in for — a petrol owner has no use for a high-voltage battery
  /// diagnostic, and an EV owner should see theirs. A typed query overrides
  /// that: an explicit search outranks personalisation, so someone shopping
  /// for their next car still finds every service.
  RegionSplit _results(String region) {
    final q = _query.trim().toLowerCase();
    final isAr = S.of(context).isAr;
    final locations = ref.read(locationCatalogProvider);
    bool hit(L text) =>
        text.ar.contains(q) || text.en.toLowerCase().contains(q);
    final marketplace = ref.read(serviceMarketplaceRepositoryProvider);
    final powertrain = ref.read(primaryPowertrainProvider);
    final bookable = {
      for (final c in marketplace.categoriesFor(powertrain)) c.id,
    };
    final matches = marketplace.pricedOfferings.where((o) {
      if (q.isEmpty) return bookable.contains(o.categoryId);
      final category = marketplace.categories
          .firstWhere((c) => c.id == o.categoryId)
          .name;
      // Place names are searchable in the displayed language too, not just by
      // their canonical English key.
      bool place(String key) =>
          key.toLowerCase().contains(q) ||
          locations.localized(key, isAr).toLowerCase().contains(q);
      return hit(o.name) ||
          hit(o.provider.name) ||
          place(o.provider.region) ||
          place(o.provider.area) ||
          hit(L(category.ar.replaceAll('\n', ' '),
              category.en.replaceAll('\n', ' ')));
    });
    return splitByRegion(matches, region);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final region = ref.watch(regionProvider);
    final car = ref.watch(primaryCarProvider);
    final searching = _query.trim().isNotEmpty;
    final results = _results(region);
    final regionLabel =
        ref.watch(locationCatalogProvider).localized(region, s.isAr);
    // Nothing in the selected governorate leaves no filter to honour, so the
    // wider list opens on its own rather than showing a dead end.
    final widened = _widenedFrom == region || results.local.isEmpty;
    // The chip counts workshops in the governorate, matching the picker —
    // not the offers below it, which are a longer list.
    final regionWorkshops = ref
        .watch(serviceMarketplaceRepositoryProvider)
        .providers
        .where((p) => p.region == region)
        .length;
    // Unsearched, the page is a shortlist; searching shows the full set.
    final limit = searching ? 25 : 6;
    // Each group is capped on its own. Capping the combined list instead let
    // a governorate with a full shortlist swallow every result from beyond
    // it, so "Look beyond" changed the header and nothing else.
    final shown = [
      ...results.local.take(limit),
      if (widened) ...results.nearby.take(searching ? limit : 4),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.navServices)),
      body: SafeArea(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  const Skeleton(height: 48, radius: 16),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        const Expanded(
                            child: Skeleton(height: 150, radius: 20)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Skeleton(height: 96, radius: 16),
                  const SizedBox(height: 16),
                  for (var i = 0; i < 3; i++) ...[
                    const Skeleton(height: 72, radius: 20),
                    const SizedBox(height: 10),
                  ],
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: s.t('ابحث عن خدمة أو ورشة…',
                            'Search services or workshops…'),
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        suffixIcon: searching
                            ? IconButton(
                                icon: const Icon(LucideIcons.x,
                                    size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        // The chip carries the count so a short list reads as
                        // "this is all there is here", not as a broken page.
                        SelectChip(
                          label: widened
                              ? s.t('$regionLabel وما حولها',
                                  '$regionLabel & around')
                              : '$regionLabel · ${s.workshops(regionWorkshops)}',
                          icon: LucideIcons.mapPin,
                          selected: true,
                          onTap: _pickRegion,
                        ),
                        // The powertrain rides on this chip because it is what
                        // decides which services the list below holds.
                        SelectChip(
                          // Model + year rather than the full label when a
                          // powertrain is shown: a chip cannot ellipsize
                          // gracefully inside a Wrap, and "Model Y 2024 ·
                          // Electric" is the part that matters here.
                          label: switch (car) {
                            null => s.t('أضف سيارتك', 'Add your car'),
                            final c when c.powertrain != null =>
                              '${c.model} ${c.year} · ${c.powertrain!.badge.of(s)}',
                            final c => c.label,
                          },
                          icon: car?.powertrain?.icon ??
                              LucideIcons.car,
                          selected: true,
                          onTap: () => context
                              .push(car == null ? '/add-car' : '/garage'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!searching && AppFlags.requestPartInstall) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _PartInstallCta(
                        onTap: () => context.push('/request-part'),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (!searching) ...[
                    const ServiceRails(),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SectionHeader(widened
                          ? s.t('الأكثر طلباً في $regionLabel وما حولها',
                              'Popular in & around $regionLabel')
                          : s.t('الأكثر طلباً في $regionLabel',
                              'Popular in $regionLabel')),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widened
                            ? s.t(
                                '${s.resultsCount(shown.length)} في $regionLabel وما حولها',
                                '${s.resultsCount(shown.length)} in & around $regionLabel')
                            : s.t(
                                '${s.resultsCount(shown.length)} في $regionLabel',
                                '${s.resultsCount(shown.length)} in $regionLabel'),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AkColors.of(context).inkSub),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Widening was already applied above when the governorate
                  // was empty, so this line explains why the list is wider.
                  if (widened && results.local.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _Notice(
                        icon: LucideIcons.compass,
                        text: searching
                            ? s.t(
                                'لا نتائج في $regionLabel — إليك الأقرب إليها',
                                'Nothing in $regionLabel — here are the closest')
                            : s.t(
                                'لا توجد ورش في $regionLabel بعد — إليك الأقرب إليها',
                                'No workshops in $regionLabel yet — here are the closest'),
                      ),
                    ),
                  if (shown.isEmpty)
                    EmptyState(
                      icon: LucideIcons.searchX,
                      title: s.t('لا نتائج مطابقة', 'Nothing matched'),
                      message: s.t(
                        'جرّب كلمة أعمّ، أو وسّع البحث لمحافظة مجاورة — الورش تُضاف تباعاً.',
                        'Try a broader word, or widen the search to a neighbouring governorate — workshops are being added all the time.',
                      ),
                    )
                  else
                    for (final (i, o) in shown.indexed) ...[
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: Entrance(
                          delayMs: 35 * i,
                          child: _OfferingCard(
                              offering: o, localRegion: region),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  // The one way an out-of-region workshop enters the list —
                  // the user asking for it.
                  if (!widened && results.nearby.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: WidenSearchButton(
                        workshops: results.nearby
                            .map((o) => o.provider.id)
                            .toSet()
                            .length,
                        regionLabel: regionLabel,
                        onTap: () =>
                            setState(() => _widenedFrom = region),
                      ),
                    ),
                  ],
                  if (_widenedFrom == region) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _widenedFrom = null),
                        icon: const Icon(LucideIcons.funnel, size: 16),
                        label: Text(s.t('اعرض $regionLabel فقط',
                            'Show only $regionLabel')),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _OfferingCard extends ConsumerWidget {
  const _OfferingCard({required this.offering, required this.localRegion});

  final ServiceOffering offering;
  final String localRegion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final locations = ref.watch(locationCatalogProvider);
    final category = ref
        .watch(serviceMarketplaceRepositoryProvider)
        .categories
        .firstWhere((c) => c.id == offering.categoryId);
    final local = offering.provider.region == localRegion;

    return AppCard(
      onTap: () => context.push('/service/${offering.id}'),
      child: Row(
        children: [
          IconTile(category.icon,
              background:
                  category.emergency ? ak.dangerSoft : ak.surfaceDim,
              foreground:
                  category.emergency ? ak.danger : ak.ink),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(offering.name.of(s),
                          overflow: TextOverflow.ellipsis,
                          // §2: the *service name* is body rank. It is the
                          // same on every card in the list; the price beside
                          // it is what the customer is actually comparing, so
                          // the price outweighs it rather than matching it.
                          style: context.text.bodyPrimary
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                    if (offering.provider.verified) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(LucideIcons.badgeCheck, size: 13, color: ak.ink),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  '${offering.provider.name.of(s)} · ${locations.localized(offering.provider.area, s.isAr)}'
                  '${local ? '' : ' · ${locations.localized(offering.provider.region, s.isAr)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySecondary
                      .copyWith(color: ak.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              offering.price != null
                  ? RialAmount.formatted(
                      omrAmount(offering.price!),
                      style: context.text.price,
                    )
                  : Text(
                      s.t('عرض سعر', 'Quote'),
                      style: context.text.bodySecondary
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
              const SizedBox(height: AppSpacing.xs),
              // Distance is the honest version of "near you" once results can
              // come from further out.
              if (local)
                StatusBadge.good(
                    '${offering.provider.distanceKm.toStringAsFixed(0)} ${s.km}')
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.compass, size: 11, color: ak.inkFaint),
                    const SizedBox(width: AppSpacing.xs - 1),
                    Text(
                      '${offering.provider.distanceKm.toStringAsFixed(0)} ${s.km}',
                      style: context.text.bodySecondary.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ak.inkFaint),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The way into "request a part + fitting" (spec §6).
///
/// It sits on the services tab rather than in a shop, because that is what it
/// is: work a workshop does, priced by that workshop. Nothing here browses a
/// catalogue — there isn't one — and the copy says so instead of implying a
/// parts store that this build does not run.
class _PartInstallCta extends StatelessWidget {
  const _PartInstallCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return AppCard(
      onTap: onTap,
      color: ak.surfaceDim,
      child: Row(
        children: [
          IconTile(LucideIcons.wrench,
              background: ak.primary.withValues(alpha: 0.12),
              foreground: ak.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('تحتاج قطعة؟ اطلبها مع التركيب',
                      'Need a part? Ask for it fitted'),
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  s.t('صف القطعة، وتردّ الورشة بسعر القطعة وأجرة التركيب منفصلين.',
                      'Describe it and the workshop replies with the part and the fitting priced separately.'),
                  style: TextStyle(
                      fontSize: 11.5, height: 1.5, color: ak.inkSub),
                ),
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevronLeft
                : LucideIcons.chevronRight,
            size: 18,
            color: ak.inkFaint,
          ),
        ],
      ),
    );
  }
}

/// Quiet inline explainer — used when the page had to widen the search on the
/// user's behalf, so the wider list never arrives unannounced.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ak.inkSub),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12, height: 1.35, color: ak.inkSub),
            ),
          ),
        ],
      ),
    );
  }
}

/// One governorate in the region picker, with the workshop count up front so
/// the choice is informed before it is made.
class _RegionOption extends StatelessWidget {
  const _RegionOption({
    required this.label,
    required this.workshops,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int workshops;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? ak.surfaceDim : ak.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? ak.ink : ak.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
                selected
                    ? LucideIcons.circleCheck
                    : LucideIcons.mapPin,
                size: 18,
                color: selected ? ak.ink : ak.inkFaint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              s.workshops(workshops),
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: ak.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
