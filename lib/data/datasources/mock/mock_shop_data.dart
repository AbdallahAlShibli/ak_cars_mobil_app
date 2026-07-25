import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
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
  };

  static const products = <Product>[
    Product(
      id: 'pr1',
      name: L('فلتر زيت أصلي', 'Genuine oil filter'),
      price: 3.5,
      categoryId: 'filters',
      providerId: 'p1',
      region: 'Muscat',
      icon: Icons.filter_alt_outlined,
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
      icon: Icons.battery_full_rounded,
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
      icon: Icons.album_outlined,
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
      icon: Icons.lightbulb_outline_rounded,
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
      icon: Icons.trip_origin_rounded,
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
      icon: Icons.air_rounded,
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
  ];
}
