import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/i18n/strings.dart';
import '../../models/product.dart';
import '../../models/shop_filter.dart';
import '../shop_service.dart';

/// The parts shop catalogue over REST (§12): `GET /products` and friends.
///
/// Two backend facts worth knowing when reading this file:
///  * `GET /products/categories` answers a `{categoryKey: {ar, en}}` object
///    keyed by the category's string `Key` (e.g. `"filters"`), matching
///    `Product.categoryId` in shape — but `ProductDto.categoryId` on the wire
///    is actually the category row's GUID, not that string key. There is
///    currently no endpoint mapping one to the other, so a product fetched
///    from `/products` will not resolve against `fetchPartCategories()`'s
///    keys until the backend aligns the two. Passed through as-is here
///    because inventing a client-side join would hide that gap rather than
///    surface it.
///  * `Product`/`PartCategory` are not seeded server-side yet, so
///    [fetchProducts] and [fetchPartCategories] both return empty collections
///    against a fresh database — expected, not a bug in this client.
class ApiShopService implements ShopService {
  const ApiShopService(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, L>> fetchPartCategories() async {
    final json = await _client.get(ApiEndpoints.partCategories);
    return {for (final entry in json.entries) entry.key: L.fromJson(entry.value)};
  }

  @override
  Future<List<Product>> fetchProducts({ShopFilter? filter}) async =>
      (await _client.getList(
        ApiEndpoints.products,
        queryParameters: filter?.toQueryParameters(),
      ))
          .map(Product.fromJson)
          .toList();

  @override
  Future<Product> fetchProduct(String productId) async =>
      Product.fromJson(await _client.get(ApiEndpoints.product(productId)));
}
