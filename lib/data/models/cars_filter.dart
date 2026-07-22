import '../../core/json/json_utils.dart';
import 'gallery_listing.dart';
import 'spec_catalog.dart';

/// Cars-market filter — instant and local-first, modelled on a full
/// marketplace filter: single-value criteria (make, model, year range) plus
/// multi-select facets (deal/body/spec/transmission/drivetrain/fuel/cylinders/
/// colors/region) that OR within a facet and AND across facets.
///
/// `null`/empty means "no constraint". Price and mileage filters exclude
/// "Ask for price" / unknown-value listings.
///
/// [toQueryParameters] is the shape `GET /cars` will accept, so moving the
/// filtering server-side later does not change the filter's public API.
class CarsFilter {
  const CarsFilter({
    this.make,
    this.model,
    this.trims = const {},
    this.fromYear,
    this.toYear,
    this.dealTypes = const {},
    this.bodyTypes = const {},
    this.conditions = const {},
    this.regionalSpecs = const {},
    this.transmissions = const {},
    this.drivetrains = const {},
    this.fuels = const {},
    this.cylinders = const {},
    this.engineSizes = const {},
    this.doors = const {},
    this.seats = const {},
    this.sellerTypes = const {},
    this.warrantyOnly = false,
    this.exteriorColors = const {},
    this.interiorColors = const {},
    this.regions = const {},
    this.cities = const {},
    this.minPrice,
    this.maxPrice,
    this.maxMileage,
    this.sort = GallerySort.newest,
  });

  final String? make;
  final String? model;
  final Set<String> trims;
  final int? fromYear;
  final int? toYear;
  final Set<String> dealTypes;
  final Set<String> bodyTypes;
  final Set<String> conditions;
  final Set<String> regionalSpecs;
  final Set<String> transmissions;
  final Set<String> drivetrains;
  final Set<String> fuels;
  final Set<int> cylinders;

  /// [EngineBucket.value] ids from [SpecCatalog.engineSizes].
  final Set<String> engineSizes;
  final Set<int> doors;

  /// `8` means "8 or more" — see [SpecCatalog.seats].
  final Set<int> seats;
  final Set<String> sellerTypes;
  final bool warrantyOnly;
  final Set<String> exteriorColors;
  final Set<String> interiorColors;

  /// Governorate (the part after the comma in a listing's `region`).
  final Set<String> regions;

  /// Wilayat / city (the part before the comma).
  final Set<String> cities;
  final double? minPrice;
  final double? maxPrice;
  final int? maxMileage;
  final GallerySort sort;

  int get activeCount {
    var n = 0;
    if (make != null) n++;
    if (model != null) n++;
    if (trims.isNotEmpty) n++;
    if (fromYear != null || toYear != null) n++;
    if (dealTypes.isNotEmpty) n++;
    if (bodyTypes.isNotEmpty) n++;
    if (conditions.isNotEmpty) n++;
    if (regionalSpecs.isNotEmpty) n++;
    if (transmissions.isNotEmpty) n++;
    if (drivetrains.isNotEmpty) n++;
    if (fuels.isNotEmpty) n++;
    if (cylinders.isNotEmpty) n++;
    if (engineSizes.isNotEmpty) n++;
    if (doors.isNotEmpty) n++;
    if (seats.isNotEmpty) n++;
    if (sellerTypes.isNotEmpty) n++;
    if (warrantyOnly) n++;
    if (exteriorColors.isNotEmpty) n++;
    if (interiorColors.isNotEmpty) n++;
    if (regions.isNotEmpty) n++;
    if (cities.isNotEmpty) n++;
    if (maxMileage != null) n++;
    if (minPrice != null || maxPrice != null) n++;
    return n;
  }

  /// [specs] resolves the engine-size facet's bucket ids to litre ranges. It
  /// is passed in rather than looked up statically so the vocabulary can come
  /// from the API without this model reaching into a global.
  bool matches(GalleryListing l, SpecCatalog specs) {
    if (make != null && l.make != make) return false;
    if (model != null && l.model != model) return false;
    if (trims.isNotEmpty && !trims.contains(l.trim)) return false;
    if (fromYear != null && l.year < fromYear!) return false;
    if (toYear != null && l.year > toYear!) return false;
    if (dealTypes.isNotEmpty && !dealTypes.contains(l.dealType)) return false;
    if (bodyTypes.isNotEmpty && !bodyTypes.contains(l.bodyType)) return false;
    if (conditions.isNotEmpty && !conditions.contains(l.condition)) {
      return false;
    }
    if (regionalSpecs.isNotEmpty && !regionalSpecs.contains(l.regionalSpec)) {
      return false;
    }
    if (transmissions.isNotEmpty && !transmissions.contains(l.transmission)) {
      return false;
    }
    if (drivetrains.isNotEmpty && !drivetrains.contains(l.drivetrain)) {
      return false;
    }
    if (fuels.isNotEmpty && !fuels.contains(l.fuel)) return false;
    if (cylinders.isNotEmpty && !cylinders.contains(l.cylinders)) {
      return false;
    }
    if (engineSizes.isNotEmpty &&
        !engineSizes.any((id) {
          final bucket = specs.bucketOf(id);
          return bucket != null && bucket.contains(l.engineLitres);
        })) {
      return false;
    }
    if (doors.isNotEmpty && !doors.contains(l.doors)) return false;
    // The top seat option (8) reads as "8 or more".
    if (seats.isNotEmpty &&
        !seats.any((s) => s == 8 ? l.seats >= 8 : l.seats == s)) {
      return false;
    }
    if (sellerTypes.isNotEmpty && !sellerTypes.contains(l.sellerType)) {
      return false;
    }
    if (warrantyOnly && !l.hasWarranty) return false;
    if (exteriorColors.isNotEmpty &&
        !exteriorColors.contains(l.exteriorColor)) {
      return false;
    }
    if (interiorColors.isNotEmpty &&
        !interiorColors.contains(l.interiorColor)) {
      return false;
    }
    if (regions.isNotEmpty && !regions.contains(l.governorate)) return false;
    if (cities.isNotEmpty && !cities.contains(l.cityName)) return false;
    if (maxMileage != null && l.mileageValue > maxMileage!) return false;
    if (minPrice != null || maxPrice != null) {
      final p = l.price;
      if (p == null) return false;
      if (minPrice != null && p < minPrice!) return false;
      if (maxPrice != null && p > maxPrice!) return false;
    }
    return true;
  }

