import 'package:flutter/widgets.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/icon_codec.dart';
import '../../core/json/json_utils.dart';
import 'car.dart';

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

  /// `'any'`, or `'Make Model'` keys this part fits.
  final Set<String> fits;

  bool get onOffer => oldPrice != null && oldPrice! > price;

  String details(S s) =>
      description?.of(s) ??
      s.t(
          'قطعة أصلية بجودة عالية مع ضمان 6 أشهر — مفحوصة ومضمونة من '
              'الورشة البائعة.',
          'Genuine quality part with 6-month warranty. Inspected and '
              'guaranteed by the selling workshop.');

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
        Object.hashAllUnordered(fits),
      );
}
