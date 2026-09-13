import 'package:collection/collection.dart';
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
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import 'service_photo_field.dart';
import 'service_widgets.dart';

/// Services — search across all workshops, "Car service" package cards,
/// "Other services" icon tiles, and popular offerings near you.
///
/// The search field is **pinned**: it scrolls up with the title, then stops at
/// the top of the viewport and stays there. This page is a search page before
/// it is anything else, and the previous layout put the only way to search it
/// above the fold and then let the user scroll it away — so refining a search
/// after reading three results meant scrolling back up to find the box again.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.initialQuery});

  /// Search text to open with (`/services?q=charging`). Lets a shortcut
  /// elsewhere in the app land on results instead of on an empty search box.
  final String? initialQuery;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _search = TextEditingController();
  String _query = '';

  /// Set when a catalogue fetch this screen started came back and the cache is
  /// still cold — i.e. it failed. Distinct from "not warm yet", which is the
  /// ordinary state on the way in and wants a skeleton, not an error.
  bool _loadFailed = false;

  /// The governorate the user explicitly asked to search beyond. Held as a
  /// region rather than a bool so changing the filter resets the widening —
  /// picking a new governorate always starts from "just this one".
  String? _widenedFrom;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery?.trim() ?? '';
    _search.text = _query;
    // Self-healing rather than a fixed timer. The catalogue is normally warmed
    // at bootstrap, so this does nothing on a healthy launch; when that
    // warm-up failed (`SessionRefresh` is best-effort by design and swallows
    // the error) this is the only thing that would ever ask again — and
    // without it the tab showed a permanently empty "nothing matched" page for
    // what was actually a network error.
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmIfCold());
  }

  Future<void> _warmIfCold() async {
    final marketplace = ref.read(serviceMarketplaceRepositoryProvider);
    if (marketplace.isCatalogueWarm) return;
    try {
      await marketplace.warmUp();
      ref.read(warmCacheNoticeProvider).announce();
    } catch (_) {
      // The reason is already logged by the API client; what this screen needs
      // to know is only that asking did not help.
    }
    if (!mounted) return;
    setState(
      () => _loadFailed = !ref
          .read(serviceMarketplaceRepositoryProvider)
          .isCatalogueWarm,
    );
  }

  Future<void> _refresh() async {
    await ref.read(sessionRefreshProvider).refreshVisibleData();
    if (!mounted) return;
    setState(
      () => _loadFailed = !ref
          .read(serviceMarketplaceRepositoryProvider)
          .isCatalogueWarm,
    );
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
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl + AppSpacing.xs,
              ),
              children: [
                // Drag handle — says "this can be swiped away" before a word
                // of the sheet is read.
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
                  s.t('أين تحتاج الخدمة؟', 'Where do you need service?'),
                  style: context.text.screenTitle,
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  s.t(
                    'سنعرض ورش هذه المحافظة فقط',
                    'We\'ll show workshops in this governorate only',
                  ),
                  style: context.text.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final r in regions) ...[
                  _RegionOption(
                    label: locations.localized(r, isAr),
                    workshops: marketplace.providers
                        .where((p) => p.region == r)
                        .length,
                    selected: r == current,
                    onTap: () => Navigator.pop(context, r),
                  ),
                  const SizedBox(height: AppSpacing.itemGap + 1),
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
      // `firstWhereOrNull`, not `firstWhere`: the founder can now delete a
      // service type, and an offering whose category has gone would otherwise
      // throw `StateError` out of a search — taking down the customer's main
      // tab over a catalogue edit. Falling back to an empty name keeps the
      // predicate below unchanged: `q` is non-empty here, so an empty name
      // simply never matches, and the offering is still found by its own name
      // or its workshop's.
      final category =
          marketplace.categories
              .firstWhereOrNull((c) => c.id == o.categoryId)
              ?.name ??
          const L('', '');
      // Place names are searchable in the displayed language too, not just by
      // their canonical English key.
      bool place(String key) =>
          key.toLowerCase().contains(q) ||
          locations.localized(key, isAr).toLowerCase().contains(q);
      return hit(o.name) ||
          hit(o.provider.name) ||
          place(o.provider.region) ||
          place(o.provider.area) ||
          hit(
            L(
              category.ar.replaceAll('\n', ' '),
              category.en.replaceAll('\n', ' '),
            ),
          );
    });
    return splitByRegion(matches, region);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final region = ref.watch(regionProvider);
    final car = ref.watch(primaryCarProvider);
    final searching = _query.trim().isNotEmpty;
    final warm = marketplace.isCatalogueWarm;

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: SandRefresh(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.md,
                  AppSpacing.screenMargin,
                  AppSpacing.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: SandTabHeader(
                    s.navServices,
                    subtitle: s.t(
                      'ابحث، قارن السعر، واحجز — والمبلغ محجوز حتى ترضى',
                      'Search, compare, book — the money is held until you approve',
                    ),
                  ),
                ),
              ),
              // Everything below the title scrolls under this.
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedSearchField(
                  background: ak.bg,
                  field: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md + 1,
                      ),
                      hintText: s.t(
                        'ابحث عن خدمة أو ورشة…',
                        'Search services or workshops…',
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 42,
                        minHeight: 24,
                      ),
                      suffixIcon: searching
                          ? IconButton(
                              tooltip: s.t('مسح البحث', 'Clear search'),
                              icon: const Icon(LucideIcons.x, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 42,
                        minHeight: 24,
                      ),
                    ),
                  ),
                ),
              ),
              if (!warm)
                SliverToBoxAdapter(
                  child: _loadFailed
                      ? _CatalogueUnavailable(onRetry: _refresh)
                      : const _CatalogueSkeleton(),
                )
              else
                ..._resultSlivers(
                  s: s,
                  region: region,
                  car: car,
                  searching: searching,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The page below the search field, once there is a catalogue to draw it
  /// from. Split out only because [build] is otherwise carrying two unrelated
  /// jobs — the chrome, and the results.
  List<Widget> _resultSlivers({
    required S s,
    required String region,
    required Car? car,
    required bool searching,
  }) {
    final results = _results(region);
    final regionLabel = ref
        .watch(locationCatalogProvider)
        .localized(region, s.isAr);
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

    const gutter = EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: gutter,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // The chip carries the count so a short list reads as "this is
              // all there is here", not as a broken page.
              SelectChip(
                label: widened
                    ? s.t('$regionLabel وما حولها', '$regionLabel & around')
                    : '$regionLabel · ${s.workshops(regionWorkshops)}',
                icon: LucideIcons.mapPin,
                selected: true,
                onTap: _pickRegion,
              ),
              // The powertrain rides on this chip because it is what decides
              // which services the list below holds.
              SelectChip(
                // Model + year rather than the full label when a powertrain is
                // shown: a chip cannot ellipsize gracefully inside a Wrap, and
                // "Model Y 2024 · Electric" is the part that matters here.
                label: switch (car) {
                  null => s.t('أضف سيارتك', 'Add your car'),
                  final c when c.powertrain != null =>
                    '${c.model} ${c.year} · ${c.powertrain!.badge.of(s)}',
                  final c => c.label,
                },
                icon: car?.powertrain?.icon ?? LucideIcons.car,
                selected: true,
                onTap: () => context.push(car == null ? '/add-car' : '/garage'),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
      if (!searching && AppFlags.requestPartInstall) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: gutter,
            child: _PartInstallCta(onTap: () => context.push('/request-part')),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
      ],
      if (!searching) ...[
        const SliverToBoxAdapter(child: ServiceRails()),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.sectionGap - 2),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: gutter,
            child: SectionHeader(
              widened
                  ? s.t(
                      'الأكثر طلباً في $regionLabel وما حولها',
                      'Popular in & around $regionLabel',
                    )
                  : s.t(
                      'الأكثر طلباً في $regionLabel',
                      'Popular in $regionLabel',
                    ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.headingGap),
        ),
      ] else ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: gutter,
            child: Text(
              widened
                  ? s.t(
                      '${s.resultsCount(shown.length)} في $regionLabel وما حولها',
                      '${s.resultsCount(shown.length)} in & around $regionLabel',
                    )
                  : s.t(
                      '${s.resultsCount(shown.length)} في $regionLabel',
                      '${s.resultsCount(shown.length)} in $regionLabel',
                    ),
              style: context.text.bodySecondary.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.headingGap),
        ),
      ],
      // Widening was already applied above when the governorate was empty, so
      // this line explains why the list is wider.
      if (widened && results.local.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              0,
              AppSpacing.screenMargin,
              AppSpacing.md,
            ),
            child: _Notice(
              icon: LucideIcons.compass,
              text: searching
                  ? s.t(
                      'لا نتائج في $regionLabel — إليك الأقرب إليها',
                      'Nothing in $regionLabel — here are the closest',
                    )
                  : s.t(
                      'لا توجد ورش في $regionLabel بعد — إليك الأقرب إليها',
                      'No workshops in $regionLabel yet — here are the closest',
                    ),
            ),
          ),
        ),
      if (shown.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: LucideIcons.searchX,
            title: s.t('لا نتائج مطابقة', 'Nothing matched'),
            message: s.t(
              'جرّب كلمة أعمّ، أو وسّع البحث لمحافظة مجاورة — الورش تُضاف تباعاً.',
              'Try a broader word, or widen the search to a neighbouring governorate — workshops are being added all the time.',
            ),
          ),
        )
      else
        SliverPadding(
          padding: gutter,
          sliver: SliverList.separated(
            itemCount: shown.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.itemGap + 2),
            itemBuilder: (context, i) => Entrance(
              delayMs: 35 * i,
              child: _OfferingCard(offering: shown[i], localRegion: region),
            ),
          ),
        ),
      // The one way an out-of-region workshop enters the list — the user
      // asking for it.
      if (!widened && results.nearby.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.md,
              AppSpacing.screenMargin,
              0,
            ),
            child: WidenSearchButton(
              workshops: results.nearby
                  .map((o) => o.provider.id)
                  .toSet()
                  .length,
              regionLabel: regionLabel,
              onTap: () => setState(() => _widenedFrom = region),
            ),
          ),
        ),
      if (_widenedFrom == region)
        SliverToBoxAdapter(
          child: Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _widenedFrom = null),
              icon: const Icon(LucideIcons.funnel, size: 16),
              label: Text(
                s.t('اعرض $regionLabel فقط', 'Show only $regionLabel'),
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
    ];
  }
}