  List<GalleryListing> apply(
    Iterable<GalleryListing> feed,
    SpecCatalog specs,
  ) {
    final list = feed.where((l) => matches(l, specs)).toList();
    list.sort((a, b) => switch (sort) {
          GallerySort.newest =>
            a.postedMinutesAgo.compareTo(b.postedMinutesAgo),
          GallerySort.oldest =>
            b.postedMinutesAgo.compareTo(a.postedMinutesAgo),
          GallerySort.priceLowHigh => (a.price ?? double.infinity)
              .compareTo(b.price ?? double.infinity),
          GallerySort.priceHighLow => (b.price ?? -1).compareTo(a.price ?? -1),
          GallerySort.mileageLowHigh =>
            a.mileageValue.compareTo(b.mileageValue),
          GallerySort.yearNewOld => b.year.compareTo(a.year),
        });
    return list;
  }

  /// Query-string form for `GET /cars`. Multi-select facets are sent as
  /// repeated values; empty facets are omitted entirely.
  Map<String, dynamic> toQueryParameters() => compactJson({
        'make': make,
        'model': model,
        'trims': trims.isEmpty ? null : trims.toList(),
        'fromYear': fromYear,
        'toYear': toYear,
        'dealTypes': dealTypes.isEmpty ? null : dealTypes.toList(),
        'bodyTypes': bodyTypes.isEmpty ? null : bodyTypes.toList(),
        'conditions': conditions.isEmpty ? null : conditions.toList(),
        'regionalSpecs': regionalSpecs.isEmpty ? null : regionalSpecs.toList(),
        'transmissions': transmissions.isEmpty ? null : transmissions.toList(),
        'drivetrains': drivetrains.isEmpty ? null : drivetrains.toList(),
        'fuels': fuels.isEmpty ? null : fuels.toList(),
        'cylinders': cylinders.isEmpty ? null : cylinders.toList(),
        'engineSizes': engineSizes.isEmpty ? null : engineSizes.toList(),
        'doors': doors.isEmpty ? null : doors.toList(),
        'seats': seats.isEmpty ? null : seats.toList(),
        'sellerTypes': sellerTypes.isEmpty ? null : sellerTypes.toList(),
        'warrantyOnly': warrantyOnly ? true : null,
        'exteriorColors':
            exteriorColors.isEmpty ? null : exteriorColors.toList(),
        'interiorColors':
            interiorColors.isEmpty ? null : interiorColors.toList(),
        'regions': regions.isEmpty ? null : regions.toList(),
        'cities': cities.isEmpty ? null : cities.toList(),
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'maxMileage': maxMileage,
        'sort': sort.key,
      });

  CarsFilter copyWith({
    String? Function()? make,
    String? Function()? model,
    Set<String>? trims,
    int? Function()? fromYear,
    int? Function()? toYear,
    Set<String>? dealTypes,
    Set<String>? bodyTypes,
    Set<String>? conditions,
    Set<String>? regionalSpecs,
    Set<String>? transmissions,
    Set<String>? drivetrains,
    Set<String>? fuels,
    Set<int>? cylinders,
    Set<String>? engineSizes,
    Set<int>? doors,
    Set<int>? seats,
    Set<String>? sellerTypes,
    bool? warrantyOnly,
    Set<String>? exteriorColors,
    Set<String>? interiorColors,
    Set<String>? regions,
    Set<String>? cities,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    int? Function()? maxMileage,
    GallerySort? sort,
  }) =>
      CarsFilter(
        make: make != null ? make() : this.make,
        model: model != null ? model() : this.model,
        trims: trims ?? this.trims,
        fromYear: fromYear != null ? fromYear() : this.fromYear,
        toYear: toYear != null ? toYear() : this.toYear,
        dealTypes: dealTypes ?? this.dealTypes,
        bodyTypes: bodyTypes ?? this.bodyTypes,
        conditions: conditions ?? this.conditions,
        regionalSpecs: regionalSpecs ?? this.regionalSpecs,
        transmissions: transmissions ?? this.transmissions,
        drivetrains: drivetrains ?? this.drivetrains,
        fuels: fuels ?? this.fuels,
        cylinders: cylinders ?? this.cylinders,
        engineSizes: engineSizes ?? this.engineSizes,
        doors: doors ?? this.doors,
        seats: seats ?? this.seats,
        sellerTypes: sellerTypes ?? this.sellerTypes,
        warrantyOnly: warrantyOnly ?? this.warrantyOnly,
        exteriorColors: exteriorColors ?? this.exteriorColors,
        interiorColors: interiorColors ?? this.interiorColors,
        regions: regions ?? this.regions,
        cities: cities ?? this.cities,
        minPrice: minPrice != null ? minPrice() : this.minPrice,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        maxMileage: maxMileage != null ? maxMileage() : this.maxMileage,
        sort: sort ?? this.sort,
      );
}
