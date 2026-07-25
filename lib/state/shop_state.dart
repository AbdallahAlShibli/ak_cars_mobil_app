import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/order.dart';
import '../data/models/product.dart';
import '../data/models/shop_filter.dart';
import '../di/providers.dart';
import 'garage_state.dart';

/// The parts catalogue, unfiltered.
final productsProvider = Provider<List<Product>>(
  (ref) => ref.watch(shopRepositoryProvider).products,
);

/// Part category id → bilingual label.
final partCategoriesProvider = Provider(
  (ref) => ref.watch(shopRepositoryProvider).partCategories,
);

/// Workshops selling parts, reused as the shop's seller filter.
final shopSellersProvider = Provider(
  (ref) => ref.watch(serviceMarketplaceRepositoryProvider).providers,
);

/// Cart contents as product id → quantity.
///
/// Rule: the shop is never locked to the saved car, so the cart is keyed by
/// product alone.
class CartNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void toggle(Product p) {
    final next = Map<String, int>.from(state);
    if (next.containsKey(p.id)) {
      next.remove(p.id);
    } else {
      next[p.id] = 1;
    }
    state = next;
  }

  void setQty(String productId, int qty) {
    final next = Map<String, int>.from(state);
    if (qty <= 0) {
      next.remove(productId);
    } else {
      next[productId] = qty;
    }
    state = next;
  }

  void clear() => state = const {};
}

final cartProvider =
    NotifierProvider<CartNotifier, Map<String, int>>(CartNotifier.new);

/// Cart resolved to products + quantities.
final cartItemsProvider = Provider<List<OrderItem>>((ref) {
  final repository = ref.watch(shopRepositoryProvider);
  return [
    for (final entry in ref.watch(cartProvider).entries)
      if (repository.productById(entry.key) case final product?)
        OrderItem(product: product, qty: entry.value),
  ];
});

final cartTotalProvider = Provider<double>((ref) =>
    ref.watch(cartItemsProvider).fold<double>(0, (sum, i) => sum + i.total));

class ShopFilterNotifier extends Notifier<ShopFilter> {
  @override
  ShopFilter build() {
    // Default: suggest the user's saved car, but never lock to it.
    return ShopFilter(car: ref.watch(primaryCarProvider));
  }

  void set(ShopFilter filter) => state = filter;

  void clearCar() => state = state.copyWith(car: () => null);
}

final shopFilterProvider =
    NotifierProvider<ShopFilterNotifier, ShopFilter>(ShopFilterNotifier.new);

/// Instant, local-first filtering and ordering — applies as the user taps.
final filteredProductsProvider = Provider<List<Product>>((ref) {
  final filter = ref.watch(shopFilterProvider);
  return filter.ordered(ref.watch(shopRepositoryProvider).filter(filter));
});

/// Every part carrying a live discount, deepest first — the shop's offers
/// carousel.
///
/// Derived, never authored: the banner this replaced advertised "up to 15%
/// off batteries" as static copy no matter what the catalogue said. An empty
/// list means the shop has no offers to show and the section disappears,
/// rather than an evergreen ad nothing has to honour.
final offersProvider = Provider<List<Product>>((ref) {
  final offers =
      ref.watch(productsProvider).where((p) => p.onOffer).toList();
  offers.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
  return offers;
});

final favoritesProvider = StateProvider<Set<String>>((ref) => {});

/// Parts the user saved from the product page.
///
/// Separate from [favoritesProvider] (which holds car-ad ids) so neither
/// feature has to assume the other's ids can never collide.
final savedPartsProvider = StateProvider<Set<String>>((ref) => {});
