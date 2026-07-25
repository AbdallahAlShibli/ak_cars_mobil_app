import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../services/provider_details_card.dart';
import 'product_widgets.dart';
import 'shop_filter_sheet.dart';

/// Parts product page.
///
/// Replaces the old half-height bottom sheet. A parts buyer decides on four
/// things — does it fit, is it the right part number, who is selling it, and
/// when does it arrive — and a sheet had room for none of them. The order of
/// the sections below is that decision order: fitment first, then identity
/// (brand / part number / specs), then the shop, then price and delivery.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _photos = PageController();
  int _photo = 0;
  int _qty = 1;
  bool _specsExpanded = false;

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  void _copy(String value, String confirmation) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(confirmation)));
  }

  /// Sends the buyer back to the shop with this seller's parts filtered in.
  void _showAllFromShop(ServiceProvider provider) {
    final filter = ref.read(shopFilterProvider);
    ref
        .read(shopFilterProvider.notifier)
        .set(filter.copyWith(providerId: () => provider.id));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/shop');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final product = ref
        .watch(productsProvider)
        .firstWhereOrNull((p) => p.id == widget.productId);

    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(s.t('القطعة غير متوفرة', 'Part not found'))),
      );
    }

    final seller = ref
        .watch(shopSellersProvider)
        .firstWhereOrNull((x) => x.id == product.providerId);
    final saved = ref.watch(savedPartsProvider).contains(product.id);
    final car = ref.watch(shopFilterProvider).car;
    final inCart = ref.watch(cartProvider)[product.id];
    final similar = ref
        .watch(productsProvider)
        .where((p) => p.categoryId == product.categoryId && p.id != product.id)
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _gallery(context, product, saved),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _identity(product, s, ak),
                  const SizedBox(height: 14),
                  _priceCard(product, s, ak),
                  const SizedBox(height: 12),
                  _fitmentCard(product, car, s, ak),
                  const SizedBox(height: 12),
                  _stockAndDelivery(product, seller, s, ak),
                  const SizedBox(height: 18),
                  SectionHeader(s.t('الوصف', 'Description')),
                  const SizedBox(height: 8),
                  Text(
                    product.details(s),
                    style: TextStyle(
                        fontSize: 12.5, color: ak.inkSub, height: 1.6),
                  ),
                  if (product.specs.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SectionHeader(s.t('المواصفات', 'Specifications')),
                    const SizedBox(height: 8),
                    _specTable(product, s, ak),
                  ],
                  const SizedBox(height: 18),
                  SectionHeader(s.t('ضمانك', 'Your cover')),
                  const SizedBox(height: 8),
                  _assurances(product, s, ak),
                  if (seller != null) ...[
                    const SizedBox(height: 18),
                    SectionHeader(s.t('بيانات المتجر', 'Shop details')),
                    const SizedBox(height: 8),
                    _sellerCard(seller, product, s),
                  ],
                  if (similar.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SectionHeader(s.t('قطع مشابهة', 'Similar parts')),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: similar.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) =>
                            _SimilarCard(product: similar[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buyBar(product, seller, inCart, s, ak),
    );
  }

  // ------------------------------------------------------------ gallery
  Widget _gallery(BuildContext context, Product product, bool saved) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: ak.bg,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _RoundAction(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _RoundAction(
            icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            foreground: saved ? ak.danger : null,
            onTap: () {
              final next = {...ref.read(savedPartsProvider)};
              next.contains(product.id)
                  ? next.remove(product.id)
                  : next.add(product.id);
              ref.read(savedPartsProvider.notifier).state = next;
              HapticFeedback.selectionClick();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 12, top: 8, bottom: 8),
          child: _RoundAction(
            icon: Icons.share_outlined,
            onTap: () => _copy(
              '${product.name.of(s)} — OMR ${product.price.toStringAsFixed(2)} · AK Cars',
              s.t('تم نسخ تفاصيل القطعة', 'Part details copied'),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: ak.surfaceDim),
            PageView.builder(
              controller: _photos,
              itemCount: product.photoCount,
              onPageChanged: (i) => setState(() => _photo = i),
              itemBuilder: (context, i) => Center(
                child: Icon(
                  i == 0 ? product.icon : Icons.photo_outlined,
                  size: 96,
                  color: ak.inkFaint,
                ),
              ),
            ),
            PositionedDirectional(
              start: 16,
              bottom: 16,
              child: Row(
                children: [
                  if (product.onOffer)
                    DiscountBadge(percent: product.discountPercent),
                  if (product.onOffer) const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: ak.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ak.border),
                    ),
                    child: Text(
                      '${_photo + 1}/${product.photoCount}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ak.inkSub,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------- identity
  Widget _identity(Product product, S s, AkColors ak) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (product.brand case final brand?) ...[
              Text(
                brand.of(s).toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: ak.inkSub,
                ),
              ),
              const SizedBox(width: 8),
            ],
            product.genuine
                ? StatusBadge.good(s.t('قطعة أصلية', 'Genuine / OEM'))
                : StatusBadge(s.t('بديل تجاري', 'Aftermarket')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          product.name.of(s),
          style: const TextStyle(
              fontSize: 21, fontWeight: FontWeight.w800, height: 1.25),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ProductRating(rating: product.rating, size: 12),
            const SizedBox(width: 12),
            if (product.partNumber case final number?)
              Expanded(
                child: GestureDetector(
                  onTap: () => _copy(
                    number,
                    s.t('تم نسخ رقم القطعة', 'Part number copied'),
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          s.t('رقم القطعة: $number', 'Part no. $number'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: ak.inkSub,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded, size: 12, color: ak.inkFaint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------- price
  Widget _priceCard(Product product, S s, AkColors ak) {
    // Oman quotes shelf prices VAT-inclusive, so the tax is backed out of the
    // price rather than added to it.
    final vat = product.price -
        product.price / (1 + AppConstants.vatRate);
    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ProductPriceLine(product: product, size: 24),
              const Spacer(),
              // The saving pill yields to the price under a large text scale
              // rather than pushing the row into an overflow.
              if (product.onOffer)
                Flexible(
                  child: StatusBadge.warn(s.t(
                      'وفّر ${product.saving.toStringAsFixed(2)} ${s.omr}',
                      'Save OMR ${product.saving.toStringAsFixed(2)}')),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.t(
                'شامل ضريبة القيمة المضافة ٥٪ (${vat.toStringAsFixed(2)} ${s.omr})',
                'Includes 5% VAT (OMR ${vat.toStringAsFixed(2)})'),
            style: TextStyle(fontSize: 11.5, color: ak.inkSub),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ fitment
  Widget _fitmentCard(Product product, Car? car, S s, AkColors ak) {
    final fits = car != null && product.fitsCar(car);
    final unknown = car == null;
    final (background, border, icon, tint) = switch (true) {
      _ when product.universalFit => (
          ak.surfaceDim,
          ak.border,
          Icons.check_circle_outline_rounded,
          ak.ink
        ),
      _ when unknown => (
          ak.amberBgSoft,
          ak.amberBorder,
          Icons.help_outline_rounded,
          ak.amberText
        ),
      _ when fits => (
          ak.successSoft,
          ak.successSoft,
          Icons.verified_rounded,
          ak.success
        ),
      _ => (ak.amberBgSoft, ak.amberBorder, Icons.info_outline_rounded, ak.amberText),
    };

    final title = product.universalFit
        ? s.t('تناسب كل السيارات', 'Fits all cars')
        : unknown
            ? s.t('حدد سيارتك للتأكد', 'Select your car to check fitment')
            : fits
                ? s.t('تناسب ${car.label}', 'Fits your ${car.label}')
                : s.t('قد لا تناسب ${car.label}',
                    'May not fit your ${car.label}');

    final subtitle = product.universalFit
        ? s.t('قطعة عامة لا تعتمد على الموديل.',
            'A universal part — not model-specific.')
        : s.t('تناسب: ${product.fits.join('، ')}',
            'Compatible with: ${product.fits.join(', ')}');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: tint)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11.5, color: ak.inkSub, height: 1.45)),
              ],
            ),
          ),
          if (!product.universalFit) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const ShopFilterSheet(),
              ),
              child: StatusBadge(
                  unknown ? s.t('اختر', 'Select') : s.t('تغيير', 'Change')),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------- stock and delivery
  Widget _stockAndDelivery(
      Product product, ServiceProvider? seller, S s, AkColors ak) {
    final rows = <(IconData, String, Color)>[
      product.inStock
          ? (
              Icons.inventory_2_outlined,
              s.t('متوفرة — ${product.stock} قطعة لدى المتجر',
                  'In stock — ${product.stock} at the shop'),
              ak.success
            )
          : (
              Icons.inventory_2_outlined,
              s.t('غير متوفرة حالياً', 'Out of stock'),
              ak.amberText
            ),
      (
        Icons.local_shipping_outlined,
        product.deliveryDays == 1
            ? s.t('التوصيل خلال يوم عمل واحد', 'Delivery in 1 working day')
            : s.t('التوصيل خلال ${product.deliveryDays} أيام عمل',
                'Delivery in ${product.deliveryDays} working days'),
        ak.inkSub
      ),
      if (product.fittingAvailable && seller != null)
        (
          Icons.build_outlined,
          s.t('التركيب متاح في ${seller.name.ar}',
              'Fitting available at ${seller.name.en}'),
          ak.inkSub
        ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: 9),
            Row(
              children: [
                Icon(row.$1, size: 16, color: row.$3),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    row.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: row.$3 == ak.inkSub ? ak.ink : row.$3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------- spec table
  Widget _specTable(Product product, S s, AkColors ak) {
    const collapsed = 4;
    final overflowing = product.specs.length > collapsed;
    final visible = _specsExpanded || !overflowing
        ? product.specs
        : product.specs.take(collapsed).toList();

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      child: Column(
        children: [
          for (final (index, spec) in visible.indexed) ...[
            if (index > 0) Divider(height: 1, color: ak.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      spec.label.of(s),
                      style: TextStyle(fontSize: 12, color: ak.inkSub),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Text(
                      spec.value.of(s),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (overflowing)
            GestureDetector(
              onTap: () => setState(() => _specsExpanded = !_specsExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _specsExpanded
                      ? s.t('عرض أقل', 'Show less')
                      : s.t('كل المواصفات (${product.specs.length})',
                          'All specifications (${product.specs.length})'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ak.ink),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- assurances
  Widget _assurances(Product product, S s, AkColors ak) {
    final items = <(IconData, String, String)>[
      (
        Icons.shield_outlined,
        s.t('ضمان', 'Warranty'),
        s.t('${product.warrantyMonths} شهراً', '${product.warrantyMonths} months'),
      ),
      (
        Icons.assignment_return_outlined,
        s.t('إرجاع', 'Returns'),
        s.t('خلال ${product.returnDays} أيام', '${product.returnDays} days'),
      ),
      (
        Icons.lock_outline_rounded,
        s.t('الدفع', 'Payment'),
        s.t('محتجز حتى الاستلام', 'Held until delivery'),
      ),
    ];
    return Row(
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const SizedBox(width: 9),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
              child: Column(
                children: [
                  Icon(item.$1, size: 19, color: ak.ink),
                  const SizedBox(height: 7),
                  Text(item.$2,
                      style: TextStyle(fontSize: 10.5, color: ak.inkSub)),
                  const SizedBox(height: 2),
                  Text(
                    item.$3,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------- seller card
  Widget _sellerCard(ServiceProvider seller, Product product, S s) {
    final part = product.partNumber == null ? '' : ' (${product.partNumber})';
    return ProviderDetailsCard(
      provider: seller,
      whatsappMessage: s.t(
          'مرحباً، أستفسر عن "${product.name.ar}"$part في متجر AK Cars.',
          'Hi, I am asking about "${product.name.en}"$part on AK Cars.'),
      footer: ProviderCardAction(
        label: s.t('كل قطع هذا المتجر', 'All parts from this shop'),
        onTap: () => _showAllFromShop(seller),
      ),
    );
  }

  // ------------------------------------------------------------ buy bar
  Widget _buyBar(
      Product product, ServiceProvider? seller, int? inCart, S s, AkColors ak) {
    final total = product.price * _qty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: ak.surface,
        border: Border(top: BorderSide(color: ak.border)),
      ),
      child: SafeArea(
        top: false,
        child: product.inStock
            ? Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: ak.surfaceDim,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_rounded, size: 18),
                          onPressed:
                              _qty > 1 ? () => setState(() => _qty--) : null,
                        ),
                        Text('$_qty',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          onPressed: _qty < product.stock
                              ? () => setState(() => _qty++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                      onPressed: () {
                        if (!ensureRegistered(context, ref)) return;
                        HapticFeedback.mediumImpact();
                        ref.read(cartProvider.notifier).setQty(product.id, _qty);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(inCart == null
                                ? s.t('أُضيفت إلى السلة', 'Added to cart')
                                : s.t('حُدّثت الكمية في السلة',
                                    'Cart quantity updated')),
                            action: SnackBarAction(
                              label: s.t('السلة', 'Cart'),
                              onPressed: () => context.push('/cart'),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        s.t('أضف للسلة · ${total.toStringAsFixed(2)} ${s.omr}',
                            'Add to cart · OMR ${total.toStringAsFixed(2)}'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      s.t('غير متوفرة حالياً — تواصل مع المتجر لموعد التوفر.',
                          'Out of stock — ask the shop when it is back.'),
                      style: TextStyle(fontSize: 12, color: ak.inkSub),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(140, 48),
                      backgroundColor: const Color(0xFF25A55A),
                    ),
                    onPressed: seller?.whatsapp == null
                        ? null
                        : () => Contact.whatsapp(
                              context,
                              seller!.whatsapp!,
                              message: s.t(
                                  'مرحباً، متى تتوفر "${product.name.ar}"؟',
                                  'Hi, when will "${product.name.en}" be back in stock?'),
                            ),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: Text(s.t('اسأل المتجر', 'Ask the shop'),
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Circular translucent action used over the gallery.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: ak.surface,
          shape: BoxShape.circle,
          border: Border.all(color: ak.border),
        ),
        child: Icon(icon, size: 18, color: foreground ?? ak.ink),
      ),
    );
  }
}

/// Compact card in the "Similar parts" rail.
class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.replace('/shop/product/${product.id}');
      },
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: ak.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ak.border),
        ),
        child: Row(
          children: [
            IconTile(product.icon,
                size: 56,
                radius: 14,
                background: ak.surfaceDim,
                foreground: ak.inkSub),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name.of(s),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  ProductRating(rating: product.rating),
                  const SizedBox(height: 4),
                  ProductPriceLine(product: product, size: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
