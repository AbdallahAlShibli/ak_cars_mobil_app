import 'package:flutter/material.dart';

import 'models.dart';

/// Demo data. Replace with the AKCars API client in Phase 2.
abstract final class MockData {
  /// Governorates where parts/providers operate (subset of OmanLocations).
  static const regions = [
    'Muscat',
    'North Al Batinah',
    'Ad Dakhiliyah',
    'Dhofar',
  ];

  static const providers = [
    ServiceProvider(
      id: 'p1',
      name: 'Al Noor Workshop',
      area: 'Al Khuwair',
      region: 'Muscat',
      distanceKm: 2.4,
      verified: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
    ),
    ServiceProvider(
      id: 'p2',
      name: 'Gulf Auto Care',
      area: 'Seeb',
      region: 'Muscat',
      distanceKm: 6.1,
      verified: true,
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
    ),
    ServiceProvider(
      id: 'p3',
      name: 'Sohar Speed Garage',
      area: 'Sohar',
      region: 'North Al Batinah',
      distanceKm: 18.0,
      verified: false,
      fulfillments: {Fulfillment.workshop},
    ),
    ServiceProvider(
      id: 'p4',
      name: 'Qurum Auto Experts',
      area: 'Qurum',
      region: 'Muscat',
      distanceKm: 4.2,
      verified: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
      pickupFee: 2,
    ),
    ServiceProvider(
      id: 'p5',
      name: 'Nizwa Car Care',
      area: 'Nizwa',
      region: 'Ad Dakhiliyah',
      distanceKm: 32.0,
      verified: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
    ),
    ServiceProvider(
      id: 'p6',
      name: 'Salalah Motors Hub',
      area: 'Salalah',
      region: 'Dhofar',
      distanceKm: 45.0,
      verified: true,
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
      pickupFee: 4,
    ),
    ServiceProvider(
      id: 'p7',
      name: 'Barka Quick Fix',
      area: 'Barka',
      region: 'South Al Batinah',
      distanceKm: 22.0,
      verified: false,
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
    ),
  ];

  /// Offerings grouped per category — used to compare providers.
  static List<ServiceOffering> offeringsFor(String categoryId) =>
      offerings.where((o) => o.categoryId == categoryId).toList();

  static int providerCountFor(String categoryId) =>
      offeringsFor(categoryId).map((o) => o.provider.id).toSet().length;

  /// "Car service" packages — big cards, like the reference design.
  static const categories = [
    ServiceCategory(
      id: 'major',
      name: 'Major\nService',
      icon: Icons.settings_suggest_rounded,
      providerCount: 3,
      fromPrice: 45,
      badge: 'FREE OIL',
      primary: true,
    ),
    ServiceCategory(
      id: 'full',
      name: 'Full\nService',
      icon: Icons.build_rounded,
      providerCount: 4,
      fromPrice: 30,
      primary: true,
    ),
    ServiceCategory(
      id: 'express',
      name: 'Express\nService',
      icon: Icons.bolt_rounded,
      providerCount: 6,
      fromPrice: 12,
      primary: true,
    ),
    // ------------------------------------------- other services
    ServiceCategory(
      id: 'repair',
      name: 'Car\nRepair',
      icon: Icons.car_repair,
      providerCount: 5,
      note: 'quote after inspection',
    ),
    ServiceCategory(
      id: 'sos',
      name: 'Roadside\nAssistance',
      icon: Icons.rv_hookup,
      providerCount: 2,
      note: 'on call · avg 25 min',
      emergency: true,
    ),
    ServiceCategory(
      id: 'tyres',
      name: 'Tyres &\nWheel care',
      icon: Icons.tire_repair,
      providerCount: 4,
      fromPrice: 6,
    ),
    ServiceCategory(
      id: 'detailing',
      name: 'Car\nDetailing',
      icon: Icons.local_car_wash,
      providerCount: 3,
      fromPrice: 12,
    ),
    ServiceCategory(
      id: 'battery',
      name: 'Battery\n& Power',
      icon: Icons.battery_charging_full_rounded,
      providerCount: 5,
      fromPrice: 5,
    ),
    ServiceCategory(
      id: 'ac',
      name: 'AC\nCare',
      icon: Icons.ac_unit_rounded,
      providerCount: 4,
      fromPrice: 15,
    ),
    ServiceCategory(
      id: 'diag',
      name: 'Engine\nDiagnostics',
      icon: Icons.monitor_heart_outlined,
      providerCount: 7,
      fromPrice: 8,
    ),
    ServiceCategory(
      id: 'contracts',
      name: 'Service\nContracts',
      icon: Icons.assignment_turned_in_outlined,
      providerCount: 2,
      fromPrice: 120,
    ),
  ];

  static List<ServiceCategory> get primaryCategories =>
      categories.where((c) => c.primary).toList();

  static List<ServiceCategory> get otherCategories =>
      categories.where((c) => !c.primary).toList();

