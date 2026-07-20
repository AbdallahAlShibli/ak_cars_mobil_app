import 'package:flutter/widgets.dart';

/// Bilingual string pair — used by data models that carry display text.
class L {
  const L(this.ar, this.en);

  final String ar;
  final String en;

  String of(S s) => s.isAr ? ar : en;
}

/// Lightweight AR/EN strings lookup. Arabic is the app default.
///
/// Usage: `final s = S.of(context);` then `s.navHome` for shared strings or
/// `s.t('عربي', 'English')` inline for screen-local ones. Rebuilds happen
/// automatically when the MaterialApp locale flips.
class S {
  const S(this.isAr);

  final bool isAr;

  static S of(BuildContext context) =>
      S(Localizations.localeOf(context).languageCode == 'ar');

  String t(String ar, String en) => isAr ? ar : en;

  // ---------------------------------------------------------------- nav
  String get navHome => t('الرئيسية', 'Home');
  String get navServices => t('الخدمات', 'Services');
  String get navShop => t('المتجر', 'Shop');
  String get navCars => t('السيارات', 'Cars');
  String get navProfile => t('حسابي', 'Profile');

  // ---------------------------------------------------------------- common
  String get omr => t('ر.ع', 'OMR');
  String get km => t('كم', 'km');
  String get details => t('التفاصيل', 'Details');
  String get viewAll => t('عرض الكل', 'View all');
  String get settings => t('الإعدادات', 'Settings');

  // ---------------------------------------------------------------- home
  String greeting(String name) => t('أهلاً، $name!', 'Hello, $name!');
  String get greetingSub =>
      t('وش تحتاج سيارتك اليوم؟', 'What does your car need today?');
  String get searchHint =>
      t('ابحث عن خدمة، قطعة، أو سيارة…', 'Search services, parts, cars…');
  String get maintenanceTitle => t('متابعة الصيانة', 'Maintenance');
  String get mostSearched => t('الأكثر بحثاً', 'Most searched');
  String get bookService => t('حجز صيانة', 'Book service');
  String get roadside => t('مساعدة طريق', 'Roadside');
  String get parts => t('قطع غيار', 'Parts');
  String get sellCar => t('بِع سيارتك', 'Sell car');
  String get weeklyChallenge => t('تحدي الأسبوع', 'Weekly challenge');
}
