import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import 'shop_filter_sheet.dart';

const _categoryIcons = {
  'filters': Icons.filter_alt_outlined,
  'batteries': Icons.battery_charging_full_rounded,
  'brakes': Icons.album_outlined,
  'tyres': Icons.tire_repair,
  'lights': Icons.lightbulb_outline_rounded,
};

/// Parts shop — 2026 e-commerce patterns: promo banner, icon categories,
/// best-sellers rail, bento product grid, product sheet, sticky cart bar.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final filter = ref.watch(shopFilterProvider);
    final q = _query.trim().toLowerCase();
    final products = ref
        .watch(filteredProductsProvider)
        .where((p) =>
            q.isEmpty ||
            p.name.ar.contains(q) ||
            p.name.en.toLowerCase().contains(q))
        .toList();
    final cart = ref.watch(cartProvider);
    final cartItems = ref.watch(cartItemsProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final searching = _query.trim().isNotEmpty;

    final bestSellers = [...ref.watch(productsProvider)]
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return Scaffold(
      appBar: AppBar(
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
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.only(
                  top: 4, bottom: cart.isNotEmpty ? 92 : 24),
              children: [
                // ------------------------------------ search + filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: s.t('ابحث عن قطعة…', 'Search parts…'),
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(
                                  color: ak.border, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(
                                  color: ak.border, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Badge(
                        isLabelVisible: filter.activeCount > 0,
                        label: Text('${filter.activeCount}'),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => const ShopFilterSheet(),
                            );
                          },
                          child: const IconTile(Icons.tune_rounded,
                              size: 48, radius: 999),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!searching) ...[
                  // ------------------------------------ promo banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () => ref
                          .read(shopFilterProvider.notifier)
                          .set(filter.copyWith(
                              categoryId: () => 'batteries')),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.sunsetGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amber
                                  .withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.16),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      s.t('هذا الأسبوع', 'THIS WEEK'),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    s.t('خصم حتى 15% على البطاريات',
                                        'Up to 15% off batteries'),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    s.t('تركيب مجاني في الورش الشريكة',
                                        'Free fitting at partner workshops'),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.battery_charging_full_rounded,
                                size: 52, color: Colors.white54),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // ------------------------------------ icon categories
                  SizedBox(
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
                              .set(filter.copyWith(
                                  categoryId: () => null)),
                        ),
                        for (final e in ref.watch(partCategoriesProvider).entries)
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
                  const SizedBox(height: 16),
                  // ------------------------------------ best sellers
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SectionHeader(s.t('الأكثر مبيعاً', 'Best sellers')),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 3,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) => _BestSellerCard(
                          product: bestSellers[i],
                          onTap: () =>
                              _openProduct(context, bestSellers[i])),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                // ------------------------------------ shopping-for bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
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
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const ShopFilterSheet(),
                          ),
                          child: StatusBadge(s.t('تغيير', 'Change car')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SectionHeader(searching
                      ? s.t('${products.length} نتيجة', '${products.length} results')
                      : s.t('كل القطع', 'All parts')),
                ),
                const SizedBox(height: 10),
                if (products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 40, color: ak.inkFaint),
                          const SizedBox(height: 8),
                          Text(
                              s.t('لا قطع تطابق هذه الفلاتر',
                                  'No parts match these filters'),
                              style: TextStyle(
                                  fontSize: 13, color: ak.inkSub)),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 11,
                        crossAxisSpacing: 11,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, i) => Entrance(
                        delayMs: 30 * i,
                        child: _ProductCard(
                          product: products[i],
                          onTap: () =>
                              _openProduct(context, products[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // ------------------------------------ sticky cart bar
            if (cart.isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 14,
                child: Entrance(
                  child: GestureDetector(
                    onTap: () {
                      if (!ensureRegistered(context, ref)) return;
                      context.push('/cart');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 15),
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
                          Icon(Icons.shopping_bag_rounded,
                              color: ak.onPrimary, size: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.t(
                                  '${cartItems.length} قطعة · ${cartTotal.toStringAsFixed(2)} ${s.omr}',
                                  '${cartItems.length} item${cartItems.length == 1 ? '' : 's'} · OMR ${cartTotal.toStringAsFixed(2)}'),
                              style: TextStyle(
                                color: ak.onPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            s.t('عرض السلة', 'View cart'),
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
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openProduct(BuildContext context, Product product) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductSheet(product: product),
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
                border:
                    selected ? null : Border.all(color: ak.border),
              ),
              child: Icon(icon,
                  size: 22,
                  color: selected ? ak.onPrimary : ak.inkSub),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight:
                    selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? ak.ink : ak.inkSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestSellerCard extends StatelessWidget {
  const _BestSellerCard({required this.product, required this.onTap});

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
                  Text(product.name.of(s),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _Rating(rating: product.rating),
                  const SizedBox(height: 4),
                  _PriceLine(product: product, size: 13.5),
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
                  child:
                      Icon(product.icon, size: 32, color: ak.inkFaint),
                ),
                if (product.onOffer)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        // Amber, not red — red is reserved for SOS.
                        color: ak.amber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '-${(100 - product.price / product.oldPrice! * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D1B17),
                        ),
                      ),
                    ),
                  ),
                if (fits)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: ak.successSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s.t('✓ تناسب سيارتك', '✓ Fits your car'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: ak.success,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name.of(s),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          _Rating(rating: product.rating),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _PriceLine(product: product, size: 13)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  if (!ensureRegistered(context, ref)) return;
                  HapticFeedback.selectionClick();
                  ref.read(cartProvider.notifier).toggle(product);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: inCart ? ak.success : ak.surfaceDim,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    inCart ? Icons.check_rounded : Icons.add_rounded,
                    size: 17,
                    color: inCart ? Colors.white : ak.ink,
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

/// Product detail sheet — image carousel, full details, provider card
/// with contact actions, quantity stepper and add-to-cart.
class _ProductSheet extends ConsumerStatefulWidget {
  const _ProductSheet({required this.product});

  final Product product;

  @override
  ConsumerState<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<_ProductSheet> {
  int _qty = 1;
  int _photo = 0;
  final _photos = PageController();

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final p = widget.product;
    final provider = ref
        .watch(shopSellersProvider)
        .where((x) => x.id == p.providerId)
        .firstOrNull;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                children: [
                  // ---------------------------------- image carousel
                  Stack(
                    children: [
                      Container(
                        height: 190,
                        decoration: BoxDecoration(
                          color: ak.surfaceDim,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: PageView.builder(
                          controller: _photos,
                          itemCount: p.photoCount,
                          onPageChanged: (i) =>
                              setState(() => _photo = i),
                          itemBuilder: (context, i) => Center(
                            child: Icon(
                              i == 0 ? p.icon : Icons.photo_outlined,
                              size: 64,
                              color: ak.inkFaint,
                            ),
                          ),
                        ),
                      ),
                      if (p.onOffer)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              // Amber, not red — red is reserved for SOS.
                              color: ak.amber,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '-${(100 - p.price / p.oldPrice! * 100).round()}% OFF',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1D1B17),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < p.photoCount; i++)
                              AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 3),
                                width: _photo == i ? 18 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _photo == i
                                      ? ak.ink
                                      : ak.surface,
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ---------------------------------- name + rating
                  Text(p.name.of(s),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _Rating(rating: p.rating),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.fits.contains('any')
                              ? ak.surfaceDim
                              : ak.successSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          p.fits.contains('any')
                              ? s.t('تناسب كل السيارات', 'Universal fit')
                              : s.t('تناسب: ${p.fits.join('، ')}',
                                  'Fits: ${p.fits.join(', ')}'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: p.fits.contains('any')
                                ? ak.ink
                                : ak.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    p.details(s),
                    style: TextStyle(
                        fontSize: 12.5,
                        color: ak.inkSub,
                        height: 1.55),
                  ),
                  const SizedBox(height: 14),
                  // ---------------------------------- provider card
                  if (provider != null)
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: ak.surfaceDim,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const IconTile(Icons.storefront_rounded,
                                  size: 42, radius: 999),
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
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight:
                                                    FontWeight.w700),
                                          ),
                                        ),
                                        if (provider.verified) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                              Icons.verified_rounded,
                                              size: 14,
                                              color: ak.ink),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${provider.area}, ${provider.region} · ${provider.distanceKm} km',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: ak.inkFaint),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize:
                                        const Size.fromHeight(42),
                                    backgroundColor: ak.surface,
                                  ),
                                  onPressed: () => Contact.call(
                                      context, '+96824000000'),
                                  icon: const Icon(Icons.phone_outlined,
                                      size: 15),
                                  label: Text(s.t('اتصل', 'Call'),
                                      style: const TextStyle(fontSize: 12.5)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    minimumSize:
                                        const Size.fromHeight(42),
                                    backgroundColor:
                                        const Color(0xFF25A55A),
                                  ),
                                  onPressed: () => Contact.whatsapp(
                                    context,
                                    '96892000000',
                                    message: s.t(
                                        'مرحباً، أستفسر عن "${p.name.ar}" في متجر AK Cars.',
                                        'Hi, I am asking about "${p.name.en}" on AK Cars shop.'),
                                  ),
                                  icon: const Icon(Icons.chat_rounded,
                                      size: 15),
                                  label: Text(s.t('واتساب', 'WhatsApp'),
                                      style: const TextStyle(fontSize: 12.5)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // ---------------------------------- price + qty + CTA
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: ak.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _PriceLine(product: p, size: 18),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: ak.surfaceDim,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove_rounded,
                                  size: 18),
                              onPressed: _qty > 1
                                  ? () => setState(() => _qty--)
                                  : null,
                            ),
                            Text('$_qty',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon:
                                  const Icon(Icons.add_rounded, size: 18),
                              onPressed: () => setState(() => _qty++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      if (!ensureRegistered(context, ref)) return;
                      HapticFeedback.mediumImpact();
                      ref.read(cartProvider.notifier).setQty(p.id, _qty);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.shopping_bag_outlined,
                        size: 17),
                    label: Text(s.t(
                        'أضف $_qty للسلة — ${(p.price * _qty).toStringAsFixed(2)} ${s.omr}',
                        'Add $_qty to cart — OMR ${(p.price * _qty).toStringAsFixed(2)}')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 13, color: ak.amber),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: ak.inkSub),
        ),
      ],
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.product, required this.size});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            'OMR ${product.price.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: ak.ink,
            ),
          ),
        ),
        if (product.onOffer) ...[
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              product.oldPrice!.toStringAsFixed(2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: size - 3,
                color: ak.inkFaint,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
