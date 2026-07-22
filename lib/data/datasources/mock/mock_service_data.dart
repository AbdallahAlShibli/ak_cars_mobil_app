import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../models/add_on.dart';
import '../../models/service_category.dart';
import '../../models/service_offering.dart';
import '../../models/service_provider.dart';

/// What one workshop sells within one category.
///
/// A null [_Sale.price] means "quote after inspection"; a null
/// [_Sale.minutes] means the job has no fixed duration (a yearly contract, an
/// open-ended repair).
typedef _Sale = ({double? price, int? minutes});

/// Customer-facing wording for a category, shared by every workshop selling
/// it.
typedef _Copy = ({L name, L description});

/// Demo data for the service marketplace — providers, categories, offerings,
/// add-ons and bookable slots.
///
/// Only `MockServiceMarketplaceService` reads this file. Phase 2 replaces it
/// with the `/service-marketplace/*` endpoints.
///
/// **Coverage rule.** The services page filters strictly by governorate and
/// only widens when the user asks — or, silently, when the selected
/// governorate has nothing to show. So every governorate here carries at
/// least two workshops that between them sell *all* of [categories]. A hole
/// makes the region filter look broken: under the old data a Muscat user who
/// tapped "Tyres" got a sheet of Sohar and Salalah workshops, because no
/// Muscat workshop sold tyres at all. [_catalogue] is the matrix that
/// guarantees coverage; `services_region_test.dart` asserts it.
abstract final class MockServiceData {
  /// Grouped by governorate — `providerRegions`, and therefore the order of
  /// the region picker, is derived from this list.
  static const providers = <ServiceProvider>[
    // ------------------------------------------------------------ Muscat
    ServiceProvider(
      id: 'p1',
      name: L('ورشة النور', 'Al Noor Workshop'),
      area: 'Al Khuwair',
      region: 'Muscat',
      distanceKm: 2.4,
      verified: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
    ),
    ServiceProvider(
      id: 'p2',
      name: L('الخليج للعناية بالسيارات', 'Gulf Auto Care'),
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
      id: 'p4',
      name: L('خبراء القرم للسيارات', 'Qurum Auto Experts'),
      area: 'Qurum',
      region: 'Muscat',
      distanceKm: 4.2,
      verified: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
      pickupFee: 2,
    ),
    // -------------------------------------------------- North Al Batinah
    ServiceProvider(
      id: 'p3',
      name: L('كراج صحار سبيد', 'Sohar Speed Garage'),
      area: 'Sohar',
      region: 'North Al Batinah',
      distanceKm: 18.0,
      verified: false,
      fulfillments: {Fulfillment.workshop},
    ),
    ServiceProvider(
      id: 'p8',
      name: L('مركز صحم للسيارات', 'Saham Auto Centre'),
      area: 'Saham',
      region: 'North Al Batinah',
      distanceKm: 26.0,
      verified: true,
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
    ),
    // -------------------------------------------------- South Al Batinah
    ServiceProvider(
      id: 'p7',
      name: L('بركاء كويك فكس', 'Barka Quick Fix'),
      area: 'Barka',
      region: 'South Al Batinah',
      distanceKm: 22.0,
      verified: false,
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
    ),
    ServiceProvider(
      id: 'p9',
      name: L('الرستاق لميكانيكا السيارات', 'Rustaq Motor Works'),
      area: 'Rustaq',
      region: 'South Al Batinah',
      distanceKm: 38.0,
      verified: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
      pickupFee: 4,
    ),
    // ----------------------------------------------------- Ad Dakhiliyah
    ServiceProvider(
      id: 'p5',
      name: L('نزوى للعناية بالسيارات', 'Nizwa Car Care'),
      area: 'Nizwa',
      region: 'Ad Dakhiliyah',
      distanceKm: 32.0,
      verified: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
    ),
    ServiceProvider(
      id: 'p10',
      name: L('نقطة خدمة سمائل', 'Samail Service Point'),
      area: 'Samail',
      region: 'Ad Dakhiliyah',
      distanceKm: 24.0,
      verified: false,
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
    ),
    // ------------------------------------------------------------ Dhofar
    ServiceProvider(
      id: 'p6',
      name: L('مركز صلالة للمحركات', 'Salalah Motors Hub'),
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
      id: 'p11',
      name: L('كراج طاقة للسيارات', 'Taqah Auto Garage'),
      area: 'Taqah',
      region: 'Dhofar',
      distanceKm: 52.0,
      verified: false,
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
    ),
  ];

