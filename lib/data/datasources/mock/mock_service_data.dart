import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../models/add_on.dart';
import '../../models/offer.dart';
import '../../models/powertrain.dart';
import '../../models/promotion.dart';
import '../../models/service_category.dart';
import '../../models/service_offering.dart';
import '../../models/service_provider.dart';
import '../../models/service_stats.dart';

/// What one workshop sells within one category.
///
/// A null [_Sale.price] means "quote after inspection"; a null
/// [_Sale.minutes] means the job has no fixed duration (a yearly contract, an
/// open-ended repair).
typedef _Sale = ({double? price, int? minutes});

/// Customer-facing wording for a category, shared by every workshop selling
/// it.
///
/// [includes] is the checklist the service detail page renders — what the
/// price actually covers. It belongs to the category, not the workshop: two
/// garages selling "Express service" are selling the same job, and a
/// per-workshop checklist would be inventing a difference the real API will
/// not return. [warrantyMonths] is null where a workmanship warranty makes
/// no sense (a roadside callout, a year-long contract).
typedef _Copy = ({
  L name,
  L description,
  List<L> includes,
  int? warrantyMonths,
});

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
  /// **VAT rule.** `vatNumber` carries an Oman VATIN — `OM` + 10 digits,
  /// issued by the Oman Tax Authority — and is set only on the workshops that
  /// are actually VAT-registered. Registration in Oman is turnover-based, so
  /// the smaller garages here deliberately carry `null`: the shop and product
  /// pages must be able to render a seller that cannot issue a VAT invoice,
  /// rather than assuming every seller has a number to print.
  static const providers = <ServiceProvider>[
    // ------------------------------------------------------------ Muscat
    ServiceProvider(
      id: 'p1',
      name: L('ورشة النور', 'Al Noor Workshop'),
      area: 'Al Khuwair',
      region: 'Muscat',
      distanceKm: 2.4,
      verified: true,
      isApproved: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
      capabilities: {ProviderCapability.evService},
      phone: '+96824478120',
      whatsapp: '96892140088',
      vatNumber: 'OM1100047382',
      crNumber: '1198432',
      hours: L('السبت–الخميس ٨:٠٠–٢٠:٠٠ · الجمعة مغلق',
          'Sat–Thu 8:00–20:00 · Fri closed'),
    ),
    ServiceProvider(
      id: 'p2',
      name: L('الخليج للعناية بالسيارات', 'Gulf Auto Care'),
      area: 'Seeb',
      region: 'Muscat',
      distanceKm: 6.1,
      verified: true,
      isApproved: true,
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
      capabilities: {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      phone: '+96824551907',
      whatsapp: '96895330214',
      vatNumber: 'OM1100062915',
      crNumber: '1243907',
      hours: L('السبت–الخميس ٧:٣٠–٢١:٠٠ · الجمعة ١٦:٠٠–٢١:٠٠',
          'Sat–Thu 7:30–21:00 · Fri 16:00–21:00'),
    ),
    ServiceProvider(
      id: 'p4',
      name: L('خبراء القرم للسيارات', 'Qurum Auto Experts'),
      area: 'Qurum',
      region: 'Muscat',
      distanceKm: 4.2,
      verified: true,
      isApproved: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
      pickupFee: 2,
      phone: '+96824663415',
      whatsapp: '96899210546',
      vatNumber: 'OM1100051764',
      crNumber: '1215880',
      hours: L('السبت–الخميس ٨:٠٠–١٩:٠٠ · الجمعة مغلق',
          'Sat–Thu 8:00–19:00 · Fri closed'),
    ),
    // -------------------------------------------------- North Al Batinah
    ServiceProvider(
      id: 'p3',
      name: L('كراج صحار سبيد', 'Sohar Speed Garage'),
      area: 'Sohar',
      region: 'North Al Batinah',
      distanceKm: 18.0,
      verified: false,
      isApproved: false,
      fulfillments: {Fulfillment.workshop},
      phone: '+96826841203',
      whatsapp: '96897440319',
      crNumber: '1307654',
      hours: L('السبت–الخميس ٨:٠٠–١٨:٠٠', 'Sat–Thu 8:00–18:00'),
    ),
    ServiceProvider(
      id: 'p8',
      name: L('مركز صحم للسيارات', 'Saham Auto Centre'),
      area: 'Saham',
      region: 'North Al Batinah',
      distanceKm: 26.0,
      verified: true,
      isApproved: true,
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
      capabilities: {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      phone: '+96826855740',
      whatsapp: '96893120877',
      vatNumber: 'OM1100073508',
      crNumber: '1288201',
      hours: L('السبت–الخميس ٧:٠٠–٢٠:٠٠ · الجمعة ١٦:٠٠–٢٠:٠٠',
          'Sat–Thu 7:00–20:00 · Fri 16:00–20:00'),
    ),
    // -------------------------------------------------- South Al Batinah
    ServiceProvider(
      id: 'p7',
      name: L('بركاء كويك فكس', 'Barka Quick Fix'),
      area: 'Barka',
      region: 'South Al Batinah',
      distanceKm: 22.0,
      verified: false,
      isApproved: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
      capabilities: {ProviderCapability.evService},
      phone: '+96826882456',
      whatsapp: '96896015523',
      crNumber: '1341120',
      hours: L('السبت–الخميس ٨:٠٠–٢٢:٠٠', 'Sat–Thu 8:00–22:00'),
    ),
    ServiceProvider(
      id: 'p9',
      name: L('الرستاق لميكانيكا السيارات', 'Rustaq Motor Works'),
      area: 'Rustaq',
      region: 'South Al Batinah',
      distanceKm: 38.0,
      verified: true,
      isApproved: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
      capabilities: {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      pickupFee: 4,
      phone: '+96826875031',
      whatsapp: '96894870162',
      vatNumber: 'OM1100068247',
      crNumber: '1276418',
      hours: L('السبت–الخميس ٨:٠٠–١٩:٣٠ · الجمعة مغلق',
          'Sat–Thu 8:00–19:30 · Fri closed'),
    ),
    // ----------------------------------------------------- Ad Dakhiliyah
    ServiceProvider(
      id: 'p5',
      name: L('نزوى للعناية بالسيارات', 'Nizwa Car Care'),
      area: 'Nizwa',
      region: 'Ad Dakhiliyah',
      distanceKm: 32.0,
      verified: true,
      isApproved: true,
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
      capabilities: {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      phone: '+96825412876',
      whatsapp: '96891650430',
      vatNumber: 'OM1100059183',
      crNumber: '1260973',
      hours: L('السبت–الخميس ٧:٣٠–١٩:٠٠ · الجمعة مغلق',
          'Sat–Thu 7:30–19:00 · Fri closed'),
    ),
    ServiceProvider(
      id: 'p10',
      name: L('نقطة خدمة سمائل', 'Samail Service Point'),
      area: 'Samail',
      region: 'Ad Dakhiliyah',
      distanceKm: 24.0,
      verified: false,
      isApproved: false,
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
      phone: '+96825350962',
      whatsapp: '96892770118',
      crNumber: '1352209',
      hours: L('يومياً ٦:٠٠–٢٣:٠٠', 'Daily 6:00–23:00'),
    ),
    // ------------------------------------------------------------ Dhofar
    ServiceProvider(
      id: 'p6',
      name: L('مركز صلالة للمحركات', 'Salalah Motors Hub'),
      area: 'Salalah',
      region: 'Dhofar',
      distanceKm: 45.0,
      verified: true,
      isApproved: true,
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
      },
      capabilities: {
        ProviderCapability.evService,
        ProviderCapability.evChargerInstall,
      },
      pickupFee: 4,
      phone: '+96823298450',
      whatsapp: '96899640277',
      vatNumber: 'OM1100081642',
      crNumber: '1229561',
      hours: L('السبت–الخميس ٨:٠٠–٢٠:٣٠ · الجمعة ١٦:٠٠–٢٠:٣٠',
          'Sat–Thu 8:00–20:30 · Fri 16:00–20:30'),
    ),
    ServiceProvider(
      id: 'p11',
      name: L('كراج طاقة للسيارات', 'Taqah Auto Garage'),
      area: 'Taqah',
      region: 'Dhofar',
      distanceKm: 52.0,
      verified: false,
      isApproved: false,
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
      phone: '+96823271908',
      whatsapp: '96897330654',
      crNumber: '1366742',
      hours: L('السبت–الخميس ٨:٠٠–١٨:٣٠', 'Sat–Thu 8:00–18:30'),
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
    // ------------------------------------------------- electric & plug-in
    // Restricted by [powertrains] because they are genuinely not bookable for
    // a petrol car, and by [requires] because high-voltage work needs a
    // trained workshop — see the capability sets on the providers above.
    ServiceCategory(
      id: 'ev-check',
      name: L('فحص السيارة\nالكهربائية', 'EV health\ncheck'),
      icon: Icons.electric_car_rounded,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evService,
    ),
    ServiceCategory(
      id: 'ev-battery',
      name: L('فحص بطارية\nالجهد العالي', 'HV battery\ndiagnostic'),
      icon: Icons.battery_saver_rounded,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evService,
    ),
    ServiceCategory(
      id: 'ev-charging',
      name: L('فحص كيبل\nومنفذ الشحن', 'Charging cable\n& port check'),
      icon: Icons.cable_rounded,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evService,
    ),
    ServiceCategory(
      id: 'ev-charger',
      name: L('فحص شاحن\nالمنزل', 'Home charger\ninspection'),
      icon: Icons.ev_station_outlined,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evChargerInstall,
    ),
    ServiceCategory(
      id: 'ev-sos',
      name: L('شحن أو سحب\nعلى الطريق', 'Roadside charge\n& tow'),
      icon: Icons.electrical_services_rounded,
      note: L('عند الطلب', 'on call'),
      emergency: true,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evService,
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
      'ev-check': (price: 18, minutes: 60),
      'ev-battery': (price: 32, minutes: 90),
      'ev-charging': (price: 6, minutes: 25),
    },
    'p2': {
      'full': (price: 32, minutes: 125),
      'express': (price: 18, minutes: 50),
      'sos': (price: 10, minutes: 30),
      'tyres': (price: 7, minutes: 30),
      'detailing': (price: 12, minutes: 90),
      'battery': (price: 5, minutes: 20),
      'ac': (price: 15, minutes: 60),
      'ev-check': (price: 16, minutes: 55),
      'ev-battery': (price: 30, minutes: 85),
      'ev-charging': (price: 5, minutes: 20),
      'ev-charger': (price: 15, minutes: 45),
      'ev-sos': (price: 14, minutes: 40),
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
      'ev-check': (price: 15, minutes: 55),
      'ev-battery': (price: 28, minutes: 85),
      'ev-charging': (price: 5, minutes: 20),
      'ev-charger': (price: 13, minutes: 45),
      'ev-sos': (price: 12, minutes: 45),
    },
    // -------------------------------------------------- South Al Batinah
    'p7': {
      'express': (price: 11, minutes: 35),
      'sos': (price: 8, minutes: 35),
      'tyres': (price: 6, minutes: 30),
      'battery': (price: 6, minutes: 25),
      'ac': (price: 14, minutes: 60),
      'diag': (price: 9, minutes: 35),
      'ev-check': (price: 15, minutes: 55),
      'ev-charging': (price: 5, minutes: 25),
      'ev-sos': (price: 12, minutes: 45),
    },
    'p9': {
      'major': (price: 42, minutes: 185),
      'full': (price: 28, minutes: 115),
      'express': (price: 13, minutes: 40),
      'repair': (price: null, minutes: null),
      'detailing': (price: 14, minutes: 100),
      'contracts': (price: 110, minutes: null),
      'ev-check': (price: 17, minutes: 60),
      'ev-battery': (price: 29, minutes: 90),
      'ev-charger': (price: 14, minutes: 50),
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
      'ev-check': (price: 17, minutes: 60),
      'ev-battery': (price: 30, minutes: 90),
      'ev-charging': (price: 6, minutes: 25),
      'ev-charger': (price: 14, minutes: 50),
      'ev-sos': (price: 15, minutes: 50),
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
      'ev-check': (price: 19, minutes: 60),
      'ev-battery': (price: 34, minutes: 95),
      'ev-charging': (price: 7, minutes: 25),
      'ev-charger': (price: 16, minutes: 50),
      'ev-sos': (price: 16, minutes: 55),
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
      includes: [
        L('زيت محرك كامل التخليق (مجاناً ضمن الباقة)',
            'Fully synthetic engine oil (free with this package)'),
        L('فلتر زيت وهواء ووقود وفلتر مقصورة',
            'Oil, air, fuel and cabin filters'),
        L('فحص الفرامل والتعليق وتعبئة سائل الفرامل عند الحاجة',
            'Brake and suspension check, brake fluid topped up if needed'),
        L('فحص الأحزمة والخراطيم وجميع السوائل',
            'Belts, hoses and all fluid levels checked'),
        L('تقرير فحص من ٤٠ نقطة يُسلَّم في التطبيق',
            '40-point inspection report delivered in the app'),
      ],
      warrantyMonths: 6,
    ),
    'full': (
      name: L('صيانة كاملة', 'Full service'),
      description: L(
        'زيت وفلاتر، فحص الفرامل والتعليق، اختبار أداء المكيف، '
            'وفحص من 25 نقطة.',
        'Oil & filters, brake and suspension check, AC performance test, '
            '25-point inspection.',
      ),
      includes: [
        L('تغيير زيت المحرك وفلتر الزيت', 'Engine oil and oil filter change'),
        L('فلتر هواء وفلتر مقصورة', 'Air filter and cabin filter'),
        L('فحص الفرامل والتعليق', 'Brake and suspension check'),
        L('اختبار أداء المكيف', 'AC performance test'),
        L('تقرير فحص من ٢٥ نقطة', '25-point inspection report'),
      ],
      warrantyMonths: 6,
    ),
    'express': (
      name: L('صيانة سريعة', 'Express service'),
      description: L(
        'تغيير الزيت والفلتر مع فحص أمان من 10 نقاط — تخرج خلال ساعة.',
        'Oil + filter replacement and a 10-point safety check, in and out '
            'within the hour.',
      ),
      includes: [
        L('تغيير زيت المحرك وفلتر الزيت', 'Engine oil and oil filter change'),
        L('تعبئة السوائل وضبط ضغط الإطارات',
            'Fluids topped up and tyre pressures set'),
        L('فحص أمان من ١٠ نقاط', '10-point safety check'),
        L('التخلص من الزيت المستعمل وفق الاشتراطات البيئية',
            'Used oil disposed of to environmental requirements'),
      ],
      warrantyMonths: 3,
    ),
    'repair': (
      name: L('إصلاح وفحص السيارة', 'Car repair & inspection'),
      description: L(
        'فحص كامل أولاً — عرض سعر مفصّل قبل أي عمل.',
        'Full inspection first — itemized quote before any work.',
      ),
      includes: [
        L('فحص كامل لتحديد العطل', 'Full inspection to identify the fault'),
        L('عرض سعر مفصّل بالقطع والأجرة',
            'Itemized quote covering parts and labour'),
        L('لا يبدأ أي عمل قبل موافقتك في التطبيق',
            'No work starts before you approve it in the app'),
        L('إعادة القطع المستبدلة عند طلبها',
            'Replaced parts returned on request'),
      ],
      warrantyMonths: 3,
    ),
    'sos': (
      name: L('مساعدة على الطريق', 'Roadside assistance'),
      description: L(
        'شحن البطارية، تغيير الإطار، وتنسيق السحب.',
        'Battery boost, tyre change, tow coordination.',
      ),
      includes: [
        L('وصول فني إلى موقعك', 'A technician comes to your location'),
        L('شحن البطارية أو تركيب الإطار الاحتياطي',
            'Battery boost or spare-wheel change'),
        L('تنسيق السحب إلى أقرب ورشة (رسوم السحب منفصلة)',
            'Tow coordination to the nearest workshop (towing billed '
                'separately)'),
      ],
      warrantyMonths: null,
    ),
    'tyres': (
      name: L('تغيير وترصيص الإطارات', 'Tyre change & balancing'),
      description: L(
        'تركيب وترصيص وفحص الضغط لكل إطار.',
        'Fitting, balancing and pressure check per tyre.',
      ),
      includes: [
        L('فك وتركيب الإطار', 'Tyre removal and fitting'),
        L('ترصيص بالأوزان', 'Balancing with weights'),
        L('صمام هواء جديد', 'New valve stem'),
        L('ضبط ضغط الهواء وفحص الإطار الاحتياطي',
            'Pressures set and spare wheel checked'),
      ],
      warrantyMonths: 3,
    ),
    'detailing': (
      name: L('تلميع السيارة', 'Car detailing'),
      description: L(
        'تنظيف داخلي عميق، تلميع خارجي وشمع.',
        'Interior deep clean, exterior polish and wax.',
      ),
      includes: [
        L('غسيل خارجي وتلميع وطبقة شمع',
            'Exterior wash, polish and a wax coat'),
        L('تنظيف عميق للمقاعد والسجاد', 'Deep clean of seats and carpets'),
        L('تنظيف الزجاج والجنوط من الداخل والخارج',
            'Glass and wheels cleaned inside and out'),
      ],
      warrantyMonths: null,
    ),
    'battery': (
      name: L('تغيير البطارية', 'Battery replacement'),
      description: L(
        'فحص وتوريد وتركيب — ويتم تدوير البطارية القديمة.',
        'Test, supply and fit — old battery recycled.',
      ),
      includes: [
        L('فحص البطارية والدينمو قبل الاستبدال',
            'Battery and alternator tested before replacing'),
        L('تركيب البطارية وتنظيف الأطراف',
            'Battery fitted and terminals cleaned'),
        L('تدوير البطارية القديمة', 'Old battery taken away for recycling'),
        L('سعر البطارية نفسها يُضاف حسب النوع',
            'The battery itself is charged separately by type'),
      ],
      warrantyMonths: 12,
    ),
    'ac': (
      name: L('عناية بالمكيف', 'AC care'),
      description: L(
        'تعبئة الغاز، فحص التسريب، وفحص فلتر المقصورة.',
        'Gas recharge, leak test, cabin filter check.',
      ),
      includes: [
        L('تفريغ وتعبئة غاز التبريد', 'Refrigerant evacuated and recharged'),
        L('فحص التسريب بالصبغة', 'Dye leak test'),
        L('فحص فلتر المقصورة وقياس حرارة المخرج',
            'Cabin filter checked and vent temperature measured'),
      ],
      warrantyMonths: 3,
    ),
    'diag': (
      name: L('فحص المحرك', 'Engine diagnostics'),
      description: L(
        'فحص OBD كامل مع تقرير مطبوع.',
        'Full OBD scan with printed report.',
      ),
      includes: [
        L('قراءة أكواد الأعطال من جميع الوحدات',
            'Fault codes read from every module'),
        L('اختبار قيادة قصير عند الحاجة', 'Short road test when needed'),
        L('تقرير مكتوب بالأعطال والإصلاح المقترح',
            'Written report of faults and recommended repair'),
        L('تُخصم قيمة الفحص من الإصلاح إذا تم في نفس الورشة',
            'Scan fee deducted from the repair if done at the same workshop'),
      ],
      warrantyMonths: null,
    ),
    'contracts': (
      name: L('عقد صيانة سنوي', 'Annual service contract'),
      description: L(
        'جميع الصيانات الدورية لمدة سنة — حجز بأولوية واستلام مجاني.',
        'All routine services for a year — priority booking and free '
            'pickup included.',
      ),
      includes: [
        L('جميع الصيانات الدورية لمدة سنة',
            'Every routine service for twelve months'),
        L('حجز بأولوية بدون انتظار', 'Priority booking with no queue'),
        L('استلام وإعادة السيارة مجاناً', 'Free pickup and return'),
        L('يبدأ العقد من تاريخ أول خدمة',
            'The contract runs from the first service'),
      ],
      warrantyMonths: null,
    ),
    // ------------------------------------------------- electric & plug-in
    // No claim here rests on reading the car: everything listed is something
    // a technician measures with the car in front of them.
    'ev-check': (
      name: L('فحص السيارة الكهربائية', 'EV health check'),
      description: L(
        'فحص دوري للسيارة الكهربائية: الإطارات والزوايا، بطارية ١٢ فولت، '
            'سائل الفرامل، منظومة التبريد، وفلتر المقصورة.',
        'Routine EV service: tyres and alignment, 12V battery, brake fluid, '
            'thermal system and cabin filter.',
      ),
      includes: [
        L('فحص الإطارات وضبط الزوايا وضغط الهواء',
            'Tyre inspection, alignment and pressures set'),
        L('اختبار بطارية ١٢ فولت المساعدة',
            '12V auxiliary battery load test'),
        L('فحص سائل الفرامل وسمك الفحمات',
            'Brake fluid and pad thickness checked'),
        L('فحص دائرة تبريد البطارية والعاكس',
            'Battery and inverter coolant circuit checked'),
        L('استبدال فلتر المقصورة عند الحاجة (الفلتر يُحسب منفصلاً)',
            'Cabin filter replaced if needed (filter billed separately)'),
      ],
      warrantyMonths: 6,
    ),
    'ev-battery': (
      name: L('فحص بطارية الجهد العالي', 'High-voltage battery diagnostic'),
      description: L(
        'قراءة بيانات البطارية من وحدة التحكم وتقرير مكتوب بحالتها — '
            'قياس فعلي، وليس تقديراً من التطبيق.',
        'Battery-management data read at the workshop with a written report '
            'on pack condition — a real measurement, not an app estimate.',
      ),
      includes: [
        L('قراءة بيانات وحدة إدارة البطارية وأكواد الأعطال',
            'Battery-management data and fault codes read'),
        L('قياس توازن الخلايا وحالة العزل',
            'Cell balance and insulation resistance measured'),
        L('فحص تبريد حزمة البطارية', 'Battery pack cooling checked'),
        L('تقرير مكتوب بالسعة المقاسة يُسلَّم في التطبيق',
            'Written report with the measured capacity, delivered in the app'),
      ],
      warrantyMonths: null,
    ),
    'ev-charging': (
      name: L('فحص كيبل ومنفذ الشحن', 'Charging cable & port check'),
      description: L(
        'فحص الكيبل والقابس ومنفذ الشحن — أكثر أعطال الشحن سببها الكيبل '
            'أو المنفذ، لا البطارية.',
        'Cable, plug and charge-port inspection — most charging faults are '
            'the cable or the port, not the battery.',
      ),
      includes: [
        L('فحص الكيبل والقابس بحثاً عن حرارة أو تآكل',
            'Cable and plug checked for heat damage and wear'),
        L('تنظيف منفذ الشحن وفحص أطرافه',
            'Charge port cleaned and its pins inspected'),
        L('اختبار شحن فعلي بالتيار المتردد',
            'A live AC charging test'),
        L('فحص قفل المنفذ وحساس الإغلاق',
            'Port lock and latch sensor checked'),
      ],
      warrantyMonths: 3,
    ),
    'ev-charger': (
      name: L('فحص تركيب الشاحن المنزلي', 'Home charger installation check'),
      description: L(
        'زيارة للمنزل لفحص الشاحن ولوحة الكهرباء والتأريض قبل أو بعد '
            'التركيب.',
        'A home visit to inspect the charger, the consumer unit and the '
            'earthing — before or after installation.',
      ),
      includes: [
        L('فحص القاطع والكيبل المغذي للشاحن',
            'Breaker and supply cable to the charger checked'),
        L('قياس التأريض وجهد التشغيل', 'Earthing and supply voltage measured'),
        L('اختبار الشاحن على السيارة', 'Charger tested against the car'),
        L('تقرير بالملاحظات وما يلزم تصحيحه',
            'Report of findings and anything that needs correcting'),
      ],
      warrantyMonths: 6,
    ),
    'ev-sos': (
      name: L('شحن أو سحب على الطريق', 'Roadside charge & tow'),
      description: L(
        'سيارة كهربائية متوقفة بلا شحن: شحن طارئ في الموقع أو تنسيق سحب '
            'بمنصة مناسبة.',
        'Out of charge at the roadside: an emergency top-up on site, or a '
            'tow coordinated on a flatbed.',
      ),
      includes: [
        L('وصول فني إلى موقعك', 'A technician comes to your location'),
        L('شحن طارئ يكفي للوصول إلى أقرب نقطة شحن',
            'Emergency charge to reach the nearest charging point'),
        L('سحب بمنصة مسطحة عند تعذّر الشحن (رسوم السحب منفصلة)',
            'Flatbed tow when charging is not possible (towing billed '
                'separately)'),
        L('فحص بطارية ١٢ فولت — سبب شائع لتعطّل السيارة الكهربائية',
            '12V battery checked — a common cause of an EV not waking up'),
      ],
      warrantyMonths: null,
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
          includes: _copy[sale.key]!.includes,
          warrantyMonths: _copy[sale.key]!.warrantyMonths,
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

  /// Days from now, for a campaign end date.
  static DateTime _endsIn(int days) =>
      DateTime.now().add(Duration(days: days));

  /// The home page's offers rail.
  ///
  /// Two rules this list keeps, and the real endpoint must keep too:
  ///
  /// 1. **Every card points at something in [offerings].** `offeringId`s here
  ///    are real (`o-{provider}-{category}`), so the price the card shows is the
  ///    workshop's actual price and the tap opens the actual service page. The
  ///    repository drops any card whose target it cannot resolve.
  /// 2. **No badge contradicts the price.** "زيت مجاني" is on the `major`
  ///    package because that package's own checklist includes free oil;
  ///    "استلام وإعادة" is on a workshop that really offers
  ///    [Fulfillment.pickup]. A "20% off" ribbon would need a discounted price
  ///    to exist in the catalogue, and it does not.
  ///
  /// Every governorate that has workshops has at least one workshop card, and
  /// the two nationwide platform cards mean the rail is never empty.
  static final promotions = <Promotion>[
    // ---------------------------------------------------- platform, nationwide
    Promotion(
      id: 'promo-escrow',
      title: L('مبلغك محفوظ حتى تستلم سيارتك',
          'Your money is held until you collect the car'),
      body: L(
        'ندفع للورشة بعد موافقتك على العمل — لا قبل ذلك.',
        'The workshop is paid after you approve the work, not before.',
      ),
      icon: Icons.lock_clock_outlined,
      badge: L('كيف يعمل', 'How it works'),
      query: 'صيانة',
    ),
    Promotion(
      id: 'promo-pickup-platform',
      title: L('ورش تستلم سيارتك من مكانك',
          'Workshops that collect your car'),
      body: L(
        'اختر «استلام وإعادة» عند الحجز — الرسوم تظهر قبل التأكيد.',
        'Pick "pickup & return" when you book — the fee is shown before you '
            'confirm.',
      ),
      icon: Icons.local_shipping_outlined,
      query: 'pickup',
    ),
    // ------------------------------------------------------------- Muscat
    Promotion(
      id: 'promo-p1-major',
      title: L('صيانة شاملة في ورشة النور',
          'Major service at Al Noor Workshop'),
      body: L('زيت المحرك مجاناً ضمن الباقة + فحص ٤٠ نقطة.',
          'Engine oil free with the package + a 40-point inspection.'),
      icon: Icons.settings_suggest_rounded,
      badge: L('زيت مجاني', 'FREE OIL'),
      providerId: 'p1',
      offeringId: 'o-p1-major',
      regions: {'Muscat'},
      endsAt: _endsIn(12),
    ),
    Promotion(
      id: 'promo-p2-full',
      title: L('الخليج للعناية بالسيارات — نستلم ونعيد',
          'Gulf Auto Care — we collect and return'),
      body: L('صيانة كاملة مع خيار استلام السيارة من مكانك.',
          'Full service, with the option to collect the car from you.'),
      icon: Icons.local_shipping_outlined,
      badge: L('استلام وإعادة', 'Pickup & return'),
      providerId: 'p2',
      offeringId: 'o-p2-full',
      regions: {'Muscat'},
    ),
    Promotion(
      id: 'promo-p4-tyres',
      title: L('ترصيص وتركيب إطارات في القرم',
          'Tyre fitting & balancing in Qurum'),
      body: L('تركيب وترصيص وصمام جديد لكل إطار.',
          'Fitting, balancing and a new valve stem per tyre.'),
      icon: Icons.tire_repair,
      providerId: 'p4',
      offeringId: 'o-p4-tyres',
      regions: {'Muscat'},
      endsAt: _endsIn(6),
    ),
    // -------------------------------------------------- North Al Batinah
    Promotion(
      id: 'promo-p8-ev',
      title: L('مركز صحم: فحص السيارات الكهربائية',
          'Saham Auto Centre: EV health check'),
      body: L('ورشة معتمدة للجهد العالي مع تقرير في التطبيق.',
          'High-voltage certified, with the report delivered in the app.'),
      icon: Icons.electric_car_rounded,
      badge: L('معتمدة للكهربائية', 'EV-certified'),
      providerId: 'p8',
      offeringId: 'o-p8-ev-check',
      regions: {'North Al Batinah'},
    ),
    // -------------------------------------------------- South Al Batinah
    Promotion(
      id: 'promo-p9-detailing',
      title: L('تلميع وتنظيف عميق في الرستاق',
          'Detailing & deep clean in Rustaq'),
      body: L('تنظيف داخلي عميق، تلميع خارجي وطبقة شمع.',
          'Interior deep clean, exterior polish and a wax coat.'),
      icon: Icons.local_car_wash,
      providerId: 'p9',
      offeringId: 'o-p9-detailing',
      regions: {'South Al Batinah'},
      endsAt: _endsIn(9),
    ),
    // ----------------------------------------------------- Ad Dakhiliyah
    Promotion(
      id: 'promo-p5-contracts',
      title: L('عقد صيانة سنوي في نزوى',
          'Yearly service contract in Nizwa'),
      body: L('صيانة مجدولة طوال السنة بسعر واحد معروف مقدماً.',
          'A year of scheduled servicing at one price, known up front.'),
      icon: Icons.assignment_turned_in_outlined,
      providerId: 'p5',
      offeringId: 'o-p5-contracts',
      regions: {'Ad Dakhiliyah'},
    ),
    // ------------------------------------------------------------ Dhofar
    Promotion(
      id: 'promo-p6-ac',
      title: L('جهّز مكيفك قبل الصيف — صلالة',
          'AC ready before summer — Salalah'),
      body: L('فحص تسريب، تعبئة غاز، وفلتر مقصورة.',
          'Leak test, gas recharge and a cabin filter.'),
      icon: Icons.ac_unit_rounded,
      providerId: 'p6',
      offeringId: 'o-p6-ac',
      regions: {'Dhofar'},
      endsAt: _endsIn(21),
    ),
  ];

  /// The published price of one offering, or null when it is quote-only.
  ///
  /// Every offer below reads its reference price through here rather than
  /// carrying a literal, which is the spec's rule in code form: the "was"
  /// price is the platform's published price, never a number the seller typed.
  /// The one offer that *does* carry a literal (`of-p2-full-inflated`) is the
  /// counter-example, and it is meant to be rejected.
  static double _published(String offeringId) {
    for (final offering in offerings) {
      if (offering.id == offeringId) return offering.price ?? 0;
    }
    return 0;
  }

  static DateTime _startedDaysAgo(int days) =>
      DateTime.now().subtract(Duration(days: days));

  /// Time-boxed workshop discounts (home-page spec §3).
  ///
  /// The first five are valid and are what the home page's offers rail shows.
  /// The last four are deliberately invalid, one per failure mode, because the
  /// validation is the feature: an offers rail that cannot be trusted to drop
  /// a bad row is worse than no offers rail. `offer_governance_test.dart`
  /// asserts each one is rejected and says why.
  static final offers = <Offer>[
    // ------------------------------------------------------------- valid
    Offer(
      id: 'of-p1-major',
      workshopId: 'p1',
      serviceOfferingId: 'o-p1-major',
      referencePrice: _published('o-p1-major'),
      discountedPrice: 36,
      startsAt: _startedDaysAgo(3),
      endsAt: _endsIn(12),
      activeByFounder: true,
    ),
    Offer(
      id: 'of-p4-tyres',
      workshopId: 'p4',
      serviceOfferingId: 'o-p4-tyres',
      referencePrice: _published('o-p4-tyres'),
      discountedPrice: 4.5,
      startsAt: _startedDaysAgo(1),
      endsAt: _endsIn(6),
      activeByFounder: true,
    ),
    Offer(
      id: 'of-p8-ev-check',
      workshopId: 'p8',
      serviceOfferingId: 'o-p8-ev-check',
      referencePrice: _published('o-p8-ev-check'),
      discountedPrice: 11,
      startsAt: _startedDaysAgo(5),
      endsAt: _endsIn(18),
      activeByFounder: true,
    ),
    Offer(
      id: 'of-p9-detailing',
      workshopId: 'p9',
      serviceOfferingId: 'o-p9-detailing',
      referencePrice: _published('o-p9-detailing'),
      discountedPrice: 10.5,
      startsAt: _startedDaysAgo(2),
      endsAt: _endsIn(9),
      activeByFounder: true,
    ),
    Offer(
      id: 'of-p6-ac',
      workshopId: 'p6',
      serviceOfferingId: 'o-p6-ac',
      referencePrice: _published('o-p6-ac'),
      discountedPrice: 13,
      startsAt: _startedDaysAgo(4),
      endsAt: _endsIn(21),
      activeByFounder: true,
    ),
    // ----------------------------------------------------------- invalid
    // The workshop is on the marketplace but the platform has not approved
    // it, so it may not be promoted (§3 rule 2).
    Offer(
      id: 'of-p3-express-unapproved',
      workshopId: 'p3',
      serviceOfferingId: 'o-p3-express',
      referencePrice: _published('o-p3-express'),
      discountedPrice: 7,
      startsAt: _startedDaysAgo(2),
      endsAt: _endsIn(10),
      activeByFounder: true,
    ),
    // An inflated "was" price — the workshop publishes 32, the offer claims 45
    // was struck through. Rejected on §3 rule 1.
    Offer(
      id: 'of-p2-full-inflated',
      workshopId: 'p2',
      serviceOfferingId: 'o-p2-full',
      referencePrice: 45,
      discountedPrice: 29,
      startsAt: _startedDaysAgo(2),
      endsAt: _endsIn(14),
      activeByFounder: true,
    ),
    // Ran, and finished. Rejected on §3 rule 5.
    Offer(
      id: 'of-p5-contracts-expired',
      workshopId: 'p5',
      serviceOfferingId: 'o-p5-contracts',
      referencePrice: _published('o-p5-contracts'),
      discountedPrice: 85,
      startsAt: _startedDaysAgo(40),
      endsAt: _startedDaysAgo(2),
      activeByFounder: true,
    ),
    // Submitted, not yet switched on by the founder. Rejected on §3 rule 4.
    Offer(
      id: 'of-p1-express-draft',
      workshopId: 'p1',
      serviceOfferingId: 'o-p1-express',
      referencePrice: _published('o-p1-express'),
      discountedPrice: 9,
      startsAt: _startedDaysAgo(1),
      endsAt: _endsIn(15),
    ),
  ];

  /// Completed bookings per workshop over the trailing 30 days.
  ///
  /// "Completed" is `EscrowState.releasedToWorkshop` — the customer approved
  /// the work. `p10` is here with zero, which is the honest record of a
  /// workshop that has taken no jobs yet, and `p11` is absent entirely: a
  /// marketplace always has businesses the aggregate has never seen. Neither
  /// may be ranked, and neither may be shown as a zero on a leaderboard.
  static const workshopDemand = <WorkshopDemand>[
    WorkshopDemand(providerId: 'p2', completedBookings: 84),
    WorkshopDemand(providerId: 'p1', completedBookings: 68),
    WorkshopDemand(providerId: 'p6', completedBookings: 52),
    WorkshopDemand(providerId: 'p4', completedBookings: 41),
    WorkshopDemand(providerId: 'p5', completedBookings: 37),
    WorkshopDemand(providerId: 'p8', completedBookings: 33),
    WorkshopDemand(providerId: 'p9', completedBookings: 24),
    WorkshopDemand(providerId: 'p7', completedBookings: 19),
    WorkshopDemand(providerId: 'p3', completedBookings: 6),
    WorkshopDemand(providerId: 'p10', completedBookings: 0),
  ];

  /// Marketplace-wide booking counts per category, trailing 30 days.
  ///
  /// A server-side aggregate: the phone can only see the signed-in user's own
  /// bookings, so "most booked" cannot be computed here — see [CategoryDemand].
  /// Phase 2 replaces this with the same figures from the API.
  static const categoryDemand = <CategoryDemand>[
    CategoryDemand(categoryId: 'express', bookings: 412),
    CategoryDemand(categoryId: 'major', bookings: 268),
    CategoryDemand(categoryId: 'tyres', bookings: 231),
    CategoryDemand(categoryId: 'ac', bookings: 197),
    CategoryDemand(categoryId: 'full', bookings: 156),
    CategoryDemand(categoryId: 'battery', bookings: 143),
    CategoryDemand(categoryId: 'diag', bookings: 121),
    CategoryDemand(categoryId: 'detailing', bookings: 96),
    CategoryDemand(categoryId: 'repair', bookings: 88),
    CategoryDemand(categoryId: 'sos', bookings: 74),
    CategoryDemand(categoryId: 'contracts', bookings: 31),
    CategoryDemand(categoryId: 'ev-check', bookings: 22),
    CategoryDemand(categoryId: 'ev-charging', bookings: 14),
    CategoryDemand(categoryId: 'ev-battery', bookings: 9),
    CategoryDemand(categoryId: 'ev-charger', bookings: 7),
    CategoryDemand(categoryId: 'ev-sos', bookings: 5),
  ];

  /// Customer ratings, aggregated from completed bookings.
  ///
  /// Two workshops are deliberately absent (`p10`, `p11`): a marketplace always
  /// has businesses nobody has rated yet, and every screen that shows a rating
  /// has to render that case as *no rating* rather than as a zero. `p3` is here
  /// with only four reviews, which is below the threshold
  /// `topRatedWorkshops` will rank on — a 4.9 from four people is not evidence
  /// that it is the best workshop in the country.
  static const workshopRatings = <WorkshopRating>[
    WorkshopRating(
        providerId: 'p1', rating: 4.8, reviews: 312, completedJobs: 1840),
    WorkshopRating(
        providerId: 'p2', rating: 4.6, reviews: 487, completedJobs: 2610),
    WorkshopRating(
        providerId: 'p3', rating: 4.9, reviews: 4, completedJobs: 37),
    WorkshopRating(
        providerId: 'p4', rating: 4.7, reviews: 168, completedJobs: 903),
    WorkshopRating(
        providerId: 'p5', rating: 4.8, reviews: 204, completedJobs: 1122),
    WorkshopRating(
        providerId: 'p6', rating: 4.6, reviews: 263, completedJobs: 1475),
    WorkshopRating(
        providerId: 'p7', rating: 4.3, reviews: 96, completedJobs: 512),
    WorkshopRating(
        providerId: 'p8', rating: 4.7, reviews: 143, completedJobs: 764),
    WorkshopRating(
        providerId: 'p9', rating: 4.5, reviews: 121, completedJobs: 688),
  ];
}
