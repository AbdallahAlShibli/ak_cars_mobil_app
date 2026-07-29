import 'package:flutter/widgets.dart';

import '../../config/app_flags.dart';

/// Bilingual string pair — used by data models that carry display text.
///
/// Server-side this is a `{ "ar": "...", "en": "..." }` object. Storing both
/// languages on the record (rather than resolving server-side from an
/// `Accept-Language` header) is deliberate: persisted content such as
/// notifications must render in whatever language is active when the user
/// reads it, not the one that was active when it was written.
class L {
  const L(this.ar, this.en);

  final String ar;
  final String en;

  String of(S s) => s.isAr ? ar : en;

  /// Accepts the object form, or a bare string when only one language exists
  /// (both fields then hold the same text).
  factory L.fromJson(Object? json) {
    if (json is String) return L(json, json);
    if (json is Map) {
      final ar = json['ar']?.toString();
      final en = json['en']?.toString();
      return L(ar ?? en ?? '', en ?? ar ?? '');
    }
    return const L('', '');
  }

  Map<String, dynamic> toJson() => {'ar': ar, 'en': en};

  L copyWith({String? ar, String? en}) => L(ar ?? this.ar, en ?? this.en);

  @override
  bool operator ==(Object other) =>
      other is L && other.ar == ar && other.en == en;

  @override
  int get hashCode => Object.hash(ar, en);

  @override
  String toString() => 'L($ar / $en)';
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

  /// The two tabs the focused navigation added (spec §2): the escrow queue
  /// and the garage.
  String get navBookings => t('حجوزاتي', 'Bookings');
  String get navMyCar => t('سيارتي', 'My car');

  // ---------------------------------------------------------------- common
  String get omr => t('ر.ع', 'OMR');
  String get km => t('كم', 'km');
  String get details => t('التفاصيل', 'Details');
  String get viewAll => t('عرض الكل', 'View all');
  String get settings => t('الإعدادات', 'Settings');

  /// Counted noun, Arabic-correct.
  ///
  /// Arabic inflects a counted noun by the number in front of it: singular for
  /// one, a dual form for two, the broken plural for 3–10, then back to the
  /// singular from 11 up. "3 ورشة" and "2 ورش" both read as broken Arabic, so
  /// counts go through here rather than being interpolated inline.
  ///
  /// [dual] is the two-of-them form, [few] covers 3–10, [many] covers 11+.
  String count(
    int n, {
    required String one,
    required String dual,
    required String few,
    required String many,
    required String enOne,
    required String enMany,
    String? zeroAr,
    String? zeroEn,
  }) {
    if (!isAr) {
      if (n == 0 && zeroEn != null) return zeroEn;
      return n == 1 ? '1 $enOne' : '$n $enMany';
    }
    if (n == 0) return zeroAr ?? 'لا $few';
    if (n == 1) return one;
    if (n == 2) return dual;
    if (n <= 10) return '$n $few';
    return '$n $many';
  }

  /// "ورشة واحدة" / "ورشتان" / "5 ورش" / "14 ورشة" — and the English plural.
  String workshops(int n) => count(
        n,
        one: 'ورشة واحدة',
        dual: 'ورشتان',
        few: 'ورش',
        many: 'ورشة',
        enOne: 'workshop',
        enMany: 'workshops',
        zeroAr: 'لا توجد ورش',
        zeroEn: 'No workshops',
      );

  /// "خدمة واحدة" / "خدمتان" / "5 خدمات" / "14 خدمة".
  String services(int n) => count(
        n,
        one: 'خدمة واحدة',
        dual: 'خدمتان',
        few: 'خدمات',
        many: 'خدمة',
        enOne: 'service',
        enMany: 'services',
        zeroAr: 'لا توجد خدمات',
        zeroEn: 'No services',
      );

  /// "تقييم واحد" / "تقييمان" / "5 تقييمات" / "14 تقييماً".
  String reviews(int n) => count(
        n,
        one: 'تقييم واحد',
        dual: 'تقييمان',
        few: 'تقييمات',
        many: 'تقييماً',
        enOne: 'review',
        enMany: 'reviews',
        zeroAr: 'لا تقييمات',
        zeroEn: 'No reviews',
      );

  /// "حجز واحد" / "حجزان" / "5 حجوزات" / "14 حجزاً".
  String bookings(int n) => count(
        n,
        one: 'حجز واحد',
        dual: 'حجزان',
        few: 'حجوزات',
        many: 'حجزاً',
        enOne: 'booking',
        enMany: 'bookings',
        zeroAr: 'لا حجوزات',
        zeroEn: 'No bookings',
      );

