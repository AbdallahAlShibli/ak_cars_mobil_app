import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/utils/guid.dart';
import '../../models/add_on.dart';
import '../../models/offer.dart';
import '../../models/powertrain.dart';
import '../../models/promotion.dart';
import '../../models/service_category.dart';
import '../../models/service_offering.dart';
import '../../models/service_provider.dart';
import '../../models/service_stats.dart';
import 'mock_seed.dart';
import 'mock_ids.dart';

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
  /// The workshop roster, owned by [MockSeed].
  ///
  /// Declared there rather than here because a workshop is not a catalogue
  /// entry: its onboarding stage, its rejection reason and the account that
  /// owns it are all facts the founder panel and the registration flow read,
  /// and none of them belong in a file about what services cost. This class
  /// keeps what it is actually about — the category copy, the price matrix
  /// built from it, the add-ons, the promotions and the offers.
  ///
  /// **VAT rule.** `vatNumber` carries an Oman VATIN — `OM` + 10 digits,
  /// issued by the Oman Tax Authority — and is set only on the workshops that
  /// are actually VAT-registered. Registration in Oman is turnover-based, so
  /// the smaller garages deliberately carry `null`: the shop and product pages
  /// must be able to render a seller that cannot issue a VAT invoice, rather
  /// than assuming every seller has a number to print.
  static List<ServiceProvider> get providers => MockSeed.providers;

  /// "Car service" packages render as big cards ([ServiceCategory.primary]);
  /// the rest are "Other services" tiles.
  static const categories = <ServiceCategory>[
    ServiceCategory(
      id: mockIdMajor,
      slug: 'major',
      name: L('صيانة\nشاملة', 'Major\nService'),
      icon: LucideIcons.settings,
      badge: L('زيت مجاني', 'FREE OIL'),
      primary: true,
    ),
    ServiceCategory(
      id: mockIdFull,
      slug: 'full',
      name: L('صيانة\nكاملة', 'Full\nService'),
      icon: LucideIcons.wrench,
      primary: true,
    ),
    ServiceCategory(
      id: mockIdExpress,
      slug: 'express',
      name: L('صيانة\nسريعة', 'Express\nService'),
      icon: LucideIcons.zap,
      primary: true,
    ),
    // ------------------------------------------- other services
    ServiceCategory(
      id: mockIdRepair,
      slug: 'repair',
      name: L('إصلاح\nالسيارات', 'Car\nRepair'),
      icon: LucideIcons.carFront,
      note: L('عرض سعر بعد الفحص', 'quote after inspection'),
    ),
    ServiceCategory(
      id: mockIdSos,
      slug: 'sos',
      name: L('مساعدة\nعلى الطريق', 'Roadside\nAssistance'),
      icon: LucideIcons.truck,
      note: L('عند الطلب · متوسط 25 دقيقة', 'on call · avg 25 min'),
      emergency: true,
    ),
    ServiceCategory(
      id: mockIdTyres,
      slug: 'tyres',
      name: L('إطارات\nوعناية بالعجلات', 'Tyres &\nWheel care'),
      icon: LucideIcons.lifeBuoy,
    ),
    ServiceCategory(
      id: mockIdDetailing,
      slug: 'detailing',
      name: L('تلميع\nالسيارات', 'Car\nDetailing'),
      icon: LucideIcons.sparkles,
    ),
    ServiceCategory(
      id: mockIdBattery,
      slug: 'battery',
      name: L('بطارية\nوكهرباء', 'Battery\n& Power'),
      icon: LucideIcons.batteryCharging,
    ),
    ServiceCategory(
      id: mockIdAc,
      slug: 'ac',
      name: L('عناية\nبالمكيف', 'AC\nCare'),
      icon: LucideIcons.snowflake,
    ),
    ServiceCategory(
      id: mockIdDiag,
      slug: 'diag',
      name: L('فحص\nالمحرك', 'Engine\nDiagnostics'),
      icon: LucideIcons.activity,
    ),
    ServiceCategory(
      id: mockIdContracts,
      slug: 'contracts',
      name: L('عقود\nالصيانة', 'Service\nContracts'),
      icon: LucideIcons.clipboardCheck,
    ),
    // ------------------------------------------------- electric & plug-in
    // Restricted by [powertrains] because they are genuinely not bookable for
    // a petrol car, and by [requires] because high-voltage work needs a
    // trained workshop — see the capability sets on the providers above.
    ServiceCategory(
      id: mockIdEvCheck,
      slug: 'ev-check',
      name: L('فحص السيارة\nالكهربائية', 'EV health\ncheck'),
      icon: LucideIcons.batteryFull,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evService,
    ),
    ServiceCategory(
      id: mockIdEvBattery,
      slug: 'ev-battery',
      name: L('فحص بطارية\nالجهد العالي', 'HV battery\ndiagnostic'),
      icon: LucideIcons.batteryWarning,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evService,
    ),
    ServiceCategory(
      id: mockIdEvCharging,
      slug: 'ev-charging',
      name: L('فحص كيبل\nومنفذ الشحن', 'Charging cable\n& port check'),
      icon: LucideIcons.cable,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evService,
    ),
    ServiceCategory(
      id: mockIdEvCharger,
      slug: 'ev-charger',
      name: L('فحص شاحن\nالمنزل', 'Home charger\ninspection'),
      icon: LucideIcons.plugZap,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evChargerInstall,
    ),
    ServiceCategory(
      id: mockIdEvSos,
      slug: 'ev-sos',
      name: L('شحن أو سحب\nعلى الطريق', 'Roadside charge\n& tow'),
      icon: LucideIcons.plug,
      note: L('عند الطلب', 'on call'),
      emergency: true,
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      requires: ProviderCapability.evService,
    ),
  ];

  /// Workshop GUID → category GUID → price and duration.
  ///
  /// The coverage matrix: read one governorate's providers together and every
  /// category id in [categories] appears at least once. Wording is shared per
  /// category ([_copy]) — only price and duration differ per workshop,
  /// because inventing a distinct sales pitch per workshop would be
  /// fabricating detail the real API will not return.
  static const _catalogue = <String, Map<String, _Sale>>{
    // ------------------------------------------------------------ Muscat
    mockIdP1: {
      mockIdMajor: (price: 45, minutes: 180),
      mockIdFull: (price: 30, minutes: 120),
      mockIdExpress: (price: 12, minutes: 45),
      mockIdRepair: (price: null, minutes: null),
      mockIdAc: (price: 15, minutes: 60),
      mockIdDiag: (price: 8, minutes: 30),
      mockIdContracts: (price: 120, minutes: null),
      mockIdEvCheck: (price: 18, minutes: 60),
      mockIdEvBattery: (price: 32, minutes: 90),
      mockIdEvCharging: (price: 6, minutes: 25),
    },
    mockIdP2: {
      mockIdFull: (price: 32, minutes: 125),
      mockIdExpress: (price: 18, minutes: 50),
      mockIdSos: (price: 10, minutes: 30),
      mockIdTyres: (price: 7, minutes: 30),
      mockIdDetailing: (price: 12, minutes: 90),
      mockIdBattery: (price: 5, minutes: 20),
      mockIdAc: (price: 15, minutes: 60),
      mockIdEvCheck: (price: 16, minutes: 55),
      mockIdEvBattery: (price: 30, minutes: 85),
      mockIdEvCharging: (price: 5, minutes: 20),
      mockIdEvCharger: (price: 15, minutes: 45),
      mockIdEvSos: (price: 14, minutes: 40),
    },
    mockIdP4: {
      mockIdMajor: (price: 52, minutes: 200),
      mockIdExpress: (price: 14, minutes: 30),
      mockIdRepair: (price: null, minutes: null),
      mockIdTyres: (price: 6, minutes: 25),
      mockIdDetailing: (price: 18, minutes: 120),
      mockIdBattery: (price: 6, minutes: 25),
      mockIdDiag: (price: 10, minutes: 40),
    },
    // -------------------------------------------------- North Al Batinah
    mockIdP3: {
      mockIdMajor: (price: 38, minutes: 170),
      mockIdFull: (price: 26, minutes: 110),
      mockIdExpress: (price: 10, minutes: 40),
      mockIdRepair: (price: null, minutes: null),
      mockIdTyres: (price: 6, minutes: 30),
      mockIdDiag: (price: 8, minutes: 30),
      mockIdContracts: (price: 95, minutes: null),
    },
    mockIdP8: {
      mockIdExpress: (price: 12, minutes: 35),
      mockIdSos: (price: 8, minutes: 35),
      mockIdTyres: (price: 5, minutes: 25),
      mockIdDetailing: (price: 10, minutes: 85),
      mockIdBattery: (price: 5, minutes: 20),
      mockIdAc: (price: 13, minutes: 55),
      mockIdEvCheck: (price: 15, minutes: 55),
      mockIdEvBattery: (price: 28, minutes: 85),
      mockIdEvCharging: (price: 5, minutes: 20),
      mockIdEvCharger: (price: 13, minutes: 45),
      mockIdEvSos: (price: 12, minutes: 45),
    },
    // Carries what `p8` does not, so North Al Batinah still covers every
    // category now that `p3` is an unapproved application and its listings are
    // hidden from customers.
    mockIdP12: {
      mockIdMajor: (price: 41, minutes: 175),
      mockIdFull: (price: 27, minutes: 115),
      mockIdRepair: (price: null, minutes: null),
      mockIdTyres: (price: 6, minutes: 30),
      mockIdDiag: (price: 9, minutes: 35),
      mockIdContracts: (price: 105, minutes: null),
    },
    // -------------------------------------------------- South Al Batinah
    mockIdP7: {
      mockIdExpress: (price: 11, minutes: 35),
      mockIdSos: (price: 8, minutes: 35),
      mockIdTyres: (price: 6, minutes: 30),
      mockIdBattery: (price: 6, minutes: 25),
      mockIdAc: (price: 14, minutes: 60),
      mockIdDiag: (price: 9, minutes: 35),
      mockIdEvCheck: (price: 15, minutes: 55),
      mockIdEvCharging: (price: 5, minutes: 25),
      mockIdEvSos: (price: 12, minutes: 45),
    },
    mockIdP9: {
      mockIdMajor: (price: 42, minutes: 185),
      mockIdFull: (price: 28, minutes: 115),
      mockIdExpress: (price: 13, minutes: 40),
      mockIdRepair: (price: null, minutes: null),
      mockIdDetailing: (price: 14, minutes: 100),
      mockIdContracts: (price: 110, minutes: null),
      mockIdEvCheck: (price: 17, minutes: 60),
      mockIdEvBattery: (price: 29, minutes: 90),
      mockIdEvCharger: (price: 14, minutes: 50),
    },
    // ----------------------------------------------------- Ad Dakhiliyah
    mockIdP5: {
      mockIdMajor: (price: 40, minutes: 175),
      mockIdFull: (price: 28, minutes: 110),
      mockIdExpress: (price: 12, minutes: 40),
      mockIdSos: (price: 12, minutes: 30),
      mockIdAc: (price: 14, minutes: 60),
      mockIdDiag: (price: 10, minutes: 40),
      mockIdContracts: (price: 100, minutes: null),
      mockIdEvCheck: (price: 17, minutes: 60),
      mockIdEvBattery: (price: 30, minutes: 90),
      mockIdEvCharging: (price: 6, minutes: 25),
      mockIdEvCharger: (price: 14, minutes: 50),
      mockIdEvSos: (price: 15, minutes: 50),
    },
    mockIdP10: {
      mockIdExpress: (price: 10, minutes: 35),
      mockIdRepair: (price: null, minutes: null),
      mockIdSos: (price: 9, minutes: 35),
      mockIdTyres: (price: 6, minutes: 30),
      mockIdDetailing: (price: 11, minutes: 90),
      mockIdBattery: (price: 5, minutes: 20),
    },
    // ------------------------------------------------------------ Dhofar
    mockIdP6: {
      mockIdMajor: (price: 48, minutes: 190),
      mockIdFull: (price: 31, minutes: 120),
      mockIdExpress: (price: 15, minutes: 45),
      mockIdRepair: (price: null, minutes: null),
      mockIdTyres: (price: 7, minutes: 25),
      mockIdAc: (price: 18, minutes: 75),
      mockIdContracts: (price: 140, minutes: null),
      mockIdEvCheck: (price: 19, minutes: 60),
      mockIdEvBattery: (price: 34, minutes: 95),
      mockIdEvCharging: (price: 7, minutes: 25),
      mockIdEvCharger: (price: 16, minutes: 50),
      mockIdEvSos: (price: 16, minutes: 55),
    },
    mockIdP11: {
      mockIdExpress: (price: 12, minutes: 40),
      mockIdSos: (price: 11, minutes: 35),
      mockIdTyres: (price: 6, minutes: 30),
      mockIdDetailing: (price: 13, minutes: 95),
      mockIdBattery: (price: 6, minutes: 25),
      mockIdDiag: (price: 9, minutes: 35),
    },
  };

  /// Category id → the name and description every offering in it carries.
  /// Every category id used in [_catalogue] must appear here.
  static const _copy = <String, _Copy>{
    mockIdMajor: (
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
    mockIdFull: (
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
    mockIdExpress: (
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
    mockIdRepair: (
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
    mockIdSos: (
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
    mockIdTyres: (
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
    mockIdDetailing: (
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
    mockIdBattery: (
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
    mockIdAc: (
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
    mockIdDiag: (
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
    mockIdContracts: (
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
    mockIdEvCheck: (
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
    mockIdEvBattery: (
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
    mockIdEvCharging: (
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
    mockIdEvCharger: (
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
    mockIdEvSos: (
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

  /// [_catalogue] × [_copy], in provider order.
  ///
  /// Offering ids are *derived* from the workshop and the category rather
  /// than listed in [mockIds]: there is one per cell of the matrix, the matrix
  /// is edited regularly, and hand-maintaining ~90 constants that nothing
  /// refers to by name would be upkeep for no reader. [derivedGuid] keeps them
  /// stable across runs, which is the only property tests need.
  static final offerings = <ServiceOffering>[
    for (final provider in providers)
      for (final sale in (_catalogue[provider.id] ?? const {}).entries)
        ServiceOffering(
          id: mockOfferingId(provider.id, sale.key),
          categoryId: sale.key,
          categorySlug: mockCategorySlug(sale.key),
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
        id: mockIdARotation,
        name: L('تدوير الإطارات', 'Tyre rotation'),
        price: 4,
        isPart: false),
    AddOn(
        id: mockIdAAcGas,
        name: L('تعبئة غاز المكيف', 'AC gas top-up'),
        price: 8,
        isPart: false),
    AddOn(
        id: mockIdAOilFilter,
        name: L('فلتر زيت أصلي', 'Genuine oil filter'),
        price: 3.5,
        isPart: true),
    AddOn(
        id: mockIdAWipers,
        name: L('زوج مساحات', 'Wiper blades pair'),
        price: 5,
        isPart: true),
  ];

  /// Extras only the larger workshops carry.
  static const _detailingAddOns = <AddOn>[
    AddOn(
        id: mockIdAInterior,
        name: L('تنظيف داخلي', 'Interior detailing'),
        price: 12,
        isPart: false),
    AddOn(
        id: mockIdACabinFilter,
        name: L('فلتر مقصورة', 'Cabin filter'),
        price: 4,
        isPart: true),
    AddOn(
        id: mockIdAEngineFlush,
        name: L('غسيل المحرك', 'Engine flush'),
        price: 6,
        isPart: false),
  ];

  /// Every provider has a list — an empty extras step on the booking screen
  /// reads as a loading bug rather than as a workshop that sells no extras.
  static const addOnsByProvider = <String, List<AddOn>>{
    mockIdP1: [..._routineAddOns, ..._detailingAddOns],
    mockIdP2: [..._routineAddOns, ..._detailingAddOns],
    mockIdP3: _routineAddOns,
    mockIdP4: [..._routineAddOns, ..._detailingAddOns],
    mockIdP5: [..._routineAddOns, ..._detailingAddOns],
    mockIdP6: [..._routineAddOns, ..._detailingAddOns],
    mockIdP7: _routineAddOns,
    mockIdP8: [..._routineAddOns, ..._detailingAddOns],
    mockIdP9: [..._routineAddOns, ..._detailingAddOns],
    mockIdP10: _routineAddOns,
    mockIdP11: _routineAddOns,
    mockIdP12: [..._routineAddOns, ..._detailingAddOns],
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
      id: mockIdPromoEscrow,
      title: L('مبلغك محفوظ حتى تستلم سيارتك',
          'Your money is held until you collect the car'),
      body: L(
        'ندفع للورشة بعد موافقتك على العمل — لا قبل ذلك.',
        'The workshop is paid after you approve the work, not before.',
      ),
      icon: LucideIcons.shieldCheck,
      badge: L('كيف يعمل', 'How it works'),
      query: 'صيانة',
    ),
    Promotion(
      id: mockIdPromoPickupPlatform,
      title: L('ورش تستلم سيارتك من مكانك',
          'Workshops that collect your car'),
      body: L(
        'اختر «استلام وإعادة» عند الحجز — الرسوم تظهر قبل التأكيد.',
        'Pick "pickup & return" when you book — the fee is shown before you '
            'confirm.',
      ),
      icon: LucideIcons.truck,
      query: 'pickup',
    ),
    // ------------------------------------------------------------- Muscat
    Promotion(
      id: mockIdPromoP1Major,
      title: L('صيانة شاملة في ورشة النور',
          'Major service at Al Noor Workshop'),
      body: L('زيت المحرك مجاناً ضمن الباقة + فحص ٤٠ نقطة.',
          'Engine oil free with the package + a 40-point inspection.'),
      icon: LucideIcons.settings,
      badge: L('زيت مجاني', 'FREE OIL'),
      providerId: mockIdP1,
      offeringId: mockOfferingId(mockIdP1, mockIdMajor),
      regions: {'Muscat'},
      endsAt: _endsIn(12),
    ),
    Promotion(
      id: mockIdPromoP2Full,
      title: L('الخليج للعناية بالسيارات — نستلم ونعيد',
          'Gulf Auto Care — we collect and return'),
      body: L('صيانة كاملة مع خيار استلام السيارة من مكانك.',
          'Full service, with the option to collect the car from you.'),
      icon: LucideIcons.truck,
      badge: L('استلام وإعادة', 'Pickup & return'),
      providerId: mockIdP2,
      offeringId: mockOfferingId(mockIdP2, mockIdFull),
      regions: {'Muscat'},
    ),
    Promotion(
      id: mockIdPromoP4Tyres,
      title: L('ترصيص وتركيب إطارات في القرم',
          'Tyre fitting & balancing in Qurum'),
      body: L('تركيب وترصيص وصمام جديد لكل إطار.',
          'Fitting, balancing and a new valve stem per tyre.'),
      icon: LucideIcons.lifeBuoy,
      providerId: mockIdP4,
      offeringId: mockOfferingId(mockIdP4, mockIdTyres),
      regions: {'Muscat'},
      endsAt: _endsIn(6),
    ),
    // -------------------------------------------------- North Al Batinah
    Promotion(
      id: mockIdPromoP8Ev,
      title: L('مركز صحم: فحص السيارات الكهربائية',
          'Saham Auto Centre: EV health check'),
      body: L('ورشة معتمدة للجهد العالي مع تقرير في التطبيق.',
          'High-voltage certified, with the report delivered in the app.'),
      icon: LucideIcons.batteryFull,
      badge: L('معتمدة للكهربائية', 'EV-certified'),
      providerId: mockIdP8,
      offeringId: mockOfferingId(mockIdP8, mockIdEvCheck),
      regions: {'North Al Batinah'},
    ),
    // -------------------------------------------------- South Al Batinah
    Promotion(
      id: mockIdPromoP9Detailing,
      title: L('تلميع وتنظيف عميق في الرستاق',
          'Detailing & deep clean in Rustaq'),
      body: L('تنظيف داخلي عميق، تلميع خارجي وطبقة شمع.',
          'Interior deep clean, exterior polish and a wax coat.'),
      icon: LucideIcons.sparkles,
      providerId: mockIdP9,
      offeringId: mockOfferingId(mockIdP9, mockIdDetailing),
      regions: {'South Al Batinah'},
      endsAt: _endsIn(9),
    ),
    // ----------------------------------------------------- Ad Dakhiliyah
    Promotion(
      id: mockIdPromoP5Contracts,
      title: L('عقد صيانة سنوي في نزوى',
          'Yearly service contract in Nizwa'),
      body: L('صيانة مجدولة طوال السنة بسعر واحد معروف مقدماً.',
          'A year of scheduled servicing at one price, known up front.'),
      icon: LucideIcons.clipboardCheck,
      providerId: mockIdP5,
      offeringId: mockOfferingId(mockIdP5, mockIdContracts),
      regions: {'Ad Dakhiliyah'},
    ),
    // ------------------------------------------------------------ Dhofar
    Promotion(
      id: mockIdPromoP6Ac,
      title: L('جهّز مكيفك قبل الصيف — صلالة',
          'AC ready before summer — Salalah'),
      body: L('فحص تسريب، تعبئة غاز، وفلتر مقصورة.',
          'Leak test, gas recharge and a cabin filter.'),
      icon: LucideIcons.snowflake,
      providerId: mockIdP6,
      offeringId: mockOfferingId(mockIdP6, mockIdAc),
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
      id: mockIdOfP1Major,
      workshopId: mockIdP1,
      serviceOfferingId: mockOfferingId(mockIdP1, mockIdMajor),
      referencePrice: _published(mockOfferingId(mockIdP1, mockIdMajor)),
      discountedPrice: 36,
      startsAt: _startedDaysAgo(3),
      endsAt: _endsIn(12),
      activeByFounder: true,
    ),
    Offer(
      id: mockIdOfP4Tyres,
      workshopId: mockIdP4,
      serviceOfferingId: mockOfferingId(mockIdP4, mockIdTyres),
      referencePrice: _published(mockOfferingId(mockIdP4, mockIdTyres)),
      discountedPrice: 4.5,
      startsAt: _startedDaysAgo(1),
      endsAt: _endsIn(6),
      activeByFounder: true,
    ),
    Offer(
      id: mockIdOfP8EvCheck,
      workshopId: mockIdP8,
      serviceOfferingId: mockOfferingId(mockIdP8, mockIdEvCheck),
      referencePrice: _published(mockOfferingId(mockIdP8, mockIdEvCheck)),
      discountedPrice: 11,
      startsAt: _startedDaysAgo(5),
      endsAt: _endsIn(18),
      activeByFounder: true,
    ),
    Offer(
      id: mockIdOfP9Detailing,
      workshopId: mockIdP9,
      serviceOfferingId: mockOfferingId(mockIdP9, mockIdDetailing),
      referencePrice: _published(mockOfferingId(mockIdP9, mockIdDetailing)),
      discountedPrice: 10.5,
      startsAt: _startedDaysAgo(2),
      endsAt: _endsIn(9),
      activeByFounder: true,
    ),
    Offer(
      id: mockIdOfP6Ac,
      workshopId: mockIdP6,
      serviceOfferingId: mockOfferingId(mockIdP6, mockIdAc),
      referencePrice: _published(mockOfferingId(mockIdP6, mockIdAc)),
      discountedPrice: 13,
      startsAt: _startedDaysAgo(4),
      endsAt: _endsIn(21),
      activeByFounder: true,
    ),
    // ----------------------------------------------------------- invalid
    // The workshop is on the marketplace but the platform has not approved
    // it, so it may not be promoted (§3 rule 2).
    Offer(
      id: mockIdOfP3ExpressUnapproved,
      workshopId: mockIdP3,
      serviceOfferingId: mockOfferingId(mockIdP3, mockIdExpress),
      referencePrice: _published(mockOfferingId(mockIdP3, mockIdExpress)),
      discountedPrice: 7,
      startsAt: _startedDaysAgo(2),
      endsAt: _endsIn(10),
      activeByFounder: true,
    ),
    // An inflated "was" price — the workshop publishes 32, the offer claims 45
    // was struck through. Rejected on §3 rule 1.
    Offer(
      id: mockIdOfP2FullInflated,
      workshopId: mockIdP2,
      serviceOfferingId: mockOfferingId(mockIdP2, mockIdFull),
      referencePrice: 45,
      discountedPrice: 29,
      startsAt: _startedDaysAgo(2),
      endsAt: _endsIn(14),
      activeByFounder: true,
    ),
    // Ran, and finished. Rejected on §3 rule 5.
    Offer(
      id: mockIdOfP5ContractsExpired,
      workshopId: mockIdP5,
      serviceOfferingId: mockOfferingId(mockIdP5, mockIdContracts),
      referencePrice: _published(mockOfferingId(mockIdP5, mockIdContracts)),
      discountedPrice: 85,
      startsAt: _startedDaysAgo(40),
      endsAt: _startedDaysAgo(2),
      activeByFounder: true,
    ),
    // Submitted, not yet switched on by the founder. Rejected on §3 rule 4.
    Offer(
      id: mockIdOfP1ExpressDraft,
      workshopId: mockIdP1,
      serviceOfferingId: mockOfferingId(mockIdP1, mockIdExpress),
      referencePrice: _published(mockOfferingId(mockIdP1, mockIdExpress)),
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
    WorkshopDemand(providerId: mockIdP2, completedBookings: 84),
    WorkshopDemand(providerId: mockIdP1, completedBookings: 68),
    WorkshopDemand(providerId: mockIdP6, completedBookings: 52),
    WorkshopDemand(providerId: mockIdP4, completedBookings: 41),
    WorkshopDemand(providerId: mockIdP5, completedBookings: 37),
    WorkshopDemand(providerId: mockIdP8, completedBookings: 33),
    WorkshopDemand(providerId: mockIdP9, completedBookings: 24),
    WorkshopDemand(providerId: mockIdP7, completedBookings: 19),
    WorkshopDemand(providerId: mockIdP12, completedBookings: 11),
    WorkshopDemand(providerId: mockIdP3, completedBookings: 6),
    WorkshopDemand(providerId: mockIdP10, completedBookings: 0),
  ];

  /// Marketplace-wide booking counts per category, trailing 30 days.
  ///
  /// A server-side aggregate: the phone can only see the signed-in user's own
  /// bookings, so "most booked" cannot be computed here — see [CategoryDemand].
  /// Phase 2 replaces this with the same figures from the API.
  static const categoryDemand = <CategoryDemand>[
    CategoryDemand(categoryId: mockIdExpress, bookings: 412),
    CategoryDemand(categoryId: mockIdMajor, bookings: 268),
    CategoryDemand(categoryId: mockIdTyres, bookings: 231),
    CategoryDemand(categoryId: mockIdAc, bookings: 197),
    CategoryDemand(categoryId: mockIdFull, bookings: 156),
    CategoryDemand(categoryId: mockIdBattery, bookings: 143),
    CategoryDemand(categoryId: mockIdDiag, bookings: 121),
    CategoryDemand(categoryId: mockIdDetailing, bookings: 96),
    CategoryDemand(categoryId: mockIdRepair, bookings: 88),
    CategoryDemand(categoryId: mockIdSos, bookings: 74),
    CategoryDemand(categoryId: mockIdContracts, bookings: 31),
    CategoryDemand(categoryId: mockIdEvCheck, bookings: 22),
    CategoryDemand(categoryId: mockIdEvCharging, bookings: 14),
    CategoryDemand(categoryId: mockIdEvBattery, bookings: 9),
    CategoryDemand(categoryId: mockIdEvCharger, bookings: 7),
    CategoryDemand(categoryId: mockIdEvSos, bookings: 5),
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
        providerId: mockIdP1, rating: 4.8, reviews: 312, completedJobs: 1840),
    WorkshopRating(
        providerId: mockIdP2, rating: 4.6, reviews: 487, completedJobs: 2610),
    WorkshopRating(
        providerId: mockIdP3, rating: 4.9, reviews: 4, completedJobs: 37),
    WorkshopRating(
        providerId: mockIdP4, rating: 4.7, reviews: 168, completedJobs: 903),
    WorkshopRating(
        providerId: mockIdP5, rating: 4.8, reviews: 204, completedJobs: 1122),
    WorkshopRating(
        providerId: mockIdP6, rating: 4.6, reviews: 263, completedJobs: 1475),
    WorkshopRating(
        providerId: mockIdP7, rating: 4.3, reviews: 96, completedJobs: 512),
    WorkshopRating(
        providerId: mockIdP8, rating: 4.7, reviews: 143, completedJobs: 764),
    WorkshopRating(
        providerId: mockIdP9, rating: 4.5, reviews: 121, completedJobs: 688),
    // Newly onboarded — one review, which is below the ranking threshold for
    // the same reason `p3`'s four are.
    WorkshopRating(
        providerId: mockIdP12, rating: 5.0, reviews: 1, completedJobs: 11),
  ];
}
