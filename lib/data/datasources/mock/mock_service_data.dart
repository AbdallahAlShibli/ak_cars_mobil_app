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
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
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
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
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
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
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
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
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
      fulfillments: {Fulfillment.workshop, Fulfillment.pickup},
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
      fulfillments: {Fulfillment.workshop, Fulfillment.roadside},
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
      fulfillments: {
        Fulfillment.workshop,
        Fulfillment.pickup,
        Fulfillment.roadside,
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
}