  /// "يوم واحد" / "يومان" / "5 أيام" / "14 يوماً".
  String days(int n) => count(
        n,
        one: 'يوم واحد',
        dual: 'يومان',
        few: 'أيام',
        many: 'يوماً',
        enOne: 'day',
        enMany: 'days',
      );

  /// "شهر واحد" / "شهران" / "5 أشهر" / "14 شهراً".
  String months(int n) => count(
        n,
        one: 'شهر واحد',
        dual: 'شهران',
        few: 'أشهر',
        many: 'شهراً',
        enOne: 'month',
        enMany: 'months',
      );

  /// "نتيجة واحدة" / "نتيجتان" / "5 نتائج" / "14 نتيجة".
  String resultsCount(int n) => count(
        n,
        one: 'نتيجة واحدة',
        dual: 'نتيجتان',
        few: 'نتائج',
        many: 'نتيجة',
        enOne: 'result',
        enMany: 'results',
        zeroAr: 'لا نتائج',
        zeroEn: 'No results',
      );

  // ---------------------------------------------------------------- home
  String greeting(String name) => t('أهلاً، $name!', 'Hello, $name!');
  String get greetingSub =>
      t('وش تحتاج سيارتك اليوم؟', 'What does your car need today?');
  /// Names only the catalogues this build searches — the parts and cars
  /// pillars are hidden in phase 1 (`AppFlags`), and a hint that promises
  /// them would be a field advertising results it cannot return.
  String get searchHint => AppFlags.partsStoreEnabled ||
          AppFlags.carMarketplaceEnabled
      ? t('ابحث عن خدمة، قطعة، أو سيارة…', 'Search services, parts, cars…')
      : t('ابحث عن خدمة أو ورشة…', 'Search services or workshops…');
  String get maintenanceTitle => t('متابعة الصيانة', 'Maintenance');
  /// Was `mostSearched` ("الأكثر بحثاً" / "Most searched") until 2026-07-25.
  /// Nothing in the app records searches, so the home rail now says what it
  /// actually shows: the newest ads.
  String get latestAds => t('أحدث الإعلانات', 'Latest ads');
  String get bookService => t('حجز صيانة', 'Book service');

  // ------------------------------------------------------- home sections
  /// Section 2 — real, time-boxed discounts only. Announcements live under
  /// [announcementsTitle] further down, because a section that promises offers
  /// has to be able to be empty (home-page spec §2).
  String get offersTitle => t('عروض هذا الأسبوع', "This week's offers");

  /// Platform announcements — no price, no deadline, no discount.
  String get announcementsTitle => t('من AK Cars', 'From AK Cars');

  /// Section 1. Named for the question it answers rather than for the objects
  /// it lists: the cards are the user's cars, but the point of them is what
  /// each car needs next.
  String get carStatusTitle => t('حالة سيارتي', 'My car status');
  String get myCarsTitle => t('سياراتي', 'My cars');
  String get addCar => t('أضف سيارة', 'Add a car');

  // ---------------------------------------------------- trusted workshops
  /// Section 3.
  String get trustedWorkshopsTitle => t('ورش موثوقة', 'Trusted workshops');
  String get topRatedTab => t('الأعلى تقييماً', 'Top rated');
  String get mostRequestedTab => t('الأكثر طلباً', 'Most requested');

  /// The heading used when there are not enough ratings to rank anything —
  /// a different claim, so a different title.
  String get approvedNearbyTitle =>
      t('ورش معتمدة قريبة منك', 'Approved workshops near you');
  String get approvedBadge => t('معتمدة', 'Approved');

  String get bookNow => t('احجز الآن', 'Book now');
  String get overdueBookNow => t('متأخّر — احجز الآن', 'Overdue — book now');

  /// Recommendations are per registered car, so the heading says so.
  String get recommendedTitle => t('مقترح لسيارتك', 'Suggested for your car');
  String get mostBookedTitle => t('الأكثر حجزاً', 'Most booked');
  String get topRatedTitle => t('ورش بأعلى تقييم', 'Top-rated workshops');
  String get noRecordShort => t('لا سجل', 'no record');

  String get roadside => t('مساعدة طريق', 'Roadside');
  String get parts => t('قطع غيار', 'Parts');
  String get sellCar => t('بِع سيارتك', 'Sell car');
  String get weeklyChallenge => t('تحدي الأسبوع', 'Weekly challenge');
}
