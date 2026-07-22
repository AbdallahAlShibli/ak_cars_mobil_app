import 'package:flutter/widgets.dart';

import '../../core/json/icon_codec.dart';
import '../../core/json/json_utils.dart';

/// Compact car-for-sale summary used by the home screen rail.
///
/// The full marketplace record is [GalleryListing]; this is the trimmed
/// projection the home feed endpoint returns.
class CarListing {
  const CarListing({
    required this.id,
    required this.title,
    required this.year,
    required this.km,
    required this.region,
    required this.price,
    required this.spec,
    required this.icon,
    required this.photoCount,
  });

  final String id;
  final String title;
  final int year;
  final int km;
  final String region;
  final double price;
  final String spec;
  final IconData icon;
  final int photoCount;

  factory CarListing.fromJson(JsonMap json) => CarListing(
        id: json.requireString('id'),
        title: json.stringOr('title', ''),
        year: json.intOr('year', 0),
        km: json.intOr('km', 0),
        region: json.stringOr('region', ''),
        price: json.doubleOr('price', 0),
        spec: json.stringOr('spec', ''),
        icon: IconCodec.decode(json.stringOrNull('icon')),
        photoCount: json.intOr('photoCount', 0),
      );

  JsonMap toJson() => {
        'id': id,
        'title': title,
        'year': year,
        'km': km,
        'region': region,
        'price': price,
        'spec': spec,
        'icon': IconCodec.encode(icon),
        'photoCount': photoCount,
      };

  CarListing copyWith({
    String? id,
    String? title,
    int? year,
    int? km,
    String? region,
    double? price,
    String? spec,
    IconData? icon,
    int? photoCount,
  }) =>
      CarListing(
        id: id ?? this.id,
        title: title ?? this.title,
        year: year ?? this.year,
        km: km ?? this.km,
        region: region ?? this.region,
        price: price ?? this.price,
        spec: spec ?? this.spec,
        icon: icon ?? this.icon,
        photoCount: photoCount ?? this.photoCount,
      );

  @override
  bool operator ==(Object other) =>
      other is CarListing &&
      other.id == id &&
      other.title == title &&
      other.year == year &&
      other.km == km &&
      other.region == region &&
      other.price == price &&
      other.spec == spec &&
      other.icon == icon &&
      other.photoCount == photoCount;

  @override
  int get hashCode =>
      Object.hash(id, title, year, km, region, price, spec, icon, photoCount);
}
