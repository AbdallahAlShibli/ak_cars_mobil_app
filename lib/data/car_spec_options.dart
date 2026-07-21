import 'package:flutter/material.dart';

/// Canonical vehicle-spec vocabulary for the cars marketplace.
///
/// Single source of truth shared by the filter (`cars_filter_screen.dart`)
/// and the post-ad form (`post_ad_screen.dart`). Filter facets must be
/// driven by this catalog — never by `distinct()` over the current feed,
/// otherwise buyers only ever see the values that happen to be listed today
/// (e.g. "Petrol" as the only fuel type) and sellers can publish values the
/// filter cannot express.
///
/// Replace with `GET /api/cars/spec-options` in Phase 2 — keep the `value`
/// strings stable, they are what gets persisted on a listing.

/// One selectable spec value plus its bilingual label.
class SpecOption<T> {
  const SpecOption(this.value, this.ar, this.en);

  /// Stored/persisted value (also what a listing holds).
  final T value;
  final String ar;
  final String en;
}

/// Engine-displacement bucket in litres; both bounds inclusive.
class EngineBucket {
  const EngineBucket(this.value, this.ar, this.en, this.min, this.max);

  final String value;
  final String ar;
  final String en;
  final double min;
  final double max;

  bool contains(double litres) => litres >= min && litres <= max;
}

abstract final class CarSpecs {
  // ---------------------------------------------------------------- vehicle
  static const bodyTypes = <SpecOption<String>>[
    SpecOption('Sedan', 'سيدان', 'Sedan'),
    SpecOption('SUV', 'دفع رباعي', 'SUV'),
    SpecOption('Crossover', 'كروس أوفر', 'Crossover'),
    SpecOption('Hatchback', 'هاتشباك', 'Hatchback'),
    SpecOption('Coupe', 'كوبيه', 'Coupe'),
    SpecOption('Convertible', 'مكشوفة', 'Convertible'),
    SpecOption('Pickup', 'بيك أب', 'Pickup'),
    SpecOption('Van', 'فان', 'Van'),
    SpecOption('Wagon', 'ستيشن', 'Wagon'),
  ];

  static const conditions = <SpecOption<String>>[
    SpecOption('New', 'جديد', 'New'),
    SpecOption('Used', 'مستعمل', 'Used'),
  ];

  /// Market the car was originally built/imported for — "وارد خليجي /
  /// أمريكي / ياباني". In Oman this drives price, AC and cooling spec,
  /// warranty eligibility and resale value, so it is the spec buyers filter
  /// on. (It replaced a First/Second "grade" facet, which described condition
  /// rather than origin and duplicated the Condition facet.)
  static const regionalSpecs = <SpecOption<String>>[
    SpecOption('GCC', 'خليجي', 'GCC'),
    SpecOption('American', 'أمريكي', 'American'),
    SpecOption('European', 'أوروبي', 'European'),
    SpecOption('Japanese', 'ياباني', 'Japanese'),
    SpecOption('Korean', 'كوري', 'Korean'),
    SpecOption('Chinese', 'صيني', 'Chinese'),
    SpecOption('Canadian', 'كندي', 'Canadian'),
    SpecOption('Other', 'أخرى', 'Other'),
  ];

  // ------------------------------------------------------------ powertrain
  static const fuels = <SpecOption<String>>[
    SpecOption('Petrol', 'بنزين', 'Petrol'),
    SpecOption('Diesel', 'ديزل', 'Diesel'),
    SpecOption('Hybrid', 'هجين', 'Hybrid'),
    SpecOption('Plug-in Hybrid', 'هجين قابل للشحن', 'Plug-in Hybrid'),
    SpecOption('Electric', 'كهربائي', 'Electric'),
  ];

  static const transmissions = <SpecOption<String>>[
    SpecOption('Automatic', 'أوتوماتيك', 'Automatic'),
    SpecOption('Manual', 'عادي', 'Manual'),
    SpecOption('CVT', 'ناقل متغير CVT', 'CVT'),
    SpecOption('Dual-clutch', 'مزدوج القابض DCT', 'Dual-clutch (DCT)'),
    SpecOption('Single-speed', 'سرعة واحدة (كهربائي)', 'Single-speed (EV)'),
  ];