  /// "Car service" packages render as big cards ([ServiceCategory.primary]);
  /// the rest are "Other services" tiles.
  static const categories = <ServiceCategory>[
    ServiceCategory(
      id: 'major',
      name: L('صيانة\nشاملة', 'Major\nService'),
      icon: Icons.settings_suggest_rounded,
      badge: L('زيت مجاني', 'FREE OIL'),
      primary: true,
    ),
    ServiceCategory(
      id: 'full',
      name: L('صيانة\nكاملة', 'Full\nService'),
      icon: Icons.build_rounded,
      primary: true,
    ),
    ServiceCategory(
      id: 'express',
      name: L('صيانة\nسريعة', 'Express\nService'),
      icon: Icons.bolt_rounded,
      primary: true,
    ),
    // ------------------------------------------- other services
    ServiceCategory(
      id: 'repair',
      name: L('إصلاح\nالسيارات', 'Car\nRepair'),
      icon: Icons.car_repair,
      note: L('عرض سعر بعد الفحص', 'quote after inspection'),
    ),
    ServiceCategory(
      id: 'sos',
      name: L('مساعدة\nعلى الطريق', 'Roadside\nAssistance'),
      icon: Icons.rv_hookup,
      note: L('عند الطلب · متوسط 25 دقيقة', 'on call · avg 25 min'),
      emergency: true,
    ),
    ServiceCategory(
      id: 'tyres',
      name: L('إطارات\nوعناية بالعجلات', 'Tyres &\nWheel care'),
      icon: Icons.tire_repair,
    ),
    ServiceCategory(
      id: 'detailing',
      name: L('تلميع\nالسيارات', 'Car\nDetailing'),
      icon: Icons.local_car_wash,
    ),
    ServiceCategory(
      id: 'battery',
      name: L('بطارية\nوكهرباء', 'Battery\n& Power'),
      icon: Icons.battery_charging_full_rounded,
    ),
    ServiceCategory(
      id: 'ac',
      name: L('عناية\nبالمكيف', 'AC\nCare'),
      icon: Icons.ac_unit_rounded,
    ),
    ServiceCategory(
      id: 'diag',
      name: L('فحص\nالمحرك', 'Engine\nDiagnostics'),
      icon: Icons.monitor_heart_outlined,
    ),
    ServiceCategory(
      id: 'contracts',
      name: L('عقود\nالصيانة', 'Service\nContracts'),
      icon: Icons.assignment_turned_in_outlined,
    ),
  ];