/// Holds the search field at the top of the viewport once the title has
/// scrolled past it.
///
/// A fixed extent in both directions — this header does not shrink, it either
/// scrolls or it is parked.
///
/// [background] is painted opaque behind the field and then **faded out over
/// the last few pixels** rather than stopping at a hard edge. With a hard edge
/// the first line of whatever is scrolling underneath is sliced in half — the
/// top of a card title, the ascenders of a heading — and a half-line of text
/// reads as a rendering fault, not as depth. The fade dissolves it instead.
class _PinnedSearchField extends SliverPersistentHeaderDelegate {
  const _PinnedSearchField({required this.field, required this.background});

  final Widget field;
  final Color background;

  /// Room for the field, plus [_fade] of dissolve underneath it.
  static const _extent = 74.0;

  /// How much of the bottom of the bar is gradient rather than solid.
  static const _fade = 14.0;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    const solid = 1 - _fade / _extent;
    // [SizedBox], not a bare [DecoratedBox]: `layoutChild` passes *loose*
    // constraints, so a child that sizes to its content paints shorter than
    // the extent this delegate declared — which trips
    // `SliverGeometry.debugAssertIsValid` ("layoutExtent exceeds paintExtent").
    // The old `Container(alignment:)` filled the box for free; this has to say
    // so, and the [Align] keeps the field itself loosely sized inside it.
    return SizedBox(
      height: _extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [background, background, background.withValues(alpha: 0)],
            stops: const [0, solid, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            _fade + AppSpacing.xs,
          ),
          child: Align(alignment: Alignment.topCenter, child: field),
        ),
      ),
    );
  }

  // The field carries a live controller and closes over screen state, so there
  // is nothing cheap to compare here — and nothing gained by trying.
  @override
  bool shouldRebuild(_PinnedSearchField old) => true;
}

