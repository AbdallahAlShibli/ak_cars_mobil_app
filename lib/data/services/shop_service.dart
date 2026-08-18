import '../../core/i18n/strings.dart';
import '../models/product.dart';
import '../models/shop_filter.dart';

/// The parts shop catalogue.
///
/// Phase 2: implement `RestShopService` against `/products`. Note that
/// [fetchProducts] already takes the filter, so moving filtering server-side
/// later is an implementation change only.
abstract interface class ShopService {
  /// Part category id → bilingual label.
  Future<Map<String, L>> fetchPartCategories();

  /// Products matching [filter]; all products when it is omitted.
  Future<List<Product>> fetchProducts({ShopFilter? filter});

  Future<Product> fetchProduct(String productId);
}