  static final offerings = [
    ServiceOffering(
      id: 'o1',
      categoryId: 'express',
      name: 'Express service',
      provider: providers[0],
      description:
          'Oil + filter replacement and a 10-point safety check, in and out '
          'within the hour.',
      price: 12,
      durationMin: 45,
    ),
    ServiceOffering(
      id: 'o2',
      categoryId: 'express',
      name: 'Express service (synthetic)',
      provider: providers[1],
      description: 'Full synthetic oil, genuine filter, fluid top-ups.',
      price: 18,
      durationMin: 50,
    ),
    ServiceOffering(
      id: 'o3',
      categoryId: 'ac',
      name: 'AC care',
      provider: providers[1],
      description: 'Gas recharge, leak test, cabin filter check.',
      price: 15,
      durationMin: 60,
    ),
    ServiceOffering(
      id: 'o4',
      categoryId: 'repair',
      name: 'Car repair & inspection',
      provider: providers[0],
      description: 'Full inspection first — itemized quote before any work.',
    ),
    ServiceOffering(
      id: 'o5',
      categoryId: 'diag',
      name: 'Engine diagnostics',
      provider: providers[2],
      description: 'Full OBD scan with printed report.',
      price: 8,
      durationMin: 30,
    ),
    ServiceOffering(
      id: 'o6',
      categoryId: 'sos',
      name: 'Roadside assistance',
      provider: providers[1],
      description: 'Battery boost, tyre change, tow coordination.',
      price: 10,
      durationMin: 30,
    ),
    ServiceOffering(
      id: 'o7',
      categoryId: 'battery',
      name: 'Battery replacement',
      provider: providers[1],
      description: 'Test, supply and fit — old battery recycled.',
      price: 5,
      durationMin: 20,
    ),
    ServiceOffering(
      id: 'o8',
      categoryId: 'major',
      name: 'Major service',
      provider: providers[0],
      description:
          'Complete service: engine oil FREE, all filters, brakes check, '
          'fluids, belts and a 40-point inspection.',
      price: 45,
      durationMin: 180,
    ),
    ServiceOffering(
      id: 'o9',
      categoryId: 'full',
      name: 'Full service',
      provider: providers[1],
      description:
          'Oil & filters, brake and suspension check, AC performance test, '
          '25-point inspection.',
      price: 30,
      durationMin: 120,
    ),
    ServiceOffering(
      id: 'o10',
      categoryId: 'tyres',
      name: 'Tyre change & balancing',
      provider: providers[2],
      description: 'Fitting, balancing and pressure check per tyre.',
      price: 6,
      durationMin: 30,
    ),
    ServiceOffering(
      id: 'o11',
      categoryId: 'detailing',
      name: 'Car detailing',
      provider: providers[1],
      description: 'Interior deep clean, exterior polish and wax.',
      price: 12,
      durationMin: 90,
    ),
    ServiceOffering(
      id: 'o12',
      categoryId: 'contracts',
      name: 'Annual service contract',
      provider: providers[0],
      description:
          'All routine services for a year — priority booking and free '
          'pickup included.',
      price: 120,
      durationMin: null,
    ),
    // ----------------------------------------- more workshops (staging)
    ServiceOffering(
      id: 'o13',
      categoryId: 'major',
      name: 'Major service',
      provider: providers[3],
      description:
          'Full major service with genuine parts, free oil and a wash.',
      price: 52,
      durationMin: 200,
    ),
    ServiceOffering(
      id: 'o14',
      categoryId: 'major',
      name: 'Major service',
      provider: providers[5],
      description: 'Dealer-level major service with 12-month warranty.',
      price: 48,
      durationMin: 190,
    ),
    ServiceOffering(
      id: 'o15',
      categoryId: 'full',
      name: 'Full service',
      provider: providers[4],
      description: 'Oil, filters and 25-point check by certified techs.',
      price: 28,
      durationMin: 110,
    ),
    ServiceOffering(
      id: 'o16',
      categoryId: 'express',
      name: 'Express service',
      provider: providers[3],
      description: '30-minute oil change while you wait, coffee included.',
      price: 14,
      durationMin: 30,
    ),
    ServiceOffering(
      id: 'o17',
      categoryId: 'sos',
      name: 'Roadside assistance',
      provider: providers[6],
      description: 'Jump start, fuel delivery and towing across Al Batinah.',
      price: 8,
      durationMin: 35,
    ),
    ServiceOffering(
      id: 'o18',
      categoryId: 'sos',
      name: 'Roadside assistance',
      provider: providers[4],
      description: '24/7 rescue around Ad Dakhiliyah highways.',
      price: 12,
      durationMin: 30,
    ),
    ServiceOffering(
      id: 'o19',
      categoryId: 'repair',
      name: 'Car repair & inspection',
      provider: providers[3],
      description: 'Mechanical and electrical repair — quote first.',
    ),
    ServiceOffering(
      id: 'o20',
      categoryId: 'tyres',
      name: 'Tyre change & balancing',
      provider: providers[5],
      description: 'All sizes in stock, nitrogen fill included.',
      price: 7,
      durationMin: 25,
    ),
    ServiceOffering(
      id: 'o21',
      categoryId: 'detailing',
      name: 'Car detailing',
      provider: providers[3],
      description: 'Ceramic-grade polish, interior shampoo, engine bay.',
      price: 18,
      durationMin: 120,
    ),
    ServiceOffering(
      id: 'o22',
      categoryId: 'battery',
      name: 'Battery replacement',
      provider: providers[6],
      description: 'Free delivery and fitting anywhere in Barka.',
      price: 6,
      durationMin: 25,
    ),
    ServiceOffering(
      id: 'o23',
      categoryId: 'ac',
      name: 'AC care',
      provider: providers[5],
      description: 'Full AC overhaul — compressor check and re-gas.',
      price: 18,
      durationMin: 75,
    ),
    ServiceOffering(
      id: 'o24',
      categoryId: 'diag',
      name: 'Engine diagnostics',
      provider: providers[4],
      description: 'OBD scan + road test with written findings.',
      price: 10,
      durationMin: 40,
    ),
    ServiceOffering(
      id: 'o25',
      categoryId: 'contracts',
      name: 'Annual service contract',
      provider: providers[5],
      description: 'Two majors + two express services per year, Dhofar.',
      price: 140,
      durationMin: null,
    ),
  ];