/// The catalogue has not arrived yet. Shaped like the page it stands in for —
/// a rail of package cards, then a run of offering rows — so the layout does
/// not jump when the real thing lands.
class _CatalogueSkeleton extends StatelessWidget {
  const _CatalogueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                const Expanded(child: Skeleton(height: 150, radius: 20)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Skeleton(height: 96, radius: 16),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 4; i++) ...[
            const Skeleton(height: 72, radius: 20),
            const SizedBox(height: AppSpacing.itemGap + 2),
          ],
        ],
      ),
    );
  }
}

/// The catalogue was asked for and did not come back. An honest error beats
/// "nothing matched", which blames the search for a network failure.
class _CatalogueUnavailable extends StatelessWidget {
  const _CatalogueUnavailable({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return EmptyState(
      icon: LucideIcons.cloudOff,
      title: s.t('تعذّر تحميل الخدمات', 'Couldn\'t load services'),
      message: s.t(
        'تحقّق من اتصالك وحاول مرة أخرى — لم نتمكّن من قراءة قائمة الورش والخدمات.',
        'Check your connection and try again — we could not read the list of workshops and services.',
      ),
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(LucideIcons.refreshCw, size: 16),
        label: Text(s.t('إعادة المحاولة', 'Retry')),
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
    // Nullable for the same reason as the search above — a deleted type must
    // degrade this card's glyph, not take the tab down.
    final category = ref
        .watch(serviceMarketplaceRepositoryProvider)
        .categories
        .firstWhereOrNull((c) => c.id == offering.categoryId);
    final local = offering.provider.region == localRegion;

    return AppCard(
      onTap: () => context.push('/service/${offering.id}'),
      child: Row(
        children: [
          // A workshop's own photo for this service outranks the generic
          // category glyph once one exists — it is the more specific answer
          // to "what am I booking".
          offering.photo != null
              ? OfferingPhotoThumb(photo: offering.photo, size: 42, radius: 14)
              : IconTile(
                  category?.icon ?? LucideIcons.wrench,
                  background: (category?.emergency ?? false)
                      ? ak.dangerSoft
                      : ak.surfaceDim,
                  foreground: (category?.emergency ?? false)
                      ? ak.danger
                      : ak.ink,
                ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        offering.name.of(s),
                        overflow: TextOverflow.ellipsis,
                        // §2: the *service name* is body rank. It is the
                        // same on every card in the list; the price beside
                        // it is what the customer is actually comparing, so
                        // the price outweighs it rather than matching it.
                        style: context.text.bodyPrimary.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                  style: context.text.bodySecondary.copyWith(
                    color: ak.inkFaint,
                  ),
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
                      style: context.text.bodySecondary.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
              const SizedBox(height: AppSpacing.xs),
              // Distance is the honest version of "near you" once results can
              // come from further out.
              if (local)
                StatusBadge.good(
                  '${offering.provider.distanceKm.toStringAsFixed(0)} ${s.km}',
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.compass, size: 12, color: ak.inkFaint),
                    const SizedBox(width: AppSpacing.xs - 1),
                    Text(
                      '${offering.provider.distanceKm.toStringAsFixed(0)} ${s.km}',
                      style: context.text.bodySecondary.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ak.inkFaint,
                      ),
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
          IconTile(
            LucideIcons.wrench,
            background: ak.primary.withValues(alpha: 0.12),
            foreground: ak.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'تحتاج قطعة؟ اطلبها مع التركيب',
                    'Need a part? Ask for it fitted',
                  ),
                  style: context.text.bodyPrimary.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  s.t(
                    'صف القطعة، وتردّ الورشة بسعر القطعة وأجرة التركيب منفصلين.',
                    'Describe it and the workshop replies with the part and the fitting priced separately.',
                  ),
                  style: context.text.bodySecondary.copyWith(height: 1.5),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ak.inkSub),
          const SizedBox(width: AppSpacing.sm + 1),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySecondary.copyWith(height: 1.4),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg - 2,
          vertical: AppSpacing.md + 1,
        ),
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
              selected ? LucideIcons.circleCheck : LucideIcons.mapPin,
              size: 18,
              color: selected ? ak.ink : ak.inkFaint,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                label,
                style: context.text.bodyPrimary.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              s.workshops(workshops),
              style: context.text.bodySecondary.copyWith(
                fontWeight: FontWeight.w600,
                color: ak.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
