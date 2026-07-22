import '../../core/json/json_utils.dart';
import 'car.dart';
import 'product.dart';

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
    this.minPrice = 0,
    this.maxPrice = 100,
  });

  final Car? car;
  final String? categoryId;
  final String? providerId;
  final String? region;
  final double minPrice;
  final double maxPrice;

  int get activeCount {
    var n = 0;
    if (car != null) n++;
    if (categoryId != null) n++;
    if (providerId != null) n++;
    if (region != null) n++;
    if (minPrice > 0 || maxPrice < 100) n++;
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
    return matchesPrice(product.price);
  }

  Map<String, dynamic> toQueryParameters() => compactJson({
        'fitsMake': car?.make,
        'fitsModel': car?.model,
        'categoryId': categoryId,
        'providerId': providerId,
        'region': region,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
      });

  ShopFilter copyWith({
    Car? Function()? car,
    String? Function()? categoryId,
    String? Function()? providerId,
    String? Function()? region,
    double? minPrice,
    double? maxPrice,
  }) =>
      ShopFilter(
        car: car != null ? car() : this.car,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        providerId: providerId != null ? providerId() : this.providerId,
        region: region != null ? region() : this.region,
        minPrice: minPrice ?? this.minPrice,
        maxPrice: maxPrice ?? this.maxPrice,
      );

  @override
  bool operator ==(Object other) =>
      other is ShopFilter &&
      other.car == car &&
      other.categoryId == categoryId &&
      other.providerId == providerId &&
      other.region == region &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice;

  @override
  int get hashCode =>
      Object.hash(car, categoryId, providerId, region, minPrice, maxPrice);
}
