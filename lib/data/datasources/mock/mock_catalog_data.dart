import 'package:flutter/material.dart';

import '../../models/car_make.dart';
import '../../models/location_catalog.dart';
import '../../models/spec_catalog.dart';
import '../../models/spec_option.dart';
import '../../models/vehicle_catalog.dart';

/// Bundled reference catalogs.
///
/// This is the *seed* the mock catalog service serves. In Phase 2 the same
/// shapes come from `GET /cars/catalog`, `GET /cars/spec-options`,
/// `GET /cars/trims` and `GET /locations`; nothing outside the services layer
/// references this file.
abstract final class MockCatalogData {
  // --------------------------------------------------------------- vehicles
  static const vehicleCatalog = VehicleCatalog(
    makes: _makes,
    trimsByModel: _trimsByModel,
    plateLetters: ['A', 'B', 'D', 'H', 'M', 'R', 'S', 'W', 'X', 'Y'],
  );

  static const _makes = <CarMake>[
    CarMake('Toyota', [
      '86', 'Avalon', 'Camry', 'Corolla', 'Crown', 'C-HR', 'FJ Cruiser',
      'Fortuner', 'Hiace', 'Hilux', 'Land Cruiser', 'Land Cruiser 70',
      'Prado', 'RAV4', 'Rush', 'Sequoia', 'Supra', 'Tacoma', 'Tundra',
      'Urban Cruiser', 'Yaris',
    ], monogram: 'TO'),
    CarMake('Nissan', [
      'Altima', 'Armada', 'Kicks', 'Maxima', 'Navara', 'Pathfinder',
      'Patrol', 'Sunny', 'X-Trail', 'Xterra', 'Z',
    ], monogram: 'NI'),
    CarMake('Lexus', [
      'ES', 'GX', 'IS', 'LS', 'LX', 'NX', 'RX', 'UX',
    ], monogram: 'LX'),
    CarMake('Mercedes-Benz', [
      'A-Class', 'C-Class', 'E-Class', 'S-Class', 'G-Class', 'GLC', 'GLE',
      'GLS',
    ], monogram: 'MB'),
    CarMake('Honda', [
      'Accord', 'City', 'Civic', 'CR-V', 'HR-V', 'Pilot',
    ], monogram: 'HO'),
    CarMake('Hyundai', [
      'Accent', 'Creta', 'Elantra', 'Palisade', 'Santa Fe', 'Sonata',
      'Tucson',
    ], monogram: 'HY'),
    CarMake('Jeep', [
      'Cherokee', 'Grand Cherokee', 'Wrangler',
    ], monogram: 'JP'),
    CarMake('Dodge', ['Challenger', 'Charger', 'Durango'], monogram: 'DO'),
    CarMake('Ford', [
      'Bronco', 'Edge', 'Expedition', 'Explorer', 'F-150', 'Mustang',
      'Ranger', 'Taurus',
    ], monogram: 'FO'),
    CarMake('Chevrolet', [
      'Camaro', 'Captiva', 'Corvette', 'Groove', 'Malibu', 'Silverado',
      'Tahoe', 'Traverse',
    ], monogram: 'CH'),
    CarMake('GMC', ['Acadia', 'Sierra', 'Terrain', 'Yukon'], monogram: 'GM'),
    CarMake('Mitsubishi', [
      'ASX', 'Attrage', 'L200', 'Montero Sport', 'Outlander', 'Pajero',
    ], monogram: 'MI'),
    CarMake('Kia', [
      'Cerato', 'K5', 'Pegas', 'Seltos', 'Sorento', 'Sportage', 'Telluride',
    ], monogram: 'KIA'),
    CarMake('BMW', [
      '3 Series', '5 Series', '7 Series', 'X3', 'X5', 'X6', 'X7',
    ], monogram: 'BMW'),
    CarMake('Audi', ['A4', 'A6', 'A8', 'Q3', 'Q5', 'Q7', 'Q8'], monogram: 'AU'),
    CarMake('Volkswagen', [
      'Golf', 'Jetta', 'Passat', 'Teramont', 'Tiguan', 'Touareg',
    ], monogram: 'VW'),
    CarMake('Mazda', ['CX-5', 'CX-9', 'Mazda3', 'Mazda6'], monogram: 'MA'),
    CarMake('Subaru', ['Forester', 'Impreza', 'Outback', 'XV'], monogram: 'SU'),
    CarMake('Suzuki', [
      'Baleno', 'Ciaz', 'Dzire', 'Grand Vitara', 'Jimny', 'Swift',
    ], monogram: 'SZ'),
    CarMake('Isuzu', ['D-Max', 'MU-X'], monogram: 'IS'),
    CarMake('Land Rover', [
      'Defender', 'Discovery', 'Discovery Sport',
    ], monogram: 'LR'),
    CarMake('Range Rover', [
      'Evoque', 'Sport', 'Velar', 'Vogue',
    ], monogram: 'RR'),
    CarMake('Infiniti', ['Q50', 'QX50', 'QX60', 'QX80'], monogram: 'IN'),
    CarMake('Porsche', [
      '911', 'Cayenne', 'Macan', 'Panamera', 'Taycan',
    ], monogram: 'PO'),
    CarMake('Volvo', ['S90', 'XC40', 'XC60', 'XC90'], monogram: 'VO'),
    CarMake('Mini', ['Clubman', 'Cooper', 'Countryman'], monogram: 'MN'),
    CarMake('Lincoln', ['Aviator', 'Navigator', 'Nautilus'], monogram: 'LI'),
    CarMake('Cadillac', ['CT5', 'Escalade', 'XT5', 'XT6'], monogram: 'CA'),
    CarMake('Genesis', ['G70', 'G80', 'GV70', 'GV80'], monogram: 'GE'),
    CarMake('Tesla', ['Model 3', 'Model S', 'Model X', 'Model Y'],
        monogram: 'TE'),
    CarMake('MG', ['5', 'GT', 'HS', 'RX5', 'ZS'], monogram: 'MG'),
    CarMake('Changan', ['Alsvin', 'CS35 Plus', 'CS75', 'Eado'],
        monogram: 'CN'),
    CarMake('Geely', ['Coolray', 'Emgrand', 'Monjaro', 'Tugella'],
        monogram: 'GL'),
  ];