  /// Provider id → category id → price and duration.
  ///
  /// The coverage matrix: read one governorate's providers together and every
  /// category id in [categories] appears at least once. Wording is shared per
  /// category ([_copy]) — only price and duration differ per workshop,
  /// because inventing a distinct sales pitch per workshop would be
  /// fabricating detail the real API will not return.
  static const _catalogue = <String, Map<String, _Sale>>{
    // ------------------------------------------------------------ Muscat
    'p1': {
      'major': (price: 45, minutes: 180),
      'full': (price: 30, minutes: 120),
      'express': (price: 12, minutes: 45),
      'repair': (price: null, minutes: null),
      'ac': (price: 15, minutes: 60),
      'diag': (price: 8, minutes: 30),
      'contracts': (price: 120, minutes: null),
    },
    'p2': {
      'full': (price: 32, minutes: 125),
      'express': (price: 18, minutes: 50),
      'sos': (price: 10, minutes: 30),
      'tyres': (price: 7, minutes: 30),
      'detailing': (price: 12, minutes: 90),
      'battery': (price: 5, minutes: 20),
      'ac': (price: 15, minutes: 60),
    },
    'p4': {
      'major': (price: 52, minutes: 200),
      'express': (price: 14, minutes: 30),
      'repair': (price: null, minutes: null),
      'tyres': (price: 6, minutes: 25),
      'detailing': (price: 18, minutes: 120),
      'battery': (price: 6, minutes: 25),
      'diag': (price: 10, minutes: 40),
    },
    // -------------------------------------------------- North Al Batinah
    'p3': {
      'major': (price: 38, minutes: 170),
      'full': (price: 26, minutes: 110),
      'express': (price: 10, minutes: 40),
      'repair': (price: null, minutes: null),
      'tyres': (price: 6, minutes: 30),
      'diag': (price: 8, minutes: 30),
      'contracts': (price: 95, minutes: null),
    },
    'p8': {
      'express': (price: 12, minutes: 35),
      'sos': (price: 8, minutes: 35),
      'tyres': (price: 5, minutes: 25),
      'detailing': (price: 10, minutes: 85),
      'battery': (price: 5, minutes: 20),
      'ac': (price: 13, minutes: 55),
    },
    // -------------------------------------------------- South Al Batinah
    'p7': {
      'express': (price: 11, minutes: 35),
      'sos': (price: 8, minutes: 35),
      'tyres': (price: 6, minutes: 30),
      'battery': (price: 6, minutes: 25),
      'ac': (price: 14, minutes: 60),
      'diag': (price: 9, minutes: 35),
    },
    'p9': {
      'major': (price: 42, minutes: 185),
      'full': (price: 28, minutes: 115),
      'express': (price: 13, minutes: 40),
      'repair': (price: null, minutes: null),
      'detailing': (price: 14, minutes: 100),
      'contracts': (price: 110, minutes: null),
    },
    // ----------------------------------------------------- Ad Dakhiliyah
    'p5': {
      'major': (price: 40, minutes: 175),
      'full': (price: 28, minutes: 110),
      'express': (price: 12, minutes: 40),
      'sos': (price: 12, minutes: 30),
      'ac': (price: 14, minutes: 60),
      'diag': (price: 10, minutes: 40),
      'contracts': (price: 100, minutes: null),
    },
    'p10': {
      'express': (price: 10, minutes: 35),
      'repair': (price: null, minutes: null),
      'sos': (price: 9, minutes: 35),
      'tyres': (price: 6, minutes: 30),
      'detailing': (price: 11, minutes: 90),
      'battery': (price: 5, minutes: 20),
    },
    // ------------------------------------------------------------ Dhofar
    'p6': {
      'major': (price: 48, minutes: 190),
      'full': (price: 31, minutes: 120),
      'express': (price: 15, minutes: 45),
      'repair': (price: null, minutes: null),
      'tyres': (price: 7, minutes: 25),
      'ac': (price: 18, minutes: 75),
      'contracts': (price: 140, minutes: null),
    },
    'p11': {
      'express': (price: 12, minutes: 40),
      'sos': (price: 11, minutes: 35),
      'tyres': (price: 6, minutes: 30),
      'detailing': (price: 13, minutes: 95),
      'battery': (price: 6, minutes: 25),
      'diag': (price: 9, minutes: 35),
    },
  };

  /// Category id → the name and description every offering in it carries.
  /// Every category id used in [_catalogue] must appear here.
  static const _copy = <String, _Copy>{
    'major': (
      name: L('صيانة شاملة', 'Major service'),
      description: L(
        'صيانة كاملة: زيت المحرك مجاناً، جميع الفلاتر، فحص الفرامل، '
            'السوائل، الأحزمة وفحص من 40 نقطة.',
        'Complete service: engine oil FREE, all filters, brakes check, '
            'fluids, belts and a 40-point inspection.',
      ),
    ),
    'full': (
      name: L('صيانة كاملة', 'Full service'),
      description: L(
        'زيت وفلاتر، فحص الفرامل والتعليق، اختبار أداء المكيف، '
            'وفحص من 25 نقطة.',
        'Oil & filters, brake and suspension check, AC performance test, '
            '25-point inspection.',
      ),
    ),
    'express': (
      name: L('صيانة سريعة', 'Express service'),
      description: L(
        'تغيير الزيت والفلتر مع فحص أمان من 10 نقاط — تخرج خلال ساعة.',
        'Oil + filter replacement and a 10-point safety check, in and out '
            'within the hour.',
      ),
    ),
    'repair': (
      name: L('إصلاح وفحص السيارة', 'Car repair & inspection'),
      description: L(
        'فحص كامل أولاً — عرض سعر مفصّل قبل أي عمل.',
        'Full inspection first — itemized quote before any work.',
      ),
    ),
    'sos': (
      name: L('مساعدة على الطريق', 'Roadside assistance'),
      description: L(
        'شحن البطارية، تغيير الإطار، وتنسيق السحب.',
        'Battery boost, tyre change, tow coordination.',
      ),
    ),
    'tyres': (
      name: L('تغيير وترصيص الإطارات', 'Tyre change & balancing'),
      description: L(
        'تركيب وترصيص وفحص الضغط لكل إطار.',
        'Fitting, balancing and pressure check per tyre.',
      ),
    ),
    'detailing': (
      name: L('تلميع السيارة', 'Car detailing'),
      description: L(
        'تنظيف داخلي عميق، تلميع خارجي وشمع.',
        'Interior deep clean, exterior polish and wax.',
      ),
    ),
    'battery': (
      name: L('تغيير البطارية', 'Battery replacement'),
      description: L(
        'فحص وتوريد وتركيب — ويتم تدوير البطارية القديمة.',
        'Test, supply and fit — old battery recycled.',
      ),
    ),
    'ac': (
      name: L('عناية بالمكيف', 'AC care'),
      description: L(
        'تعبئة الغاز، فحص التسريب، وفحص فلتر المقصورة.',
        'Gas recharge, leak test, cabin filter check.',
      ),
    ),
    'diag': (
      name: L('فحص المحرك', 'Engine diagnostics'),
      description: L(
        'فحص OBD كامل مع تقرير مطبوع.',
        'Full OBD scan with printed report.',
      ),
    ),
    'contracts': (
      name: L('عقد صيانة سنوي', 'Annual service contract'),
      description: L(
        'جميع الصيانات الدورية لمدة سنة — حجز بأولوية واستلام مجاني.',
        'All routine services for a year — priority booking and free '
            'pickup included.',
      ),
    ),
  };

