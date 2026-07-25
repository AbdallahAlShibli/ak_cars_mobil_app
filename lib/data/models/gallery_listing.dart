import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/utils/search_match.dart';
import '../../core/json/color_codec.dart';
import '../../core/json/icon_codec.dart';
import '../../core/json/json_utils.dart';

/// Top-level vehicle class shown as the gallery's type rail.
enum VehicleType { all, cars, trucks, bikes }

extension VehicleTypeX on VehicleType {
  String get label => switch (this) {
        VehicleType.all => 'All',
        VehicleType.cars => 'Cars',
        VehicleType.trucks => 'Trucks',
        VehicleType.bikes => 'Bikes',
      };

  IconData get icon => switch (this) {
        VehicleType.all => Icons.apps_rounded,
        VehicleType.cars => Icons.directions_car_filled_rounded,
        VehicleType.trucks => Icons.local_shipping_rounded,
        VehicleType.bikes => Icons.two_wheeler_rounded,
      };

  String get key => name;
}

/// Ordering applied to the cars feed. The `key` values double as the
/// `sort` query parameter for `GET /cars`.
enum GallerySort {
  newest,
  oldest,
  priceLowHigh,
  priceHighLow,
  mileageLowHigh,
  yearNewOld;

  String get key => name;
}

extension GallerySortX on GallerySort {
  String get label => switch (this) {
        GallerySort.newest => 'Newest to oldest',
        GallerySort.oldest => 'Oldest to newest',
        GallerySort.priceLowHigh => 'Price: low to high',
        GallerySort.priceHighLow => 'Price: high to low',
        GallerySort.mileageLowHigh => 'Mileage: low to high',
        GallerySort.yearNewOld => 'Model year: newest first',
      };
}

/// A car-for-sale advert with its full spec sheet and seller block.
class GalleryListing {
  const GalleryListing({
    required this.id,
    required this.make,
    required this.model,
    required this.trim,
    required this.year,
    this.price,
    required this.mileage,
    required this.bodyType,
    required this.condition,
    required this.cylinders,
    required this.engineLitres,
    required this.transmission,
    required this.fuel,
    required this.drivetrain,
    required this.doors,
    required this.seats,
    required this.regionalSpec,
    required this.hasWarranty,
    required this.sellerType,
    required this.keys,
    required this.exteriorColor,
    required this.exteriorSwatch,
    required this.interiorColor,
    required this.interiorSwatch,
    required this.region,
    required this.postedMinutesAgo,
    required this.dealType,
    required this.photoCount,
    required this.icon,
    required this.tint,
    required this.sellerName,
    required this.sellerJoined,
    required this.sellerAds,
    required this.sellerFollowers,
    required this.description,
  });

  final String id;
  final String make;
  final String model;
  final String trim;
  final int year;

  /// Null renders as "Ask for price" and is excluded from price filtering.
  final double? price;

  /// Display odometer string, e.g. `'200,000+'`.
  final String mileage;
  final String bodyType;

  /// 'New' | 'Used' — see [SpecCatalog.conditions].
  final String condition;

  /// `0` for a pure EV — see [SpecCatalog.cylinders].
  final int cylinders;

  /// Displacement in litres; `0.0` for a pure EV.
  final double engineLitres;
  final String transmission;
  final String fuel;
  final String drivetrain;
  final int doors;
  final int seats;
  final String regionalSpec;

  /// Still covered by an agency/dealer warranty.
  final bool hasWarranty;

  /// 'Owner' | 'Dealer' | 'Showroom' — see [SpecCatalog.sellerTypes].
  final String sellerType;
  final int keys;
  final String exteriorColor;
  final Color exteriorSwatch;
  final String interiorColor;
  final Color interiorSwatch;

  /// Stored as `'City, Governorate'`.
  final String region;
  final int postedMinutesAgo;
  final String dealType;
  final int photoCount;
  final IconData icon;
  final Color tint;
  final String sellerName;
  final String sellerJoined;
  final int sellerAds;
  final int sellerFollowers;
  final String description;

  factory GalleryListing.fromJson(JsonMap json) => GalleryListing(
        id: json.requireString('id'),
        make: json.stringOr('make', ''),
        model: json.stringOr('model', ''),
        trim: json.stringOr('trim', ''),
        year: json.intOr('year', 0),
        price: json.doubleOrNull('price'),
        mileage: json.stringOr('mileage', '0'),
        bodyType: json.stringOr('bodyType', ''),
        condition: json.stringOr('condition', 'Used'),
        cylinders: json.intOr('cylinders', 0),
        engineLitres: json.doubleOr('engineLitres', 0),
        transmission: json.stringOr('transmission', ''),
        fuel: json.stringOr('fuel', ''),
        drivetrain: json.stringOr('drivetrain', ''),
        doors: json.intOr('doors', 0),
        seats: json.intOr('seats', 0),
        regionalSpec: json.stringOr('regionalSpec', ''),
        hasWarranty: json.boolOr('hasWarranty', false),
        sellerType: json.stringOr('sellerType', 'Owner'),
        keys: json.intOr('keys', 1),
        exteriorColor: json.stringOr('exteriorColor', ''),
        exteriorSwatch: ColorCodec.decode(json['exteriorSwatch']),
        interiorColor: json.stringOr('interiorColor', ''),
        interiorSwatch: ColorCodec.decode(json['interiorSwatch']),
        region: json.stringOr('region', ''),
        postedMinutesAgo: json.intOr('postedMinutesAgo', 0),
        dealType: json.stringOr('dealType', ''),
        photoCount: json.intOr('photoCount', 0),
        icon: IconCodec.decode(json.stringOrNull('icon')),
        tint: ColorCodec.decode(json['tint']),
        sellerName: json.stringOr('sellerName', ''),
        sellerJoined: json.stringOr('sellerJoined', ''),
        sellerAds: json.intOr('sellerAds', 0),
        sellerFollowers: json.intOr('sellerFollowers', 0),
        description: json.stringOr('description', ''),
      );