  /// Covers the feed's models plus popular ones so the Sub-Model filter is
  /// rarely empty; extend as inventory grows.
  static const _trimsByModel = <String, List<String>>{
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

  // ------------------------------------------------------------------ specs
  static const specCatalog = SpecCatalog(
    bodyTypes: [
      SpecOption('Sedan', 'سيدان', 'Sedan'),
      SpecOption('SUV', 'دفع رباعي', 'SUV'),
      SpecOption('Crossover', 'كروس أوفر', 'Crossover'),
      SpecOption('Hatchback', 'هاتشباك', 'Hatchback'),
      SpecOption('Coupe', 'كوبيه', 'Coupe'),
      SpecOption('Convertible', 'مكشوفة', 'Convertible'),
      SpecOption('Pickup', 'بيك أب', 'Pickup'),
      SpecOption('Van', 'فان', 'Van'),
      SpecOption('Wagon', 'ستيشن', 'Wagon'),
    ],
    conditions: [
      SpecOption('New', 'جديد', 'New'),
      SpecOption('Used', 'مستعمل', 'Used'),
    ],
    regionalSpecs: [
      SpecOption('GCC', 'خليجي', 'GCC'),
      SpecOption('American', 'أمريكي', 'American'),
      SpecOption('European', 'أوروبي', 'European'),
      SpecOption('Japanese', 'ياباني', 'Japanese'),
      SpecOption('Korean', 'كوري', 'Korean'),
      SpecOption('Chinese', 'صيني', 'Chinese'),
      SpecOption('Canadian', 'كندي', 'Canadian'),
      SpecOption('Other', 'أخرى', 'Other'),
    ],
    fuels: [
      SpecOption('Petrol', 'بنزين', 'Petrol'),
      SpecOption('Diesel', 'ديزل', 'Diesel'),
      SpecOption('Hybrid', 'هجين', 'Hybrid'),
      SpecOption('Plug-in Hybrid', 'هجين قابل للشحن', 'Plug-in Hybrid'),
      SpecOption('Electric', 'كهربائي', 'Electric'),
    ],
    transmissions: [
      SpecOption('Automatic', 'أوتوماتيك', 'Automatic'),
      SpecOption('Manual', 'عادي', 'Manual'),
      SpecOption('CVT', 'ناقل متغير CVT', 'CVT'),
      SpecOption('Dual-clutch', 'مزدوج القابض DCT', 'Dual-clutch (DCT)'),
      SpecOption('Single-speed', 'سرعة واحدة (كهربائي)', 'Single-speed (EV)'),
    ],
    drivetrains: [
      SpecOption('Front-wheel drive', 'دفع أمامي', 'Front-wheel drive'),
      SpecOption('Rear-wheel drive', 'دفع خلفي', 'Rear-wheel drive'),
      SpecOption('All-wheel drive', 'دفع كلي AWD', 'All-wheel drive'),
      SpecOption('Four-wheel drive', 'دفع رباعي 4×4', 'Four-wheel drive'),
    ],
    cylinders: [
      SpecOption(0, 'كهربائي (بدون إسطوانات)', 'Electric (no cylinders)'),
      SpecOption(3, '3 إسطوانات', '3 cylinders'),
      SpecOption(4, '4 إسطوانات', '4 cylinders'),
      SpecOption(5, '5 إسطوانات', '5 cylinders'),
      SpecOption(6, '6 إسطوانات', '6 cylinders'),
      SpecOption(8, '8 إسطوانات', '8 cylinders'),
      SpecOption(10, '10 إسطوانات', '10 cylinders'),
      SpecOption(12, '12 إسطوانة', '12 cylinders'),
    ],
    engineSizes: [
      EngineBucket(
          'electric', 'كهربائي (بدون محرك)', 'Electric (no engine)', 0.0, 0.0),
      EngineBucket('under1.5', 'أقل من 1.5 لتر', 'Under 1.5 L', 0.1, 1.4),
      EngineBucket('1.5-2.0', '1.5 – 2.0 لتر', '1.5 – 2.0 L', 1.5, 2.0),
      EngineBucket('2.1-3.0', '2.1 – 3.0 لتر', '2.1 – 3.0 L', 2.1, 3.0),
      EngineBucket('3.1-4.0', '3.1 – 4.0 لتر', '3.1 – 4.0 L', 3.1, 4.0),
      EngineBucket('over4.0', 'أكثر من 4.0 لتر', 'Over 4.0 L', 4.1, 99.0),
    ],
    doors: [
      SpecOption(2, 'بابان', '2 doors'),
      SpecOption(3, '3 أبواب', '3 doors'),
      SpecOption(4, '4 أبواب', '4 doors'),
      SpecOption(5, '5 أبواب', '5 doors'),
    ],
    seats: [
      SpecOption(2, 'مقعدان', '2 seats'),
      SpecOption(4, '4 مقاعد', '4 seats'),
      SpecOption(5, '5 مقاعد', '5 seats'),
      SpecOption(6, '6 مقاعد', '6 seats'),
      SpecOption(7, '7 مقاعد', '7 seats'),
      SpecOption(8, '8 مقاعد أو أكثر', '8+ seats'),
    ],
    sellerTypes: [
      SpecOption('Owner', 'المالك', 'Owner'),
      SpecOption('Dealer', 'تاجر', 'Dealer'),
      SpecOption('Showroom', 'معرض', 'Showroom'),
    ],
    dealTypes: [
      SpecOption('Sale only', 'بيع فقط', 'Sale only'),
      SpecOption('Sale or exchange', 'بيع أو تبديل', 'Sale or exchange'),
    ],
    colors: [
      SpecOption('White', 'أبيض', 'White'),
      SpecOption('Black', 'أسود', 'Black'),
      SpecOption('Silver', 'فضي', 'Silver'),
      SpecOption('Gray', 'رمادي', 'Gray'),
      SpecOption('Blue', 'أزرق', 'Blue'),
      SpecOption('Red', 'أحمر', 'Red'),
      SpecOption('Maroon', 'كستنائي', 'Maroon'),
      SpecOption('Beige', 'بيج', 'Beige'),
      SpecOption('Brown', 'بني', 'Brown'),
      SpecOption('Gold', 'ذهبي', 'Gold'),
      SpecOption('Green', 'أخضر', 'Green'),
      SpecOption('Orange', 'برتقالي', 'Orange'),
      SpecOption('Yellow', 'أصفر', 'Yellow'),
    ],
    swatches: {
      'White': Color(0xFFF3F4F6),
      'Black': Color(0xFF17181A),
      'Silver': Color(0xFFC0C4CC),
      'Gray': Color(0xFF9CA3AF),
      'Blue': Color(0xFF1E3A5F),
      'Red': Color(0xFF9B1C31),
      'Maroon': Color(0xFF7B2D3B),
      'Beige': Color(0xFFD9C9A8),
      'Brown': Color(0xFF6B4A2F),
      'Gold': Color(0xFFC9A24B),
      'Green': Color(0xFF2F5D3A),
      'Orange': Color(0xFFC96B1E),
      'Yellow': Color(0xFFE0B93B),
    },
  );

  // -------------------------------------------------------------- locations
  static const locationCatalog = LocationCatalog(
    governorates: {
      'Muscat': [
        'Muscat', 'Muttrah', 'Bawshar', 'Seeb', 'Al Amerat', 'Qurayyat',
      ],
      'Dhofar': [
        'Salalah', 'Taqah', 'Mirbat', 'Thumrait', 'Sadah', 'Rakhyut',
      ],
      'Musandam': ['Khasab', 'Bukha', 'Daba', 'Madha'],
      'Al Buraimi': ['Al Buraimi', 'Mahdah', 'Al Sinainah'],
      'Ad Dakhiliyah': [
        'Nizwa', 'Bahla', 'Manah', 'Al Hamra', 'Adam', 'Izki', 'Samail',
        'Bidbid',
      ],
      'North Al Batinah': [
        'Sohar', 'Shinas', 'Liwa', 'Saham', 'Al Khaburah', 'As Suwayq',
      ],
      'South Al Batinah': [
        'Rustaq', 'Al Awabi', 'Nakhal', 'Wadi Al Maawil', 'Barka',
        'Al Musannah',
      ],
      'South Ash Sharqiyah': [
        'Sur', 'Al Kamil Wal Wafi', 'Jalan Bani Bu Hassan',
        'Jalan Bani Bu Ali', 'Masirah',
      ],
      'North Ash Sharqiyah': [
        'Ibra', 'Al Mudhaibi', 'Bidiyah', 'Al Qabil', 'Wadi Bani Khalid',
        'Dema Wa Thaieen',
      ],
      'Ad Dhahirah': ['Ibri', 'Yanqul', 'Dhank'],
      'Al Wusta': ['Haima', 'Duqm', 'Mahout', 'Al Jazer'],
    },
    arabicNames: {
      // Governorates
      'Muscat': 'مسقط',
      'Dhofar': 'ظفار',
      'Musandam': 'مسندم',
      'Al Buraimi': 'البريمي',
      'Ad Dakhiliyah': 'الداخلية',
      'North Al Batinah': 'شمال الباطنة',
      'South Al Batinah': 'جنوب الباطنة',
      'South Ash Sharqiyah': 'جنوب الشرقية',
      'North Ash Sharqiyah': 'شمال الشرقية',
      'Ad Dhahirah': 'الظاهرة',
      'Al Wusta': 'الوسطى',
      // Wilayats
      'Muttrah': 'مطرح',
      'Bawshar': 'بوشر',
      'Seeb': 'السيب',
      'Al Amerat': 'العامرات',
      'Qurayyat': 'قريات',
      'Salalah': 'صلالة',
      'Taqah': 'طاقة',
      'Mirbat': 'مرباط',
      'Thumrait': 'ثمريت',
      'Sadah': 'سدح',
      'Rakhyut': 'رخيوت',
      'Khasab': 'خصب',
      'Bukha': 'بخا',
      'Daba': 'دبا',
      'Madha': 'مدحاء',
      'Mahdah': 'محضة',
      'Al Sinainah': 'السنينة',
      'Nizwa': 'نزوى',
      'Bahla': 'بهلاء',
      'Manah': 'منح',
      'Al Hamra': 'الحمراء',
      'Adam': 'أدم',
      'Izki': 'إزكي',
      'Samail': 'سمائل',
      'Bidbid': 'بدبد',
      'Sohar': 'صحار',
      'Shinas': 'شناص',
      'Liwa': 'لوى',
      'Saham': 'صحم',
      'Al Khaburah': 'الخابورة',
      'As Suwayq': 'السويق',
      'Rustaq': 'الرستاق',
      'Al Awabi': 'العوابي',
      'Nakhal': 'نخل',
      'Wadi Al Maawil': 'وادي المعاول',
      'Barka': 'بركاء',
      'Al Musannah': 'المصنعة',
      'Sur': 'صور',
      'Al Kamil Wal Wafi': 'الكامل والوافي',
      'Jalan Bani Bu Hassan': 'جعلان بني بو حسن',
      'Jalan Bani Bu Ali': 'جعلان بني بو علي',
      'Masirah': 'مصيرة',
      'Ibra': 'إبراء',
      'Al Mudhaibi': 'المضيبي',
      'Bidiyah': 'بدية',
      'Al Qabil': 'القابل',
      'Wadi Bani Khalid': 'وادي بني خالد',
      'Dema Wa Thaieen': 'دماء والطائيين',
      'Ibri': 'عبري',
      'Yanqul': 'ينقل',
      'Dhank': 'ضنك',
      'Haima': 'هيماء',
      'Duqm': 'الدقم',
      'Mahout': 'محوت',
      'Al Jazer': 'الجازر',
      // Areas used by providers/listings
      'Al Khuwair': 'الخوير',
      'Qurum': 'القرم',
      'Al Batinah': 'الباطنة',
    },
  );

  /// Governorates where parts/providers operate (subset of the full list).
  /// Canonical English keys — display via [LocationCatalog.localized].
  ///
  /// Must stay in step with the governorates in `MockServiceData.providers`:
  /// this list seeds the default `regionProvider` and drives the settings and
  /// shop filters, so a governorate missing here is one the user can never
  /// select even though workshops serve it. `South Al Batinah` used to be
  /// exactly that.
  static const serviceRegions = [
    'Muscat',
    'North Al Batinah',
    'South Al Batinah',
    'Ad Dakhiliyah',
    'Dhofar',
  ];
}
