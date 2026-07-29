import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'car.dart';
import 'powertrain.dart';
import 'product.dart';

/// How the results list is ordered. `recommended` is catalogue order — what
/// the API returns — and is the only value that is not a client-side sort.
enum ShopSort { recommended, priceLowHigh, priceHighLow, topRated }

extension ShopSortX on ShopSort {
  String label(S s) => switch (this) {
        ShopSort.recommended => s.t('المقترح', 'Recommended'),
        ShopSort.priceLowHigh => s.t('السعر: من الأقل', 'Price: low to high'),
        ShopSort.priceHighLow => s.t('السعر: من الأعلى', 'Price: high to low'),
        ShopSort.topRated => s.t('الأعلى تقييماً', 'Top rated'),
      };

  String get key => name;

  static ShopSort fromKey(String? key) {
    for (final value in ShopSort.values) {
      if (value.name == key) return value;
    }
    return ShopSort.recommended;
  }
}

/// Parts-shop filter. Applied locally and instantly; the same field names map
/// onto `GET /products` query parameters via [toQueryParameters].
///
/// Nullable fields use `Type? Function()?` setters in [copyWith] so a caller
/// can distinguish "leave unchanged" from "clear this filter".
class ShopFilter {
  const ShopFilter({
    this.car,
    this.categoryId,
    this.providerId,
    this.region,
    this.powertrain,
    this.minPrice = 0,
    this.maxPrice = 100,
    this.inStockOnly = false,
    this.onOfferOnly = false,
    this.sort = ShopSort.recommended,
  });

  final Car? car;
  final String? categoryId;
  final String? providerId;
  final String? region;

  /// Show only parts that suit this powertrain. Set on its own (rather than
  /// derived from [car]) so an EV owner can browse charging hardware without
  /// pinning the whole shop to one saved car, and so someone shopping ahead of
  /// buying an EV can use it with no car saved at all.
  final Powertrain? powertrain;

  final double minPrice;
  final double maxPrice;

  /// Hide parts the seller has none of on hand.
  final bool inStockOnly;

  /// Only parts carrying a live discount.
  final bool onOfferOnly;

  final ShopSort sort;

  /// Sort is deliberately excluded: it changes the order of the results, not
  /// which results there are, so it does not belong on the filter badge.
  int get activeCount {
    var n = 0;
    if (car != null) n++;
    if (categoryId != null) n++;
    if (providerId != null) n++;
    if (region != null) n++;
    if (powertrain != null) n++;
    if (minPrice > 0 || maxPrice < 100) n++;
    if (inStockOnly) n++;
    if (onOfferOnly) n++;
    return n;
  }

  bool matchesPrice(double price) => price >= minPrice && price <= maxPrice;

  /// True when [product] passes every active criterion.
  ///
  /// Lives on the filter rather than in a service so the local (instant) and
  /// remote (query-parameter) paths can never drift apart on what "matching"
  /// means.
  bool matches(Product product) {
    if (!product.fitsCar(car)) return false;
    if (categoryId != null && product.categoryId != categoryId) return false;
    if (providerId != null && product.providerId != providerId) return false;
    if (region != null && product.region != region) return false;
    if (!product.fitsPowertrain(powertrain)) return false;
    if (inStockOnly && !product.inStock) return false;
    if (onOfferOnly && !product.onOffer) return false;
    return matchesPrice(product.price);
  }

  /// [products] in [sort] order. Returns a new list rather than sorting in
  /// place, so the repository's warm cache can never be reordered under it.
  List<Product> ordered(List<Product> products) {
    if (sort == ShopSort.recommended) return products;
    final sorted = [...products];
    switch (sort) {
      case ShopSort.priceLowHigh:
        sorted.sort((a, b) => a.price.compareTo(b.price));
      case ShopSort.priceHighLow:
        sorted.sort((a, b) => b.price.compareTo(a.price));
      case ShopSort.topRated:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
      case ShopSort.recommended:
        break;
    }
    return sorted;
  }

  Map<String, dynamic> toQueryParameters() => compactJson({
        'fitsMake': car?.make,
        'fitsModel': car?.model,
        'categoryId': categoryId,
        'providerId': providerId,
        'region': region,
        'powertrain': powertrain?.key,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'inStock': inStockOnly ? true : null,
        'onOffer': onOfferOnly ? true : null,
        'sort': sort == ShopSort.recommended ? null : sort.key,
      });

  ShopFilter copyWith({
    Car? Function()? car,
    String? Function()? categoryId,
    String? Function()? providerId,
    String? Function()? region,
    Powertrain? Function()? powertrain,
    double? minPrice,
    double? maxPrice,
    bool? inStockOnly,
    bool? onOfferOnly,
    ShopSort? sort,
  }) =>
      ShopFilter(
        car: car != null ? car() : this.car,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        providerId: providerId != null ? providerId() : this.providerId,
        region: region != null ? region() : this.region,
        powertrain: powertrain != null ? powertrain() : this.powertrain,
        minPrice: minPrice ?? this.minPrice,
        maxPrice: maxPrice ?? this.maxPrice,
        inStockOnly: inStockOnly ?? this.inStockOnly,
        onOfferOnly: onOfferOnly ?? this.onOfferOnly,
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) =>
      other is ShopFilter &&
      other.car == car &&
      other.categoryId == categoryId &&
      other.providerId == providerId &&
      other.region == region &&
      other.powertrain == powertrain &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.inStockOnly == inStockOnly &&
      other.onOfferOnly == onOfferOnly &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(car, categoryId, providerId, region,
      powertrain, minPrice, maxPrice, inStockOnly, onOfferOnly, sort);
}
