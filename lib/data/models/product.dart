import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/icon_codec.dart';
import '../../core/json/json_utils.dart';
import '../../core/utils/search_match.dart';
import 'car.dart';

/// One row of a part's spec table ("Thread size" → "M20 × 1.5").
///
/// Kept as an ordered list rather than a map: the order a spec sheet is read
/// in is part of the information, and two parts in the same category should
/// list their specs in the same order.
class ProductSpec {
  const ProductSpec(this.label, this.value);

  final L label;
  final L value;

  factory ProductSpec.fromJson(JsonMap json) => ProductSpec(
        L.fromJson(json['label']),
        L.fromJson(json['value']),
      );

  JsonMap toJson() => {'label': label.toJson(), 'value': value.toJson()};

  @override
  bool operator ==(Object other) =>
      other is ProductSpec && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);
}

/// A part or accessory sold in the shop.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.providerId,
    required this.region,
    required this.icon,
    required this.fits,
    this.rating = 4.5,
    this.oldPrice,
    this.description,
    this.photoCount = 3,
    this.brand,
    this.partNumber,
    this.genuine = true,
    this.warrantyMonths = 6,
    this.stock = 0,
    this.deliveryDays = 2,
    this.returnDays = 7,
    this.fittingAvailable = false,
    this.specs = const [],
  });

  final String id;
  final L name;
  final double price;
  final String categoryId;
  final String providerId;
  final String region;
  final IconData icon;

  /// Buyer rating.
  final double rating;

  /// Pre-discount price — shown struck through when on offer.
  final double? oldPrice;

  final L? description;
  final int photoCount;

  /// Manufacturer of the part ("Denso", "Bosch") — not the car make.
  final L? brand;

  /// Manufacturer reference the buyer can cross-check against their old part.
  final String? partNumber;

  /// True for genuine/OEM parts, false for aftermarket equivalents. Shown as
  /// a badge because it is the first thing an Omani buyer asks a counter.
  final bool genuine;

  final int warrantyMonths;

  /// Units the selling workshop has on hand. `0` reads as out of stock.
  final int stock;

  /// Working days until delivery, quoted by the seller.
  final int deliveryDays;

  /// Days the buyer has to return an unfitted part.
  final int returnDays;

  /// The selling workshop will fit this part on site.
  final bool fittingAvailable;

  /// Spec sheet rows, in reading order.
  final List<ProductSpec> specs;

  /// `'any'`, or `'Make Model'` keys this part fits.
  final Set<String> fits;

  bool get onOffer => oldPrice != null && oldPrice! > price;

  bool get inStock => stock > 0;

  /// Absolute rial saved versus [oldPrice]; `0` when not on offer.
  double get saving => onOffer ? oldPrice! - price : 0;

  /// Rounded discount percentage; `0` when not on offer.
  int get discountPercent =>
      onOffer ? (100 - price / oldPrice! * 100).round() : 0;

  bool get universalFit => fits.contains('any');

  String details(S s) =>
      description?.of(s) ??
      s.t(
          'قطعة أصلية بجودة عالية مع ضمان 6 أشهر — مفحوصة ومضمونة من '
              'الورشة البائعة.',
          'Genuine quality part with 6-month warranty. Inspected and '
              'guaranteed by the selling workshop.');

  /// Free-text search over everything printed on the part.
  ///
  /// Lives on the model rather than in the shop screen because a parts buyer
  /// searches by whatever they can read — the box ("Denso"), the old part
  /// itself ("90915-YZZE1"), or the name — and all three have to mean the
  /// same thing to the local search and to the future `GET /products?q=`.
  bool matchesQuery(String query) => SearchMatch.all(query, [
        name.ar,
        name.en,
        brand?.ar,
        brand?.en,
        partNumber,
      ]);

  bool fitsCar(Car? car) {
    if (car == null || fits.contains('any')) return true;
    return fits.contains('${car.make} ${car.model}');
  }

  factory Product.fromJson(JsonMap json) => Product(
        id: json.requireString('id'),
        name: L.fromJson(json['name']),
        price: json.doubleOr('price', 0),
        categoryId: json.stringOr('categoryId', ''),
        providerId: json.stringOr('providerId', ''),
        region: json.stringOr('region', ''),
        icon: IconCodec.decode(json.stringOrNull('icon')),
        fits: json.stringSet('fits'),
        rating: json.doubleOr('rating', 4.5),
        oldPrice: json.doubleOrNull('oldPrice'),
        description:
            json['description'] == null ? null : L.fromJson(json['description']),
        photoCount: json.intOr('photoCount', 3),
        brand: json['brand'] == null ? null : L.fromJson(json['brand']),
        partNumber: json.stringOrNull('partNumber'),
        genuine: json.boolOr('genuine', true),
        warrantyMonths: json.intOr('warrantyMonths', 6),
        stock: json.intOr('stock', 0),
        deliveryDays: json.intOr('deliveryDays', 2),
        returnDays: json.intOr('returnDays', 7),
        fittingAvailable: json.boolOr('fittingAvailable', false),
        specs: [
          for (final spec in json.objectList('specs')) ProductSpec.fromJson(spec)
        ],
      );

  JsonMap toJson() => {
        'id': id,
        'name': name.toJson(),
        'price': price,
        'categoryId': categoryId,
        'providerId': providerId,
        'region': region,
        'icon': IconCodec.encode(icon),
        'fits': fits.toList(),
        'rating': rating,
        'oldPrice': oldPrice,
        'description': description?.toJson(),
        'photoCount': photoCount,
        'brand': brand?.toJson(),
        'partNumber': partNumber,
        'genuine': genuine,
        'warrantyMonths': warrantyMonths,
        'stock': stock,
        'deliveryDays': deliveryDays,
        'returnDays': returnDays,
        'fittingAvailable': fittingAvailable,
        'specs': [for (final spec in specs) spec.toJson()],
      };

  Product copyWith({
    String? id,
    L? name,
    double? price,
    String? categoryId,
    String? providerId,
    String? region,
    IconData? icon,
    Set<String>? fits,
    double? rating,
    double? oldPrice,
    L? description,
    int? photoCount,
    L? brand,
    String? partNumber,
    bool? genuine,
    int? warrantyMonths,
    int? stock,
    int? deliveryDays,
    int? returnDays,
    bool? fittingAvailable,
    List<ProductSpec>? specs,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        categoryId: categoryId ?? this.categoryId,
        providerId: providerId ?? this.providerId,
        region: region ?? this.region,
        icon: icon ?? this.icon,
        fits: fits ?? this.fits,
        rating: rating ?? this.rating,
        oldPrice: oldPrice ?? this.oldPrice,
        description: description ?? this.description,
        photoCount: photoCount ?? this.photoCount,
        brand: brand ?? this.brand,
        partNumber: partNumber ?? this.partNumber,
        genuine: genuine ?? this.genuine,
        warrantyMonths: warrantyMonths ?? this.warrantyMonths,
        stock: stock ?? this.stock,
        deliveryDays: deliveryDays ?? this.deliveryDays,
        returnDays: returnDays ?? this.returnDays,
        fittingAvailable: fittingAvailable ?? this.fittingAvailable,
        specs: specs ?? this.specs,
      );

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.name == name &&
      other.price == price &&
      other.categoryId == categoryId &&
      other.providerId == providerId &&
      other.region == region &&
      other.icon == icon &&
      other.rating == rating &&
      other.oldPrice == oldPrice &&
      other.description == description &&
      other.photoCount == photoCount &&
      other.brand == brand &&
      other.partNumber == partNumber &&
      other.genuine == genuine &&
      other.warrantyMonths == warrantyMonths &&
      other.stock == stock &&
      other.deliveryDays == deliveryDays &&
      other.returnDays == returnDays &&
      other.fittingAvailable == fittingAvailable &&
      const ListEquality<ProductSpec>().equals(other.specs, specs) &&
      other.fits.length == fits.length &&
      other.fits.containsAll(fits);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        price,
        categoryId,
        providerId,
        region,
        icon,
        rating,
        oldPrice,
        description,
        photoCount,
        brand,
        partNumber,
        genuine,
        Object.hash(warrantyMonths, stock, deliveryDays, returnDays,
            fittingAvailable, Object.hashAll(specs)),
        Object.hashAllUnordered(fits),
      );
}
