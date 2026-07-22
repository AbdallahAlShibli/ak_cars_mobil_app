import '../../core/i18n/strings.dart';
import '../models/product.dart';
import '../models/shop_filter.dart';
import '../services/shop_service.dart';
import 'warm_cache.dart';

/// The parts shop catalogue.
///
/// Filtering runs locally against the warmed catalogue so the shop's filter
/// chips stay instant. [fetchProducts] is the same operation done remotely,
/// and is what the REST implementation will make the primary path once the
/// catalogue is too large to hold in memory.
abstract interface class ShopRepository {
  Future<void> warmUp();

  /// Part category id → bilingual label.
  Map<String, L> get partCategories;

  List<Product> get products;

  /// Products passing [filter], evaluated against the warmed catalogue.
  List<Product> filter(ShopFilter filter);

  Product? productById(String productId);

  /// Server-side query — used once the catalogue outgrows the warm cache.
  Future<List<Product>> fetchProducts({ShopFilter? filter});
}

class ShopRepositoryImpl implements ShopRepository {
  ShopRepositoryImpl(this._service);

  final ShopService _service;

  final _partCategories = WarmCache<Map<String, L>>(fallback: const {});
  final _products = WarmCache<List<Product>>(fallback: const []);

  @override
  Future<void> warmUp() => Future.wait([
        _partCategories.load(_service.fetchPartCategories),
        _products.load(() => _service.fetchProducts()),
      ]);

  @override
  Map<String, L> get partCategories => _partCategories.value;

  @override
  List<Product> get products => _products.value;

  @override
  List<Product> filter(ShopFilter filter) =>
      products.where(filter.matches).toList(growable: false);

  @override
  Product? productById(String productId) {
    for (final product in products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  @override
  Future<List<Product>> fetchProducts({ShopFilter? filter}) =>
      _service.fetchProducts(filter: filter);
}
