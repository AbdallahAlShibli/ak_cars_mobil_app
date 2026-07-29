import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import 'product_widgets.dart';
import 'shop_filter_sheet.dart';

const _categoryIcons = {
  'filters': Icons.filter_alt_outlined,
  'batteries': Icons.battery_charging_full_rounded,
  'brakes': Icons.album_outlined,
  'tyres': Icons.tire_repair,
  'lights': Icons.lightbulb_outline_rounded,
};

/// Parts shop — pinned search, a real offer banner, category rail, quick
/// availability filters with sort, top-rated rail and a responsive product
/// grid. Tapping a part opens [ProductDetailScreen] at `/shop/product/:id`.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  String _query = '';

  void _openFilters() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ShopFilterSheet(),
    );
  }

  Future<void> _pickSort(ShopFilter filter) async {
    final s = S.of(context);
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<ShopSort>(
      context: context,
      builder: (context) {
        final ak = AkColors.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('الترتيب', 'Sort by'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                for (final option in ShopSort.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option.label(s),
                        style: const TextStyle(fontSize: 13.5)),
                    trailing: option == filter.sort
                        ? Icon(Icons.check_rounded, size: 19, color: ak.ink)
                        : null,
                    onTap: () => Navigator.pop(context, option),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      ref.read(shopFilterProvider.notifier).set(filter.copyWith(sort: picked));
    }
  }

  void _openProduct(BuildContext context, Product product) {
    HapticFeedback.selectionClick();
    context.push('/shop/product/${product.id}');
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final filter = ref.watch(shopFilterProvider);
    final products = ref
        .watch(filteredProductsProvider)
        .where((p) => p.matchesQuery(_query))
        .toList();
    final cart = ref.watch(cartProvider);
    final searching = _query.trim().isNotEmpty;
    final evCar = ref.watch(primaryCarProvider);
    final evShortcut = evCar == null || evCar.plugsIn;

    final topRated = [...ref.watch(productsProvider)]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final offers = ref.watch(offersProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  backgroundColor: ak.bg,
                  surfaceTintColor: Colors.transparent,
                  title: Text(s.t('متجر القطع', 'Parts shop')),
                  actions: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: Badge(
                        isLabelVisible: cart.isNotEmpty,
                        label: Text('${cart.length}'),
                        child: IconButton(
                          icon: const Icon(Icons.shopping_bag_outlined),
                          onPressed: () {
                            if (!ensureRegistered(context, ref)) return;
                            context.push('/cart');
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                // Pinned so the search box stays reachable however far down
                // the grid the user has scrolled.
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchHeader(
                    background: ak.bg,
                    child: _searchRow(filter, s, ak),
                  ),
                ),
                if (!searching) ...[
                  if (offers.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                        child: SectionHeader(
                          s.t('العروض', 'Offers'),
                          action: offers.length > 1
                              ? s.t('كل العروض', 'All offers')
                              : null,
                          onAction: () => ref
                              .read(shopFilterProvider.notifier)
                              .set(filter.copyWith(onOfferOnly: true)),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _OffersCarousel(
                        offers: offers,
                        onOpen: (product) => _openProduct(context, product),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                        height: 84,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _CategoryAvatar(
                              icon: Icons.apps_rounded,
                              label: s.t('الكل', 'All'),
                              selected: filter.categoryId == null,
                              onTap: () => ref
                                  .read(shopFilterProvider.notifier)
                                  .set(filter.copyWith(categoryId: () => null)),
                            ),
                            for (final e
                                in ref.watch(partCategoriesProvider).entries)
                              _CategoryAvatar(
                                icon: _categoryIcons[e.key] ??
                                    Icons.category_outlined,
                                label: e.value.of(s),
                                selected: filter.categoryId == e.key,
                                onTap: () => ref
                                    .read(shopFilterProvider.notifier)
                                    .set(filter.copyWith(
                                        categoryId: () => e.key)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: SectionHeader(s.t('الأعلى تقييماً', 'Top rated')),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        height: 118,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          // Never a hardcoded count: the catalogue size is
                          // the API's to decide.
                          itemCount: topRated.length.clamp(0, 5),
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, i) => _TopRatedCard(
                            product: topRated[i],
                            onTap: () => _openProduct(context, topRated[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // ------------------------------------ shopping-for bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car_outlined,
                              size: 17, color: ak.ink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: s.t('التسوق لـ: ', 'Shopping for: '),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                                children: [
                                  TextSpan(
                                    text: filter.car?.label ??
                                        s.t('أي سيارة', 'Any car'),
                                    style: TextStyle(
                                        color: ak.ink,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _openFilters,
                            child: StatusBadge(s.t('تغيير', 'Change car')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ------------------------------------ quick filters + sort
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // Offered when the saved car plugs in, or when there
                          // is no saved car to filter by (someone shopping
                          // ahead of buying an EV). Shown to a petrol owner it
                          // would only ever produce an empty grid.
                          if (evShortcut) ...[
                            SelectChip(
                              label: s.t('قطع السيارات الكهربائية', 'EV parts'),
                              icon: Icons.electric_bolt_rounded,
                              selected: filter.powertrain != null,
                              onTap: () => ref
                                  .read(shopFilterProvider.notifier)
                                  .set(filter.copyWith(
                                      powertrain: () => filter.powertrain == null
                                          ? (evCar?.powertrain ??
                                              Powertrain.electric)
                                          : null)),
                            ),
                            const SizedBox(width: 7),
                          ],
                          SelectChip(
                            label: s.t('المتوفر الآن', 'In stock'),
                            icon: Icons.inventory_2_outlined,
                            selected: filter.inStockOnly,
                            onTap: () => ref
                                .read(shopFilterProvider.notifier)
                                .set(filter.copyWith(
                                    inStockOnly: !filter.inStockOnly)),
                          ),
                          const SizedBox(width: 7),
                          SelectChip(
                            label: s.t('عليها عرض', 'On offer'),
                            icon: Icons.local_offer_outlined,
                            selected: filter.onOfferOnly,
                            onTap: () => ref
                                .read(shopFilterProvider.notifier)
                                .set(filter.copyWith(
                                    onOfferOnly: !filter.onOfferOnly)),
                          ),
                          const SizedBox(width: 7),
                          SelectChip(
                            label: filter.sort.label(s),
                            icon: Icons.swap_vert_rounded,
                            selected: filter.sort != ShopSort.recommended,
                            onTap: () => _pickSort(filter),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: SectionHeader(
                      searching || filter.activeCount > 0
                          ? s.resultsCount(products.length)
                          : s.t('كل القطع', 'All parts'),
                      action: filter.activeCount > 0
                          ? s.t('مسح الفلاتر', 'Clear filters')
                          : null,
                      onAction: () => ref
                          .read(shopFilterProvider.notifier)
                          .set(ShopFilter(sort: filter.sort)),
                    ),
                  ),
                ),
                if (products.isEmpty)
                  SliverToBoxAdapter(
                    child: _emptyState(searching, filter, s, ak),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      // Max-extent, not a fixed column count: the grid keeps
                      // its card size on a tablet instead of stretching two
                      // cards across the width.
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 230,
                        mainAxisSpacing: 11,
                        crossAxisSpacing: 11,
                        childAspectRatio: 0.66,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Entrance(
                          delayMs: 30 * i,
                          child: _ProductCard(
                            product: products[i],
                            onTap: () => _openProduct(context, products[i]),
                          ),
                        ),
                        childCount: products.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(height: cart.isNotEmpty ? 96 : 28),
                ),
              ],
            ),
            if (cart.isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 14,
                child: const Entrance(child: _CartBar()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchRow(ShopFilter filter, S s, AkColors ak) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: ak.surface,
                hintText: s.t('ابحث بالاسم أو رقم القطعة…',
                    'Search name or part number…'),
                hintStyle: TextStyle(fontSize: 12.5, color: ak.inkFaint),
                prefixIcon: Icon(Icons.search_rounded, size: 19, color: ak.inkSub),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 17, color: ak.inkSub),
                        onPressed: () => setState(() => _query = ''),
                      ),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: ak.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: ak.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: ak.ink, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Badge(
          isLabelVisible: filter.activeCount > 0,
          label: Text('${filter.activeCount}'),
          child: GestureDetector(
            onTap: _openFilters,
            child: IconTile(Icons.tune_rounded,
                size: 46,
                radius: 999,
                background: ak.surface,
                foreground: ak.ink),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(bool searching, ShopFilter filter, S s, AkColors ak) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: ak.inkFaint),
          const SizedBox(height: 10),
          Text(
            searching
                ? s.t('لا نتائج لهذا البحث', 'Nothing matches that search')
                : s.t('لا قطع تطابق هذه الفلاتر',
                    'No parts match these filters'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            searching
                ? s.t('جرّب اسم القطعة أو رقمها أو الماركة.',
                    'Try the part name, its number, or the brand.')
                : s.t('وسّع الفلاتر لعرض المزيد من القطع.',
                    'Widen the filters to see more parts.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: ak.inkSub),
          ),
          if (filter.activeCount > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: FilledButton(
                onPressed: () => ref
                    .read(shopFilterProvider.notifier)
                    .set(ShopFilter(sort: filter.sort)),
                child: Text(s.t('مسح الفلاتر', 'Clear filters')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fixed-height pinned header holding the search row.
class _SearchHeader extends SliverPersistentHeaderDelegate {
  _SearchHeader({required this.child, required this.background});

  final Widget child;
  final Color background;

  static const _height = 62.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SearchHeader old) =>
      old.child != child || old.background != background;
}

/// Offers carousel — one page per part carrying a live discount.
///
/// Every number on a card is read off the part it links to. The banner this
/// replaced read "Up to 15% off batteries · free fitting at partner
/// workshops" no matter what the catalogue contained, and showed one thing at
/// a time; this shows every real offer and lets the customer swipe.
class _OffersCarousel extends StatefulWidget {
  const _OffersCarousel({required this.offers, required this.onOpen});

  final List<Product> offers;
  final void Function(Product product) onOpen;

  @override
  State<_OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends State<_OffersCarousel> {
  static const _height = 138.0;
  static const _advanceAfter = Duration(seconds: 6);

  final _controller = PageController(viewportFraction: 0.9);
  Timer? _advance;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scheduleAdvance();
  }

  /// Rescheduled after each turn rather than run as a periodic timer, so a
  /// swipe restarts the countdown instead of the page jumping out from under
  /// a customer who has just taken control. Cancelled in [dispose], which
  /// also keeps widget tests free of a pending timer.
  void _scheduleAdvance() {
    _advance?.cancel();
    if (widget.offers.length < 2) return;
    _advance = Timer(_advanceAfter, () {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % widget.offers.length,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _advance?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      children: [
        SizedBox(
          height: _height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.offers.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _scheduleAdvance();
            },
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _OfferCard(
                product: widget.offers[i],
                onTap: () => widget.onOpen(widget.offers[i]),
              ),
            ),
          ),
        ),
        if (widget.offers.length > 1) ...[
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.offers.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _page == i ? ak.ink : ak.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One offer page: the discount, the part, and what it costs now.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ak.promoBgA, ak.promoBgB],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ak.promoBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      DiscountBadge(percent: product.discountPercent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          s.t('وفّر ${product.saving.toStringAsFixed(2)} ${s.omr}',
                              'SAVE OMR ${product.saving.toStringAsFixed(2)}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: ak.promoSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    product.name.of(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ak.promoTitle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.t(
                        '${product.price.toStringAsFixed(2)} بدلاً من ${product.oldPrice!.toStringAsFixed(2)} ${s.omr}',
                        'OMR ${product.price.toStringAsFixed(2)} instead of ${product.oldPrice!.toStringAsFixed(2)}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: ak.promoSub),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.t('اعرض القطعة ›', 'View part ›'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: ak.promoTitle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(product.icon, size: 46, color: ak.promoSub),
          ],
        ),
      ),
    );
  }
}

/// Round icon category with label — modern store navigation.
class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
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
        width: 66,
        margin: const EdgeInsetsDirectional.only(end: 6),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? ak.primary : ak.surface,
                shape: BoxShape.circle,
                border: selected ? null : Border.all(color: ak.border),
              ),
              child: Icon(icon,
                  size: 22, color: selected ? ak.onPrimary : ak.inkSub),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? ak.ink : ak.inkSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRatedCard extends StatelessWidget {
  const _TopRatedCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ak.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ak.border),
        ),
        child: Row(
          children: [
            IconTile(product.icon,
                size: 60,
                radius: 14,
                background: ak.surfaceDim,
                foreground: ak.inkSub),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand case final brand?)
                    Text(
                      brand.of(s).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: ak.inkFaint,
                      ),
                    ),
                  Text(product.name.of(s),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  ProductRating(rating: product.rating),
                  const SizedBox(height: 3),
                  ProductPriceLine(product: product, size: 13.5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final inCart = ref.watch(cartProvider).containsKey(product.id);
    final car = ref.watch(shopFilterProvider).car;
    final fits = car != null && product.fitsCar(car);

    return AppCard(
      padding: const EdgeInsets.all(11),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: ak.surfaceDim,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Opacity(
                    opacity: product.inStock ? 1 : 0.4,
                    child: Icon(product.icon, size: 32, color: ak.inkFaint),
                  ),
                ),
                if (product.onOffer)
                  PositionedDirectional(
                    top: 6,
                    start: 6,
                    child: DiscountBadge(percent: product.discountPercent),
                  ),
                if (!product.inStock)
                  PositionedDirectional(
                    bottom: 6,
                    start: 6,
                    child: _Tag(
                      label: s.t('غير متوفرة', 'Out of stock'),
                      background: ak.surface,
                      foreground: ak.inkSub,
                    ),
                  )
                else if (fits)
                  PositionedDirectional(
                    bottom: 6,
                    start: 6,
                    child: _Tag(
                      label: s.t('✓ تناسب سيارتك', '✓ Fits your car'),
                      background: ak.successSoft,
                      foreground: ak.success,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (product.brand case final brand?)
            Text(
              brand.of(s).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: ak.inkFaint,
              ),
            ),
          Text(
            product.name.of(s),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              ProductRating(rating: product.rating),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  product.deliveryDays == 1
                      ? s.t('توصيل خلال يوم', '1-day delivery')
                      : s.t('${product.deliveryDays} أيام',
                          '${product.deliveryDays} days'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: ak.inkFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: ProductPriceLine(product: product, size: 13)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: product.inStock
                    ? () {
                        if (!ensureRegistered(context, ref)) return;
                        HapticFeedback.selectionClick();
                        ref.read(cartProvider.notifier).toggle(product);
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: !product.inStock
                        ? ak.surfaceDim
                        : inCart
                            ? ak.success
                            : ak.surfaceDim,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    !product.inStock
                        ? Icons.block_rounded
                        : inCart
                            ? Icons.check_rounded
                            : Icons.add_rounded,
                    size: 17,
                    color: !product.inStock
                        ? ak.inkFaint
                        : inCart
                            ? Colors.white
                            : ak.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small overlay pill on a product image.
class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

/// Sticky "N items · OMR x" bar over the grid.
class _CartBar extends ConsumerWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final items = ref.watch(cartItemsProvider);
    final total = ref.watch(cartTotalProvider);

    return GestureDetector(
      onTap: () {
        if (!ensureRegistered(context, ref)) return;
        context.push('/cart');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: ak.primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.shopping_bag_rounded, color: ak.onPrimary, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.t('${items.length} قطعة · ${total.toStringAsFixed(2)} ${s.omr}',
                    '${items.length} item${items.length == 1 ? '' : 's'} · OMR ${total.toStringAsFixed(2)}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ak.onPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              s.t('السلة', 'View cart'),
              style: TextStyle(
                color: ak.onPrimary.withValues(alpha: 0.75),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: ak.onPrimary.withValues(alpha: 0.75)),
          ],
        ),
      ),
    );
  }
}
