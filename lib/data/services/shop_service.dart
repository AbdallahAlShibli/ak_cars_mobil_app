import '../../config/app_config.dart';
import '../../core/i18n/strings.dart';
import '../datasources/mock/mock_shop_data.dart';
import '../models/product.dart';
import '../models/shop_filter.dart';
import 'mock_service_base.dart';

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

class MockShopService with MockServiceBase implements ShopService {
  MockShopService({required this.config});

  @override
  final AppConfig config;

  @override
  Future<Map<String, L>> fetchPartCategories() =>
      respond(MockShopData.partCategories);

  @override
  Future<List<Product>> fetchProducts({ShopFilter? filter}) => respond(
        filter == null
            ? MockShopData.products
            : MockShopData.products
                .where(filter.matches)
                .toList(growable: false),
      );

  @override
  Future<Product> fetchProduct(String productId) {
    Product? match;
    for (final product in MockShopData.products) {
      if (product.id == productId) match = product;
    }
    return respondRequired(match, 'Product $productId');
  }
}