  JsonMap toJson() => {
        'id': id,
        'make': make,
        'model': model,
        'trim': trim,
        'year': year,
        'price': price,
        'mileage': mileage,
        'bodyType': bodyType,
        'condition': condition,
        'cylinders': cylinders,
        'engineLitres': engineLitres,
        'transmission': transmission,
        'fuel': fuel,
        'drivetrain': drivetrain,
        'doors': doors,
        'seats': seats,
        'regionalSpec': regionalSpec,
        'hasWarranty': hasWarranty,
        'sellerType': sellerType,
        'keys': keys,
        'exteriorColor': exteriorColor,
        'exteriorSwatch': ColorCodec.encode(exteriorSwatch),
        'interiorColor': interiorColor,
        'interiorSwatch': ColorCodec.encode(interiorSwatch),
        'region': region,
        'postedMinutesAgo': postedMinutesAgo,
        'dealType': dealType,
        'photoCount': photoCount,
        'icon': IconCodec.encode(icon),
        'tint': ColorCodec.encode(tint),
        'sellerName': sellerName,
        'sellerJoined': sellerJoined,
        'sellerAds': sellerAds,
        'sellerFollowers': sellerFollowers,
        'description': description,
      };

  GalleryListing copyWith({
    String? id,
    String? make,
    String? model,
    String? trim,
    int? year,
    double? Function()? price,
    String? mileage,
    String? bodyType,
    String? condition,
    int? cylinders,
    double? engineLitres,
    String? transmission,
    String? fuel,
    String? drivetrain,
    int? doors,
    int? seats,
    String? regionalSpec,
    bool? hasWarranty,
    String? sellerType,
    int? keys,
    String? exteriorColor,
    Color? exteriorSwatch,
    String? interiorColor,
    Color? interiorSwatch,
    String? region,
    int? postedMinutesAgo,
    String? dealType,
    int? photoCount,
    IconData? icon,
    Color? tint,
    String? sellerName,
    String? sellerJoined,
    int? sellerAds,
    int? sellerFollowers,
    String? description,
  }) =>
      GalleryListing(
        id: id ?? this.id,
        make: make ?? this.make,
        model: model ?? this.model,
        trim: trim ?? this.trim,
        year: year ?? this.year,
        price: price != null ? price() : this.price,
        mileage: mileage ?? this.mileage,
        bodyType: bodyType ?? this.bodyType,
        condition: condition ?? this.condition,
        cylinders: cylinders ?? this.cylinders,
        engineLitres: engineLitres ?? this.engineLitres,
        transmission: transmission ?? this.transmission,
        fuel: fuel ?? this.fuel,
        drivetrain: drivetrain ?? this.drivetrain,
        doors: doors ?? this.doors,
        seats: seats ?? this.seats,
        regionalSpec: regionalSpec ?? this.regionalSpec,
        hasWarranty: hasWarranty ?? this.hasWarranty,
        sellerType: sellerType ?? this.sellerType,
        keys: keys ?? this.keys,
        exteriorColor: exteriorColor ?? this.exteriorColor,
        exteriorSwatch: exteriorSwatch ?? this.exteriorSwatch,
        interiorColor: interiorColor ?? this.interiorColor,
        interiorSwatch: interiorSwatch ?? this.interiorSwatch,
        region: region ?? this.region,
        postedMinutesAgo: postedMinutesAgo ?? this.postedMinutesAgo,
        dealType: dealType ?? this.dealType,
        photoCount: photoCount ?? this.photoCount,
        icon: icon ?? this.icon,
        tint: tint ?? this.tint,
        sellerName: sellerName ?? this.sellerName,
        sellerJoined: sellerJoined ?? this.sellerJoined,
        sellerAds: sellerAds ?? this.sellerAds,
        sellerFollowers: sellerFollowers ?? this.sellerFollowers,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) => other is GalleryListing && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

extension GalleryListingX on GalleryListing {
  String get displayTitle => '$year $make $model $trim'.trim();

  /// Free-text search over the ad.
  ///
  /// The cars screen used to match only `displayTitle` and the raw `region`
  /// key, which meant "camry 2017" found nothing (the title reads "2017
  /// Toyota Camry SE", so the words are in the other order) and an Arabic
  /// user searching "مسقط" found nothing at all, because the stored region is
  /// the English key. [localizedRegion] carries the translated place name in
  /// so the model stays free of the location catalogue.
  bool matchesQuery(String query, {String? localizedRegion}) =>
      SearchMatch.all(query, [
        make,
        model,
        trim,
        '$year',
        bodyType,
        region,
        localizedRegion,
        sellerName,
      ]);

  /// Numeric odometer parsed from the display string ("200,000+" → 200000)
  /// for range filtering.
  int get mileageValue =>
      int.tryParse(mileage.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  /// Listing `region` is stored "City, Governorate" — split for the
  /// Region (governorate) and City filter facets.
  String get cityName {
    final i = region.indexOf(',');
    return (i < 0 ? region : region.substring(0, i)).trim();
  }

  String get governorate {
    final i = region.indexOf(',');
    return (i < 0 ? region : region.substring(i + 1)).trim();
  }

  String postedLabel(S s) {
    if (postedMinutesAgo < 60) {
      return s.t('قبل $postedMinutesAgo دقيقة', '$postedMinutesAgo min ago');
    }
    final h = postedMinutesAgo ~/ 60;
    return s.t('قبل $h ساعة', '$h h ago');
  }
}