  static const addOnsByProvider = {
    'p1': [
      AddOn(id: 'a1', name: 'Tyre rotation', price: 4, isPart: false),
      AddOn(id: 'a2', name: 'AC gas top-up', price: 8, isPart: false),
      AddOn(id: 'a3', name: 'Genuine oil filter', price: 3.5, isPart: true),
      AddOn(id: 'a4', name: 'Wiper blades pair', price: 5, isPart: true),
    ],
    'p2': [
      AddOn(id: 'a5', name: 'Interior detailing', price: 12, isPart: false),
      AddOn(id: 'a6', name: 'Cabin filter', price: 4, isPart: true),
    ],
    'p3': [
      AddOn(id: 'a7', name: 'Engine flush', price: 6, isPart: false),
    ],
  };

  static const partCategories = {
    'filters': 'Filters',
    'batteries': 'Batteries',
    'brakes': 'Brakes',
    'tyres': 'Tyres',
    'lights': 'Lights',
  };

  static const products = [
    Product(
      id: 'pr1',
      name: 'Genuine oil filter',
      price: 3.5,
      categoryId: 'filters',
      providerId: 'p1',
      region: 'Muscat',
      icon: Icons.filter_alt_outlined,
      fits: {'Toyota Camry'},
      rating: 4.8,
    ),
    Product(
      id: 'pr2',
      name: 'Battery 70Ah AGM',
      price: 28,
      categoryId: 'batteries',
      providerId: 'p2',
      region: 'Muscat',
      icon: Icons.battery_full_rounded,
      fits: {'any'},
      rating: 4.6,
      oldPrice: 32,
    ),
    Product(
      id: 'pr3',
      name: 'Brake pads — front',
      price: 18,
      categoryId: 'brakes',
      providerId: 'p1',
      region: 'Muscat',
      icon: Icons.album_outlined,
      fits: {'Toyota Camry', 'Nissan Patrol'},
      rating: 4.7,
    ),
    Product(
      id: 'pr4',
      name: 'LED headlight kit',
      price: 9.5,
      categoryId: 'lights',
      providerId: 'p2',
      region: 'Muscat',
      icon: Icons.lightbulb_outline_rounded,
      fits: {'any'},
      rating: 4.3,
      oldPrice: 12,
    ),
    Product(
      id: 'pr5',
      name: 'All-terrain tyre 265/60R18',
      price: 38,
      categoryId: 'tyres',
      providerId: 'p3',
      region: 'North Al Batinah',
      icon: Icons.trip_origin_rounded,
      fits: {'Nissan Patrol'},
      rating: 4.5,
    ),
    Product(
      id: 'pr6',
      name: 'Cabin air filter',
      price: 4,
      categoryId: 'filters',
      providerId: 'p2',
      region: 'Muscat',
      icon: Icons.air_rounded,
      fits: {'any'},
      rating: 4.2,
      oldPrice: 5,
    ),
  ];

  static const listings = [
    CarListing(
      id: 'l1',
      title: 'Lexus ES 350',
      year: 2021,
      km: 64000,
      region: 'Muscat',
      price: 9800,
      spec: 'GCC specs',
      icon: Icons.directions_car_filled_rounded,
      photoCount: 12,
    ),
    CarListing(
      id: 'l2',
      title: 'Nissan Patrol',
      year: 2019,
      km: 98000,
      region: 'Al Batinah',
      price: 12500,
      spec: 'Full option',
      icon: Icons.airport_shuttle_rounded,
      photoCount: 8,
    ),
    CarListing(
      id: 'l3',
      title: 'Toyota Corolla',
      year: 2022,
      km: 31000,
      region: 'Muscat',
      price: 6400,
      spec: 'Agency maintained',
      icon: Icons.directions_car_rounded,
      photoCount: 10,
    ),
  ];

  static const slots = ['9:00', '10:30', '13:00', '16:00'];
  static const bookedSlots = {'16:00'};
}
