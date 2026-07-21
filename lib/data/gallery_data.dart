import 'package:flutter/material.dart';

import 'car_spec_options.dart';

/// Cars-gallery marketplace data — mirrors the reference marketplace app:
/// vehicle types, makes rail, trim-filterable results, rich listing details.
/// Replace with `GET /api/cars` in Phase 2.

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
}

enum GallerySort {
  newest,
  oldest,
  priceLowHigh,
  priceHighLow,
  mileageLowHigh,
  yearNewOld,
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

/// Cars-market filter — instant, local-first (same pattern as [ShopFilter]),
/// modelled on a full marketplace filter: single-value criteria (make, model,
/// year range) plus multi-select facets (deal/body/spec/transmission/
/// drivetrain/fuel/cylinders/colors/region) that OR within a facet and AND
/// across facets. `null`/empty means "no constraint". Price and mileage
/// filters exclude "Ask for price" / unknown-value listings.
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

  /// [EngineBucket.value] ids from [CarSpecs.engineSizes].
  final Set<String> engineSizes;
  final Set<int> doors;

  /// `8` means "8 or more" — see [CarSpecs.seats].
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

  bool matches(GalleryListing l) {
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
    if (transmissions.isNotEmpty &&
        !transmissions.contains(l.transmission)) {
      return false;
    }
    if (drivetrains.isNotEmpty && !drivetrains.contains(l.drivetrain)) {
      return false;
    }
    if (fuels.isNotEmpty && !fuels.contains(l.fuel)) return false;
    if (cylinders.isNotEmpty && !cylinders.contains(l.cylinders)) {
      return false;
    }
    if (engineSizes.isNotEmpty && !engineSizes.any((id) {
      final bucket = CarSpecs.bucketOf(id);
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

  List<GalleryListing> apply(Iterable<GalleryListing> feed) {
    final list = feed.where(matches).toList();
    list.sort((a, b) => switch (sort) {
          GallerySort.newest =>
            a.postedMinutesAgo.compareTo(b.postedMinutesAgo),
          GallerySort.oldest =>
            b.postedMinutesAgo.compareTo(a.postedMinutesAgo),
          GallerySort.priceLowHigh => (a.price ?? double.infinity)
              .compareTo(b.price ?? double.infinity),
          GallerySort.priceHighLow =>
            (b.price ?? -1).compareTo(a.price ?? -1),
          GallerySort.mileageLowHigh =>
            a.mileageValue.compareTo(b.mileageValue),
          GallerySort.yearNewOld => b.year.compareTo(a.year),
        });
    return list;
  }

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
  final double? price; // null => "Ask for price"
  final String mileage;
  final String bodyType;

  /// 'New' | 'Used' — see [CarSpecs.conditions].
  final String condition;

  /// `0` for a pure EV — see [CarSpecs.cylinders].
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

  /// 'Owner' | 'Dealer' | 'Showroom' — see [CarSpecs.sellerTypes].
  final String sellerType;
  final int keys;
  final String exteriorColor;
  final Color exteriorSwatch;
  final String interiorColor;
  final Color interiorSwatch;
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
}

extension GalleryListingX on GalleryListing {
  String get displayTitle => '$year $make $model $trim'.trim();

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

  String get postedLabel {
    if (postedMinutesAgo < 60) return '$postedMinutesAgo min ago';
    final h = postedMinutesAgo ~/ 60;
    return '$h h ago';
  }
}

abstract final class GalleryData {
  /// Sub-model (trim) options per model — mirrors the marketplace's
  /// "Sub-Model" facet. Covers the feed's models plus popular ones so the
  /// filter is rarely empty; extend as inventory grows.
  static const trimsByModel = {
    // Toyota
    'Camry': ['SE', 'LE', 'XSE', 'XLE', 'GL', 'GLX'],
    'Corolla': ['XLI', 'GLI', 'SE', 'LE', 'XSE'],
    'Land Cruiser': ['GX', 'GXR', 'VX', 'VXR', 'GR Sport'],
    'Land Cruiser 70': ['LX', 'GXR'],
    'Prado': ['TXL', 'VXL', 'VX', 'GXR'],
    'Hilux': ['GLX', 'SR5', 'Adventure'],
    'RAV4': ['LE', 'XLE', 'Limited', 'Adventure'],
    'Fortuner': ['GX', 'GXR', 'VXR', 'Legender'],
    'Yaris': ['Y', 'Y-Plus'],
    // Nissan
    'Altima': ['S', 'SV', 'SL', 'SR', 'Platinum'],
    'Patrol': ['XE', 'SE', 'LE', 'Platinum', 'Nismo'],
    'Armada': ['SV', 'SL', 'Platinum'],
    'X-Trail': ['S', 'SV', 'SL'],
    'Sunny': ['S', 'SV', 'SL'],
    'Pathfinder': ['S', 'SV', 'SL', 'Platinum'],
    // Lexus
    'ES': ['250', '300h', '350'],
    'RX': ['300', '350', '350h', '500h'],
    'LX': ['570', '600'],
    'GX': ['460', '550'],
    'NX': ['250', '350', '350h'],
    // Honda
    'Accord': ['LX', 'EX', 'Sport', 'Touring'],
    'Civic': ['LX', 'EX', 'Sport', 'Touring'],
    'CR-V': ['LX', 'EX', 'Touring'],
    // Hyundai
    'Elantra': ['SE', 'SEL', 'Limited', 'N Line'],
    'Sonata': ['SE', 'SEL', 'Limited', 'N Line'],
    'Tucson': ['GL', 'GLS', 'Limited'],
    'Santa Fe': ['GL', 'GLS', 'Limited', 'Calligraphy'],
    'Accent': ['GL', 'GLS', 'SR'],
    // Mitsubishi
    'Pajero': ['GLS', 'GLX', 'Signature'],
    'Montero Sport': ['GLX', 'GLS'],
    // Kia
    'Sportage': ['LX', 'EX', 'GT-Line'],
    'Sorento': ['LX', 'EX', 'SX'],
    'Cerato': ['LX', 'EX', 'GT'],
  };

  static const listings = [
    GalleryListing(
      id: 'g1',
      make: 'Toyota',
      model: 'Camry',
      trim: 'SE',
      year: 2017,
      price: null,
      mileage: '200,000+',
      bodyType: 'Sedan',
      condition: 'Used',
      cylinders: 4,
      engineLitres: 2.5,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      doors: 4,
      seats: 5,
      regionalSpec: 'GCC',
      hasWarranty: false,
      sellerType: 'Owner',
      keys: 1,
      exteriorColor: 'Silver',
      exteriorSwatch: Color(0xFFC0C4CC),
      interiorColor: 'Black',
      interiorSwatch: Color(0xFF17181A),
      region: 'Al Khaburah, North Al Batinah',
      postedMinutesAgo: 2,
      dealType: 'Sale only',
      photoCount: 22,
      icon: Icons.directions_car_rounded,
      tint: Color(0xFF8B99AD),
      sellerName: 'Mohad Alkhawaldi',
      sellerJoined: '31/1/2023',
      sellerAds: 10,
      sellerFollowers: 7,
      description:
          'Camry 2017 SE — 4 cylinders, 2.5L engine, automatic. Bluetooth, '
          'rear camera, traction control. Oman + UAE insurance. Financing '
          'available. Silver exterior, black interior.',
    ),
    GalleryListing(
      id: 'g2',
      make: 'Toyota',
      model: 'Camry',
      trim: 'SE',
      year: 2023,
      price: 6200,
      mileage: '48,000',
      bodyType: 'Sedan',
      condition: 'Used',
      cylinders: 4,
      engineLitres: 2.5,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      doors: 4,
      seats: 5,
      regionalSpec: 'GCC',
      hasWarranty: true,
      sellerType: 'Owner',
      keys: 2,
      exteriorColor: 'Silver',
      exteriorSwatch: Color(0xFFC0C4CC),
      interiorColor: 'Gray',
      interiorSwatch: Color(0xFF6B7280),
      region: 'Bawshar, Muscat',
      postedMinutesAgo: 3,
      dealType: 'Sale only',
      photoCount: 14,
      icon: Icons.directions_car_filled_rounded,
      tint: Color(0xFF64748B),
      sellerName: 'Salim Al Habsi',
      sellerJoined: '12/6/2024',
      sellerAds: 3,
      sellerFollowers: 12,
      description:
          'Camry 2023 SE under warranty, agency serviced, first owner. '
          'No accidents, GCC specs.',
    ),
    GalleryListing(
      id: 'g3',
      make: 'Toyota',
      model: 'Camry',
      trim: 'SE',
      year: 2016,
      price: 3200,
      mileage: '180,000',
      bodyType: 'Sedan',
      condition: 'Used',
      cylinders: 4,
      engineLitres: 2.5,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      doors: 4,
      seats: 5,
      regionalSpec: 'GCC',
      hasWarranty: false,
      sellerType: 'Owner',
      keys: 1,
      exteriorColor: 'Maroon',
      exteriorSwatch: Color(0xFF7B2D3B),
      interiorColor: 'Beige',
      interiorSwatch: Color(0xFFD9C9A8),
      region: 'Seeb, Muscat',
      postedMinutesAgo: 5,
      dealType: 'Sale or exchange',
      photoCount: 9,
      icon: Icons.directions_car_rounded,
      tint: Color(0xFF8A5560),
      sellerName: 'Nasser Al Riyami',
      sellerJoined: '4/3/2022',
      sellerAds: 22,
      sellerFollowers: 40,
      description:
          'Clean Camry 2016, new tyres, recent oil service. Price slightly '
          'negotiable.',
    ),
    GalleryListing(
      id: 'g4',
      make: 'Toyota',
      model: 'Camry',
      trim: 'XSE',
      year: 2021,
      price: 8000,
      mileage: '76,000',
      bodyType: 'Sedan',
      condition: 'Used',
      cylinders: 4,
      engineLitres: 2.5,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      doors: 4,
      seats: 5,
      regionalSpec: 'American',
      hasWarranty: false,
      sellerType: 'Owner',
      keys: 2,
      exteriorColor: 'White',
      exteriorSwatch: Color(0xFFF3F4F6),
      interiorColor: 'Red',
      interiorSwatch: Color(0xFF9B1C31),
      region: 'Nizwa, Ad Dakhiliyah',
      postedMinutesAgo: 6,
      dealType: 'Sale only',
      photoCount: 18,
      icon: Icons.directions_car_filled_rounded,
      tint: Color(0xFFB0A996),
      sellerName: 'Ahmed Al Abri',
      sellerJoined: '19/9/2023',
      sellerAds: 5,
      sellerFollowers: 15,
      description:
          'Camry XSE 2021 full option — panoramic roof, red leather, '
          'wireless CarPlay.',
    ),
    GalleryListing(
      id: 'g5',
      make: 'Toyota',
      model: 'Camry',
      trim: 'LE',
      year: 2016,
      price: 3200,
      mileage: '210,000',
      bodyType: 'Sedan',
      condition: 'Used',
      cylinders: 4,
      engineLitres: 2.5,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      doors: 4,
      seats: 5,
      regionalSpec: 'American',
      hasWarranty: false,
      sellerType: 'Owner',
      keys: 1,
      exteriorColor: 'Gray',
      exteriorSwatch: Color(0xFF9CA3AF),
      interiorColor: 'Black',
      interiorSwatch: Color(0xFF17181A),
      region: 'Sohar, North Al Batinah',
      postedMinutesAgo: 7,
      dealType: 'Sale only',
      photoCount: 11,
      icon: Icons.directions_car_rounded,
      tint: Color(0xFF7C8899),
      sellerName: 'Khalid Al Balushi',
      sellerJoined: '2/11/2021',
      sellerAds: 14,
      sellerFollowers: 28,
      description: 'Economical daily driver, AC ice cold, ready to transfer.',
    ),
    GalleryListing(
      id: 'g6',
      make: 'Nissan',
      model: 'Armada',
      trim: '',
      year: 2018,
      price: 9300,
      mileage: '130,000',
      bodyType: 'SUV',
      condition: 'Used',
      cylinders: 8,
      engineLitres: 5.6,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Four-wheel drive',
      doors: 5,
      seats: 8,
      regionalSpec: 'GCC',
      hasWarranty: false,
      sellerType: 'Dealer',
      keys: 2,
      exteriorColor: 'Black',
      exteriorSwatch: Color(0xFF17181A),
      interiorColor: 'Beige',
      interiorSwatch: Color(0xFFD9C9A8),
      region: 'Al Khuwair, Muscat',
      postedMinutesAgo: 1,
      dealType: 'Sale only',
      photoCount: 16,
      icon: Icons.airport_shuttle_rounded,
      tint: Color(0xFF3F4756),
      sellerName: 'Yousef Al Lawati',
      sellerJoined: '8/5/2020',
      sellerAds: 31,
      sellerFollowers: 96,
      description:
          'Armada 2018 V8, full service history, screens + 360 camera.',
    ),
    GalleryListing(
      id: 'g7',
      make: 'Nissan',
      model: 'Patrol',
      trim: 'LE',
      year: 2019,
      price: 12500,
      mileage: '98,000',
      bodyType: 'SUV',
      condition: 'Used',
      cylinders: 8,
      engineLitres: 5.6,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Four-wheel drive',
      doors: 5,
      seats: 7,
      regionalSpec: 'GCC',
      hasWarranty: false,
      sellerType: 'Owner',
      keys: 2,
      exteriorColor: 'White',
      exteriorSwatch: Color(0xFFF3F4F6),
      interiorColor: 'Brown',
      interiorSwatch: Color(0xFF6B4A2F),
      region: 'Salalah, Dhofar',
      postedMinutesAgo: 12,
      dealType: 'Sale or exchange',
      photoCount: 20,
      icon: Icons.airport_shuttle_rounded,
      tint: Color(0xFF8794A6),
      sellerName: 'Hamed Al Mashani',
      sellerJoined: '25/2/2023',
      sellerAds: 8,
      sellerFollowers: 19,
      description: 'Patrol LE Platinum, no desert use, garage kept.',
    ),
    GalleryListing(
      id: 'g8',
      make: 'Lexus',
      model: 'ES',
      trim: '350',
      year: 2021,
      price: 9800,
      mileage: '64,000',
      bodyType: 'Sedan',
      condition: 'Used',
      cylinders: 6,
      engineLitres: 3.5,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      doors: 4,
      seats: 5,
      regionalSpec: 'Japanese',
      hasWarranty: false,
      sellerType: 'Owner',
      keys: 2,
      exteriorColor: 'Blue',
      exteriorSwatch: Color(0xFF1E3A5F),
      interiorColor: 'White',
      interiorSwatch: Color(0xFFEDEDED),
      region: 'Ruwi, Muscat',
      postedMinutesAgo: 25,
      dealType: 'Sale only',
      photoCount: 12,
      icon: Icons.directions_car_filled_rounded,
      tint: Color(0xFF41536B),
      sellerName: 'Fatma Al Zadjali',
      sellerJoined: '14/7/2024',
      sellerAds: 2,
      sellerFollowers: 5,
      description: 'Lexus ES350 — lady driven, agency maintained, GCC.',
    ),
    GalleryListing(
      id: 'g9',
      make: 'Toyota',
      model: 'Hilux',
      trim: 'GLX',
      year: 2022,
      price: 7400,
      mileage: '85,000',
      bodyType: 'Pickup',
      condition: 'Used',
      cylinders: 4,
      engineLitres: 2.4,
      transmission: 'Manual',
      fuel: 'Diesel',
      drivetrain: 'Four-wheel drive',
      doors: 4,
      seats: 5,
      regionalSpec: 'GCC',
      hasWarranty: false,
      sellerType: 'Dealer',
      keys: 2,
      exteriorColor: 'White',
      exteriorSwatch: Color(0xFFF3F4F6),
      interiorColor: 'Gray',
      interiorSwatch: Color(0xFF6B7280),
      region: 'Ibri, Ad Dhahirah',
      postedMinutesAgo: 40,
      dealType: 'Sale or exchange',
      photoCount: 15,
      icon: Icons.local_shipping_rounded,
      tint: Color(0xFF9AA4B2),
      sellerName: 'Al Dhahirah Motors',
      sellerJoined: '3/4/2021',
      sellerAds: 47,
      sellerFollowers: 130,
      description:
          'Hilux 2.4L diesel manual, double cab 4×4. Work-ready, new '
          'tyres, full service history.',
    ),
    GalleryListing(
      id: 'g10',
      make: 'Toyota',
      model: 'RAV4',
      trim: 'Limited',
      year: 2023,
      price: 10200,
      mileage: '39,000',
      bodyType: 'Crossover',
      condition: 'Used',
      cylinders: 4,
      engineLitres: 2.5,
      transmission: 'CVT',
      fuel: 'Hybrid',
      drivetrain: 'All-wheel drive',
      doors: 5,
      seats: 5,
      regionalSpec: 'Japanese',
      hasWarranty: true,
      sellerType: 'Showroom',
      keys: 2,
      exteriorColor: 'Blue',
      exteriorSwatch: Color(0xFF1E3A5F),
      interiorColor: 'Black',
      interiorSwatch: Color(0xFF17181A),
      region: 'Barka, South Al Batinah',
      postedMinutesAgo: 55,
      dealType: 'Sale only',
      photoCount: 19,
      icon: Icons.directions_car_filled_rounded,
      tint: Color(0xFF41536B),
      sellerName: 'Batinah Auto Showroom',
      sellerJoined: '17/8/2022',
      sellerAds: 62,
      sellerFollowers: 210,
      description:
          'RAV4 Hybrid AWD, agency warranty valid until 2027. Very low '
          'fuel consumption, one owner.',
    ),
    GalleryListing(
      id: 'g11',
      make: 'Tesla',
      model: 'Model Y',
      trim: '',
      year: 2024,
      price: 14500,
      mileage: '18,000',
      bodyType: 'Crossover',
      condition: 'Used',
      cylinders: 0,
      engineLitres: 0.0,
      transmission: 'Single-speed',
      fuel: 'Electric',
      drivetrain: 'All-wheel drive',
      doors: 5,
      seats: 5,
      regionalSpec: 'American',
      hasWarranty: true,
      sellerType: 'Owner',
      keys: 2,
      exteriorColor: 'White',
      exteriorSwatch: Color(0xFFF3F4F6),
      interiorColor: 'White',
      interiorSwatch: Color(0xFFEDEDED),
      region: 'Muscat, Muscat',
      postedMinutesAgo: 70,
      dealType: 'Sale only',
      photoCount: 13,
      icon: Icons.directions_car_filled_rounded,
      tint: Color(0xFFB6BEC9),
      sellerName: 'Rashid Al Harthy',
      sellerJoined: '9/1/2024',
      sellerAds: 1,
      sellerFollowers: 3,
      description:
          'Model Y Long Range, home charger included, battery warranty '
          'transferable.',
    ),
    GalleryListing(
      id: 'g12',
      make: 'Nissan',
      model: 'Patrol',
      trim: 'Platinum',
      year: 2025,
      price: 21900,
      mileage: '0',
      bodyType: 'SUV',
      condition: 'New',
      cylinders: 8,
      engineLitres: 5.6,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Four-wheel drive',
      doors: 5,
      seats: 8,
      regionalSpec: 'GCC',
      hasWarranty: true,
      sellerType: 'Showroom',
      keys: 2,
      exteriorColor: 'Black',
      exteriorSwatch: Color(0xFF17181A),
      interiorColor: 'Beige',
      interiorSwatch: Color(0xFFD9C9A8),
      region: 'Sohar, North Al Batinah',
      postedMinutesAgo: 90,
      dealType: 'Sale only',
      photoCount: 24,
      icon: Icons.airport_shuttle_rounded,
      tint: Color(0xFF3F4756),
      sellerName: 'Sohar Prime Motors',
      sellerJoined: '5/2/2019',
      sellerAds: 88,
      sellerFollowers: 340,
      description:
          'Brand new Patrol Platinum 2025, zero km, 3-year agency '
          'warranty. Registration and insurance handled for you.',
    ),
  ];

  static List<String> trimsFor(String model) =>
      trimsByModel[model] ?? const [];

  static List<GalleryListing> related(GalleryListing l) => listings
      .where((o) => o.id != l.id && o.model == l.model)
      .toList();
}
