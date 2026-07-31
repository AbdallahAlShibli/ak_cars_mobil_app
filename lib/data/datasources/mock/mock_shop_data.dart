import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../models/powertrain.dart';
import '../../models/product.dart';

/// Demo catalogue for the parts shop. Read only by `MockShopService`.
///
/// Every product carries the fields the product page needs to sell a part
/// without guessing: brand, manufacturer part number, genuine/aftermarket,
/// warranty, stock on hand, delivery days, and a spec sheet. A part listed
/// with no part number and no specs is exactly the listing an Omani buyer
/// walks away from, so the demo data models the complete case.
abstract final class MockShopData {
  static const partCategories = <String, L>{
    'filters': L('فلاتر', 'Filters'),
    'batteries': L('بطاريات', 'Batteries'),
    'brakes': L('فرامل', 'Brakes'),
    'tyres': L('إطارات', 'Tyres'),
    'lights': L('إضاءة', 'Lights'),
    // Charging hardware is its own category rather than a tag on
    // "batteries": an EV owner shopping for a cable is not shopping for a
    // battery, and the two have nothing in common on the shelf.
    'charging': L('الشحن والكيبلات', 'Charging & cables'),
  };

  static const products = <Product>[
    Product(
      id: 'pr1',
      name: L('فلتر زيت أصلي', 'Genuine oil filter'),
      price: 3.5,
      categoryId: 'filters',
      providerId: 'p1',
      region: 'Muscat',
      icon: LucideIcons.funnel,
      fits: {'Toyota Camry'},
      rating: 4.8,
      brand: L('دينسو', 'Denso'),
      partNumber: '90915-YZZE1',
      genuine: true,
      warrantyMonths: 6,
      stock: 24,
      deliveryDays: 1,
      fittingAvailable: true,
      description: L(
        'فلتر زيت أصلي من دينسو لمحركات كامري ٢.٥ لتر. يحافظ على ضغط الزيت '
            'ويمنع وصول الشوائب إلى المحرك، ويُنصح بتغييره كل ١٠٬٠٠٠ كم أو مع '
            'كل تغيير زيت.',
        'Genuine Denso oil filter for the 2.5L Camry engine. Holds oil '
            'pressure and keeps contaminants out of the engine — replace every '
            '10,000 km or with every oil change.',
      ),
      specs: [
        ProductSpec(L('رقم القطعة', 'Part number'), L('90915-YZZE1', '90915-YZZE1')),
        ProductSpec(L('نوع القطعة', 'Part type'), L('أصلية (OEM)', 'Genuine (OEM)')),
        ProductSpec(L('سعة المحرك', 'Engine'), L('٢.٥ لتر بنزين', '2.5L petrol')),
        ProductSpec(L('قياس السن', 'Thread'), L('M20 × 1.5', 'M20 × 1.5')),
        ProductSpec(L('فترة الاستبدال', 'Change interval'), L('١٠٬٠٠٠ كم', '10,000 km')),
      ],
    ),
    Product(
      id: 'pr2',
      name: L('بطارية 70 أمبير AGM', 'Battery 70Ah AGM'),
      price: 28,
      categoryId: 'batteries',
      providerId: 'p2',
      region: 'Muscat',
      icon: LucideIcons.batteryMedium,
      fits: {'any'},
      rating: 4.6,
      oldPrice: 32,
      brand: L('فارتا', 'Varta'),
      partNumber: 'E39-570901',
      genuine: false,
      warrantyMonths: 24,
      stock: 6,
      deliveryDays: 2,
      fittingAvailable: true,
      description: L(
        'بطارية AGM مغلقة تتحمل حرارة الصيف العماني وتشغيل المكيف لفترات '
            'طويلة. مناسبة للسيارات المزوّدة بخاصية التشغيل/الإيقاف. تُسلَّم '
            'مشحونة وجاهزة للتركيب، ويشمل السعر تركيبها في الورشة.',
        'Sealed AGM battery built for Omani summer heat and long AC idling. '
            'Suits start/stop vehicles. Delivered charged and ready to fit — '
            'fitting at the workshop is included in the price.',
      ),
      specs: [
        ProductSpec(L('السعة', 'Capacity'), L('٧٠ أمبير/ساعة', '70 Ah')),
        ProductSpec(L('تيار التشغيل البارد', 'Cold cranking'), L('٧٦٠ أمبير', '760 A')),
        ProductSpec(L('الجهد', 'Voltage'), L('١٢ فولت', '12 V')),
        ProductSpec(L('التقنية', 'Technology'), L('AGM مغلقة', 'Sealed AGM')),
        ProductSpec(L('الأبعاد', 'Dimensions'), L('٢٧٨ × ١٧٥ × ١٩٠ مم', '278 × 175 × 190 mm')),
        ProductSpec(L('اتجاه الأقطاب', 'Terminal layout'), L('موجب يمين', 'Positive right')),
      ],
    ),
    Product(
      id: 'pr3',
      name: L('فحمات فرامل — أمامية', 'Brake pads — front'),
      price: 18,
      categoryId: 'brakes',
      providerId: 'p1',
      region: 'Muscat',
      icon: LucideIcons.disc,
      fits: {'Toyota Camry', 'Nissan Patrol'},
      rating: 4.7,
      brand: L('أكيبونو', 'Akebono'),
      partNumber: 'ACT1211',
      genuine: false,
      warrantyMonths: 12,
      stock: 11,
      deliveryDays: 1,
      fittingAvailable: true,
      description: L(
        'طقم فحمات سيراميك للمحور الأمامي — أقل غباراً وأهدأ من الفحمات '
            'شبه المعدنية، وأداء ثابت عند الكبح المتكرر في زحام مسقط. الطقم '
            'يشمل أربع فحمات ومشحّم تركيب.',
        'Ceramic front-axle pad set — lower dust and quieter than semi-'
            'metallic pads, with stable performance under the repeated braking '
            'of Muscat traffic. Set of four pads plus fitting grease.',
      ),
      specs: [
        ProductSpec(L('المحور', 'Axle'), L('أمامي', 'Front')),
        ProductSpec(L('الخامة', 'Material'), L('سيراميك', 'Ceramic')),
        ProductSpec(L('محتويات الطقم', 'Set contents'), L('٤ فحمات', '4 pads')),
        ProductSpec(L('السماكة', 'Thickness'), L('١٧.٥ مم', '17.5 mm')),
        ProductSpec(L('حساس التآكل', 'Wear sensor'), L('غير مضمّن', 'Not included')),
      ],
    ),
    Product(
      id: 'pr4',
      name: L('طقم إضاءة LED أمامية', 'LED headlight kit'),
      price: 9.5,
      categoryId: 'lights',
      providerId: 'p2',
      region: 'Muscat',
      icon: LucideIcons.lightbulb,
      fits: {'any'},
      rating: 4.3,
      oldPrice: 12,
      brand: L('فيليبس', 'Philips'),
      partNumber: 'H4-LED-6000K',
      genuine: false,
      warrantyMonths: 12,
      stock: 3,
      deliveryDays: 2,
      description: L(
        'طقم لمبتين LED بقاعدة H4 بإضاءة بيضاء ٦٠٠٠ كلفن ومروحة تبريد '
            'مدمجة. التركيب مباشر بدون تعديل الأسلاك في أغلب الموديلات.',
        'Pair of H4 LED bulbs at 6000K with an integrated cooling fan. '
            'Direct fit with no wiring changes on most models.',
      ),
      specs: [
        ProductSpec(L('القاعدة', 'Bulb base'), L('H4', 'H4')),
        ProductSpec(L('درجة اللون', 'Colour temperature'), L('٦٠٠٠ كلفن', '6000 K')),
        ProductSpec(L('شدة الإضاءة', 'Output'), L('٤٠٠٠ لومن للّمبة', '4000 lm per bulb')),
        ProductSpec(L('الاستهلاك', 'Power draw'), L('٢٤ واط', '24 W')),
        ProductSpec(L('محتويات الطقم', 'Set contents'), L('لمبتان', '2 bulbs')),
      ],
    ),
    Product(
      id: 'pr5',
      name: L('إطار جميع التضاريس 265/60R18', 'All-terrain tyre 265/60R18'),
      price: 38,
      categoryId: 'tyres',
      providerId: 'p3',
      region: 'North Al Batinah',
      icon: LucideIcons.circleDot,
      fits: {'Nissan Patrol'},
      rating: 4.5,
      brand: L('يوكوهاما', 'Yokohama'),
      partNumber: 'G015-2656018',
      genuine: false,
      warrantyMonths: 12,
      stock: 8,
      deliveryDays: 3,
      fittingAvailable: true,
      description: L(
        'إطار جميع التضاريس للطرق المعبّدة والوعرة، بجدار جانبي مقوّى '
            'يناسب الرمل والحصى. السعر لإطار واحد، والتركيب والترصيص متاح في '
            'الكراج.',
        'All-terrain tyre for tarmac and off-road use, with a reinforced '
            'sidewall for sand and gravel. Price is per tyre; fitting and '
            'balancing available at the garage.',
      ),
      specs: [
        ProductSpec(L('المقاس', 'Size'), L('265/60R18', '265/60R18')),
        ProductSpec(L('مؤشر الحمل', 'Load index'), L('١١٠ (١٠٦٠ كجم)', '110 (1060 kg)')),
        ProductSpec(L('مؤشر السرعة', 'Speed rating'), L('H (٢١٠ كم/س)', 'H (210 km/h)')),
        ProductSpec(L('النمط', 'Pattern'), L('جميع التضاريس', 'All-terrain')),
        ProductSpec(L('الكمية', 'Quantity'), L('إطار واحد', 'Single tyre')),
      ],
    ),
    Product(
      id: 'pr6',
      name: L('فلتر هواء المقصورة', 'Cabin air filter'),
      price: 4,
      categoryId: 'filters',
      providerId: 'p2',
      region: 'Muscat',
      icon: LucideIcons.wind,
      fits: {'any'},
      rating: 4.2,
      oldPrice: 5,
      brand: L('مان فلتر', 'Mann-Filter'),
      partNumber: 'CUK-2545',
      genuine: false,
      warrantyMonths: 6,
      stock: 40,
      deliveryDays: 1,
      description: L(
        'فلتر مقصورة بطبقة كربون نشط يحجز الغبار وحبوب اللقاح والروائح — '
            'فرق ملحوظ بعد موسم الغبار. يُستبدل كل ١٥٬٠٠٠ كم.',
        'Activated-carbon cabin filter that traps dust, pollen and odours — '
            'a noticeable difference after dust season. Replace every '
            '15,000 km.',
      ),
      specs: [
        ProductSpec(L('النوع', 'Type'), L('كربون نشط', 'Activated carbon')),
        ProductSpec(L('الأبعاد', 'Dimensions'), L('٢١٦ × ٢٠٠ × ٣٠ مم', '216 × 200 × 30 mm')),
        ProductSpec(L('فترة الاستبدال', 'Change interval'), L('١٥٬٠٠٠ كم', '15,000 km')),
        ProductSpec(L('التركيب', 'Fitting'), L('بدون أدوات', 'No tools needed')),
      ],
    ),
    // ---------------------------------------------- electric & plug-in cars
    // Charging hardware carries the specs a buyer is actually deciding on —
    // connector type, current, phases, cable length and the plug it needs at
    // the wall. A cable listed without them is the listing an EV owner in Oman
    // walks away from, because the wrong one either will not fit the car or
    // will trip the socket.
    Product(
      id: 'pr7',
      name: L('كيبل شحن Type 2 — ٧.٤ كيلوواط', 'Type 2 charging cable — 7.4 kW'),
      price: 34,
      categoryId: 'charging',
      providerId: 'p2',
      region: 'Muscat',
      icon: LucideIcons.cable,
      fits: {'any'},
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      rating: 4.7,
      brand: L('دوستارك', 'Duosida'),
      partNumber: 'T2-32A-5M',
      genuine: false,
      warrantyMonths: 24,
      stock: 9,
      deliveryDays: 2,
      description: L(
        'كيبل شحن Type 2 بطرفين لشواحن المجمعات التجارية والشواحن المنزلية '
            'من نوع Type 2. تيار ٣٢ أمبير على مرحلة واحدة (٧.٤ كيلوواط)، '
            'وطوله ٥ أمتار يكفي مواقف المنازل. تأكد أن منفذ سيارتك Type 2 '
            'قبل الشراء.',
        'Type 2 to Type 2 charging cable for mall chargers and home wallboxes '
            'with a Type 2 socket. 32 A single phase (7.4 kW), 5 m — enough '
            'for a home car park. Check your car has a Type 2 port before '
            'buying.',
      ),
      specs: [
        ProductSpec(L('نوع القابس', 'Connector'), L('Type 2 إلى Type 2', 'Type 2 to Type 2')),
        ProductSpec(L('التيار', 'Current'), L('٣٢ أمبير', '32 A')),
        ProductSpec(L('القدرة', 'Power'), L('٧.٤ كيلوواط، مرحلة واحدة', '7.4 kW, single phase')),
        ProductSpec(L('الطول', 'Length'), L('٥ أمتار', '5 m')),
        ProductSpec(L('درجة الحماية', 'Protection rating'), L('IP55', 'IP55')),
        ProductSpec(L('لا يصلح لشواحن', 'Not for'), L('الشحن السريع DC', 'DC fast charging')),
      ],
    ),
    Product(
      id: 'pr8',
      name: L('شاحن محمول ٢.٣ كيلوواط', 'Portable charger 2.3 kW'),
      price: 46,
      categoryId: 'charging',
      providerId: 'p8',
      region: 'North Al Batinah',
      icon: LucideIcons.power,
      fits: {'any'},
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      rating: 4.4,
      oldPrice: 52,
      brand: L('خضراء الخليج', 'Gulf Volt'),
      partNumber: 'PC-10A-T2',
      genuine: false,
      warrantyMonths: 12,
      stock: 5,
      deliveryDays: 3,
      description: L(
        'شاحن محمول (طوارئ) يعمل من مقبس منزلي عادي ١٠ أمبير — يضيف نحو '
            '١٠ كم لكل ساعة، فهو للحالات الاحتياطية وليس بديلاً عن شاحن '
            'منزلي مثبت. لا يُستخدم مع وصلة مشتركة، ويُفضّل فحص المقبس '
            'والتأريض قبل الاستخدام المتكرر.',
        'Portable (emergency) charger that runs from an ordinary 10 A '
            'household socket — roughly 10 km of range per hour, so it is a '
            'backup, not a substitute for an installed home charger. Never use '
            'it on an extension lead, and have the socket and earthing checked '
            'before relying on it regularly.',
      ),
      specs: [
        ProductSpec(L('نوع القابس', 'Connector'), L('Type 2 إلى مقبس منزلي', 'Type 2 to household plug')),
        ProductSpec(L('التيار', 'Current'), L('١٠ أمبير (قابل للتقليل إلى ٨)', '10 A (switchable to 8 A)')),
        ProductSpec(L('القدرة', 'Power'), L('٢.٣ كيلوواط', '2.3 kW')),
        ProductSpec(L('الطول', 'Length'), L('٥ أمتار', '5 m')),
        ProductSpec(L('الحماية', 'Safety'), L('حماية حرارية وتسرب أرضي مدمجة', 'Built-in thermal and earth-leakage protection')),
        ProductSpec(L('تحذير', 'Warning'), L('لا يُستخدم مع وصلة مشتركة', 'Do not use with an extension lead')),
      ],
    ),
    Product(
      id: 'pr9',
      name: L('محول شحن Type 1 إلى Type 2', 'Charging adapter Type 1 to Type 2'),
      price: 18,
      categoryId: 'charging',
      providerId: 'p5',
      region: 'Ad Dakhiliyah',
      icon: LucideIcons.plug,
      fits: {'any'},
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      rating: 4.1,
      brand: L('خضراء الخليج', 'Gulf Volt'),
      partNumber: 'AD-T1T2-32A',
      genuine: false,
      warrantyMonths: 12,
      stock: 7,
      deliveryDays: 2,
      description: L(
        'محول يسمح بشحن سيارة بمنفذ Type 1 من شاحن Type 2 — وهو الشائع في '
            'مواقف الشحن العامة. للتيار المتردد فقط، ولا يزيد سرعة الشحن عن '
            'أقصى ما تقبله السيارة.',
        'Adapter that lets a Type 1 car charge from a Type 2 charger — the '
            'common kind in public car parks. AC only, and it cannot charge '
            'faster than the car itself accepts.',
      ),
      specs: [
        ProductSpec(L('من / إلى', 'From / to'), L('Type 2 (شاحن) إلى Type 1 (سيارة)', 'Type 2 (charger) to Type 1 (car)')),
        ProductSpec(L('التيار', 'Current'), L('٣٢ أمبير', '32 A')),
        ProductSpec(L('نوع التيار', 'Current type'), L('متردد AC فقط', 'AC only')),
        ProductSpec(L('لا يصلح لشواحن', 'Not for'), L('الشحن السريع DC', 'DC fast charging')),
      ],
    ),
    Product(
      id: 'pr10',
      name: L('إطار للسيارات الكهربائية 235/55R19', 'EV-rated tyre 235/55R19'),
      price: 44,
      categoryId: 'tyres',
      providerId: 'p1',
      region: 'Muscat',
      icon: LucideIcons.circleDot,
      fits: {'any'},
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      rating: 4.6,
      brand: L('ميشلان', 'Michelin'),
      partNumber: 'EPRIM-2355519',
      genuine: false,
      warrantyMonths: 12,
      stock: 12,
      deliveryDays: 2,
      fittingAvailable: true,
      description: L(
        'إطار مصمم للسيارات الكهربائية: مؤشر حمل أعلى لوزن البطارية، '
            'مقاومة دوران منخفضة لمدى أطول، وطبقة عازلة للصوت. السعر لإطار '
            'واحد، والتركيب والترصيص متاح في الورشة.',
        'Tyre built for electric cars: a higher load index for pack weight, '
            'low rolling resistance for range, and a foam layer for noise. '
            'Price is per tyre; fitting and balancing available at the '
            'workshop.',
      ),
      specs: [
        ProductSpec(L('المقاس', 'Size'), L('235/55R19', '235/55R19')),
        ProductSpec(L('مؤشر الحمل', 'Load index'), L('١٠٥ (٩٢٥ كجم)', '105 (925 kg)')),
        ProductSpec(L('مؤشر السرعة', 'Speed rating'), L('V (٢٤٠ كم/س)', 'V (240 km/h)')),
        ProductSpec(L('مقاومة الدوران', 'Rolling resistance'), L('منخفضة (A)', 'Low (A)')),
        ProductSpec(L('عزل الصوت', 'Noise foam'), L('مضمّن', 'Included')),
        ProductSpec(L('الكمية', 'Quantity'), L('إطار واحد', 'Single tyre')),
      ],
    ),
    Product(
      id: 'pr11',
      name: L('بطارية ١٢ فولت مساعدة للسيارات الكهربائية',
          '12V auxiliary battery for EVs'),
      price: 31,
      categoryId: 'batteries',
      providerId: 'p6',
      region: 'Dhofar',
      icon: LucideIcons.batteryMedium,
      fits: {'any'},
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      rating: 4.5,
      brand: L('فارتا', 'Varta'),
      partNumber: 'AGM-45-EV',
      genuine: false,
      warrantyMonths: 24,
      stock: 4,
      deliveryDays: 3,
      fittingAvailable: true,
      description: L(
        'بطارية AGM ١٢ فولت للدوائر المساعدة في السيارات الكهربائية — تشغّل '
            'الأقفال والشاشات وتنبيه البطارية الرئيسية. ضعفها هو أكثر سبب '
            'شائع لعدم استجابة السيارة الكهربائية حتى وحزمتها مشحونة. '
            'الاستبدال يجب أن يتم في ورشة معتمدة للسيارات الكهربائية.',
        'A 12V AGM battery for the auxiliary circuits of an electric car — '
            'locks, screens, and waking the main pack. A weak one is the most '
            'common reason an EV will not respond even with a charged pack. '
            'Replacement should be done by an EV-certified workshop.',
      ),
      specs: [
        ProductSpec(L('السعة', 'Capacity'), L('٤٥ أمبير/ساعة', '45 Ah')),
        ProductSpec(L('الجهد', 'Voltage'), L('١٢ فولت', '12 V')),
        ProductSpec(L('التقنية', 'Technology'), L('AGM مغلقة', 'Sealed AGM')),
        ProductSpec(L('اتجاه الأقطاب', 'Terminal layout'), L('موجب يمين', 'Positive right')),
        ProductSpec(L('التركيب', 'Fitting'), L('في ورشة معتمدة للسيارات الكهربائية', 'By an EV-certified workshop')),
      ],
    ),
    Product(
      id: 'pr12',
      name: L('فلتر مقصورة للسيارات الكهربائية', 'Cabin filter for EVs'),
      price: 6,
      categoryId: 'filters',
      providerId: 'p2',
      region: 'Muscat',
      icon: LucideIcons.wind,
      fits: {'any'},
      powertrains: {Powertrain.electric, Powertrain.pluginHybrid},
      rating: 4.4,
      brand: L('مان فلتر', 'Mann-Filter'),
      partNumber: 'CUK-EV-2941',
      genuine: false,
      warrantyMonths: 6,
      stock: 18,
      deliveryDays: 1,
      description: L(
        'فلتر مقصورة بكربون نشط لمقاس السيارات الكهربائية الشائعة. في '
            'السيارة الكهربائية يعمل المكيف حتى والسيارة واقفة، فيتحمل الفلتر '
            'ساعات تشغيل أكثر — يُنصح بفحصه كل ١٢ شهراً.',
        'Activated-carbon cabin filter in the size common to current electric '
            'cars. In an EV the AC runs while the car is parked, so the filter '
            'sees more hours than it would in a petrol car — worth checking '
            'every 12 months.',
      ),
      specs: [
        ProductSpec(L('النوع', 'Type'), L('كربون نشط', 'Activated carbon')),
        ProductSpec(L('الأبعاد', 'Dimensions'), L('٢٧٥ × ٢٢٠ × ٣٢ مم', '275 × 220 × 32 mm')),
        ProductSpec(L('فترة الفحص', 'Check interval'), L('١٢ شهراً', '12 months')),
        ProductSpec(L('التركيب', 'Fitting'), L('بدون أدوات', 'No tools needed')),
      ],
    ),
  ];
}
