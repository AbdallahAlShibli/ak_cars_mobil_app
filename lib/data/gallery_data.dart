import 'package:flutter/material.dart';

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

enum GallerySort { newest, oldest, priceLowHigh, priceHighLow }

extension GallerySortX on GallerySort {
  String get label => switch (this) {
        GallerySort.newest => 'Newest to oldest',
        GallerySort.oldest => 'Oldest to newest',
        GallerySort.priceLowHigh => 'Price: low to high',
        GallerySort.priceHighLow => 'Price: high to low',
      };
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
    required this.cylinders,
    required this.transmission,
    required this.fuel,
    required this.drivetrain,
    required this.specGrade,
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
  final int cylinders;
  final String transmission;
  final String fuel;
  final String drivetrain;
  final String specGrade;
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

  String get postedLabel {
    if (postedMinutesAgo < 60) return '$postedMinutesAgo min ago';
    final h = postedMinutesAgo ~/ 60;
    return '$h h ago';
  }
}

abstract final class GalleryData {
  static const trimsByModel = {
    'Camry': ['SE', 'LE', 'XSE', 'XLE', 'GL', 'GLX'],
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
      cylinders: 4,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      specGrade: 'Second grade',
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
      cylinders: 4,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      specGrade: 'First grade',
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
      cylinders: 4,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      specGrade: 'Second grade',
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
      cylinders: 4,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      specGrade: 'First grade',
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
      tint: Color(0xFF94A3B8),
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
      cylinders: 4,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      specGrade: 'Second grade',
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
      cylinders: 8,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Four-wheel drive',
      specGrade: 'First grade',
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
      cylinders: 8,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Four-wheel drive',
      specGrade: 'First grade',
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
      cylinders: 6,
      transmission: 'Automatic',
      fuel: 'Petrol',
      drivetrain: 'Front-wheel drive',
      specGrade: 'First grade',
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
  ];

  static List<String> trimsFor(String model) =>
      trimsByModel[model] ?? const [];

  static List<GalleryListing> related(GalleryListing l) => listings
      .where((o) => o.id != l.id && o.model == l.model)
      .toList();
}
