import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/product.dart';
import 'package:ak_cars_mobil_app/data/models/shop_filter.dart';
import 'package:ak_cars_mobil_app/data/services/shop_service.dart';

import 'data/mock_shop_data.dart';
import 'fake_service_base.dart';

class MockShopService with MockServiceBase implements ShopService {
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