  static const drivetrains = <SpecOption<String>>[
    SpecOption('Front-wheel drive', 'دفع أمامي', 'Front-wheel drive'),
    SpecOption('Rear-wheel drive', 'دفع خلفي', 'Rear-wheel drive'),
    SpecOption('All-wheel drive', 'دفع كلي AWD', 'All-wheel drive'),
    SpecOption('Four-wheel drive', 'دفع رباعي 4×4', 'Four-wheel drive'),
  ];

  /// `0` means an electric drivetrain with no combustion cylinders.
  static const cylinders = <SpecOption<int>>[
    SpecOption(0, 'كهربائي (بدون إسطوانات)', 'Electric (no cylinders)'),
    SpecOption(3, '3 إسطوانات', '3 cylinders'),
    SpecOption(4, '4 إسطوانات', '4 cylinders'),
    SpecOption(5, '5 إسطوانات', '5 cylinders'),
    SpecOption(6, '6 إسطوانات', '6 cylinders'),
    SpecOption(8, '8 إسطوانات', '8 cylinders'),
    SpecOption(10, '10 إسطوانات', '10 cylinders'),
    SpecOption(12, '12 إسطوانة', '12 cylinders'),
  ];

  static const engineSizes = <EngineBucket>[
    EngineBucket('electric', 'كهربائي (بدون محرك)', 'Electric (no engine)',
        0.0, 0.0),
    EngineBucket('under1.5', 'أقل من 1.5 لتر', 'Under 1.5 L', 0.1, 1.4),
    EngineBucket('1.5-2.0', '1.5 – 2.0 لتر', '1.5 – 2.0 L', 1.5, 2.0),
    EngineBucket('2.1-3.0', '2.1 – 3.0 لتر', '2.1 – 3.0 L', 2.1, 3.0),
    EngineBucket('3.1-4.0', '3.1 – 4.0 لتر', '3.1 – 4.0 L', 3.1, 4.0),
    EngineBucket('over4.0', 'أكثر من 4.0 لتر', 'Over 4.0 L', 4.1, 99.0),
  ];

  static EngineBucket? bucketOf(String value) {
    for (final b in engineSizes) {
      if (b.value == value) return b;
    }
    return null;
  }

  /// Bucket a raw displacement falls into — used when publishing an ad.
  static EngineBucket? bucketFor(double litres) {
    for (final b in engineSizes) {
      if (b.contains(litres)) return b;
    }
    return null;
  }

  // ------------------------------------------------------------- practical
  static const doors = <SpecOption<int>>[
    SpecOption(2, 'بابان', '2 doors'),
    SpecOption(3, '3 أبواب', '3 doors'),
    SpecOption(4, '4 أبواب', '4 doors'),
    SpecOption(5, '5 أبواب', '5 doors'),
  ];

  static const seats = <SpecOption<int>>[
    SpecOption(2, 'مقعدان', '2 seats'),
    SpecOption(4, '4 مقاعد', '4 seats'),
    SpecOption(5, '5 مقاعد', '5 seats'),
    SpecOption(6, '6 مقاعد', '6 seats'),
    SpecOption(7, '7 مقاعد', '7 seats'),
    SpecOption(8, '8 مقاعد أو أكثر', '8+ seats'),
  ];

  // ----------------------------------------------------------------- trade
  static const sellerTypes = <SpecOption<String>>[
    SpecOption('Owner', 'المالك', 'Owner'),
    SpecOption('Dealer', 'تاجر', 'Dealer'),
    SpecOption('Showroom', 'معرض', 'Showroom'),
  ];

  static const dealTypes = <SpecOption<String>>[
    SpecOption('Sale only', 'بيع فقط', 'Sale only'),
    SpecOption('Sale or exchange', 'بيع أو تبديل', 'Sale or exchange'),
  ];

  // ---------------------------------------------------------------- colors
  static const colors = <SpecOption<String>>[
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
  ];

  static const swatches = <String, Color>{
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
  };

  static Color swatchOf(String color) =>
      swatches[color] ?? const Color(0xFF9CA3AF);
}