  /// [_catalogue] × [_copy], in provider order. Ids read as
  /// `o-{provider}-{category}` so a fixture pointing at one says what it is.
  static final offerings = <ServiceOffering>[
    for (final provider in providers)
      for (final sale in (_catalogue[provider.id] ?? const {}).entries)
        ServiceOffering(
          id: 'o-${provider.id}-${sale.key}',
          categoryId: sale.key,
          name: _copy[sale.key]!.name,
          provider: provider,
          description: _copy[sale.key]!.description,
          price: sale.value.price,
          durationMin: sale.value.minutes,
        ),
  ];

  /// Sold by every workshop.
  static const _routineAddOns = <AddOn>[
    AddOn(
        id: 'a-rotation',
        name: L('تدوير الإطارات', 'Tyre rotation'),
        price: 4,
        isPart: false),
    AddOn(
        id: 'a-ac-gas',
        name: L('تعبئة غاز المكيف', 'AC gas top-up'),
        price: 8,
        isPart: false),
    AddOn(
        id: 'a-oil-filter',
        name: L('فلتر زيت أصلي', 'Genuine oil filter'),
        price: 3.5,
        isPart: true),
    AddOn(
        id: 'a-wipers',
        name: L('زوج مساحات', 'Wiper blades pair'),
        price: 5,
        isPart: true),
  ];

  /// Extras only the larger workshops carry.
  static const _detailingAddOns = <AddOn>[
    AddOn(
        id: 'a-interior',
        name: L('تنظيف داخلي', 'Interior detailing'),
        price: 12,
        isPart: false),
    AddOn(
        id: 'a-cabin-filter',
        name: L('فلتر مقصورة', 'Cabin filter'),
        price: 4,
        isPart: true),
    AddOn(
        id: 'a-engine-flush',
        name: L('غسيل المحرك', 'Engine flush'),
        price: 6,
        isPart: false),
  ];

  /// Every provider has a list — an empty extras step on the booking screen
  /// reads as a loading bug rather than as a workshop that sells no extras.
  static const addOnsByProvider = <String, List<AddOn>>{
    'p1': [..._routineAddOns, ..._detailingAddOns],
    'p2': [..._routineAddOns, ..._detailingAddOns],
    'p3': _routineAddOns,
    'p4': [..._routineAddOns, ..._detailingAddOns],
    'p5': [..._routineAddOns, ..._detailingAddOns],
    'p6': [..._routineAddOns, ..._detailingAddOns],
    'p7': _routineAddOns,
    'p8': [..._routineAddOns, ..._detailingAddOns],
    'p9': [..._routineAddOns, ..._detailingAddOns],
    'p10': _routineAddOns,
    'p11': _routineAddOns,
  };

  static const slots = ['9:00', '10:30', '13:00', '16:00'];
  static const bookedSlots = {'16:00'};
}
