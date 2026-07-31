import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/features/auth/register_screen.dart';
import 'package:ak_cars_mobil_app/features/cars/listing_detail_screen.dart';
import 'package:ak_cars_mobil_app/features/cars/make_filter_screen.dart';
import 'package:ak_cars_mobil_app/features/cars/post_ad_screen.dart';
import 'package:ak_cars_mobil_app/features/garage/add_car_screen.dart';
import 'package:ak_cars_mobil_app/features/garage/maintenance_screen.dart';
import 'package:ak_cars_mobil_app/features/onboarding/start_choice_screen.dart';
import 'package:ak_cars_mobil_app/features/services/booking_screen.dart';
import 'package:ak_cars_mobil_app/features/services/requests_screen.dart';
import 'package:ak_cars_mobil_app/features/services/service_detail_screen.dart';
import 'package:ak_cars_mobil_app/features/services/services_screen.dart';
import 'package:ak_cars_mobil_app/features/shop/product_detail_screen.dart';

import 'helpers/test_harness.dart';

/// These screens shipped with hard-coded English text, so they stayed English
/// no matter which language was selected. Each case pumps the same screen
/// twice and asserts the Arabic build shows none of the English wording.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required String locale,
}) async {
  final container = await createTestContainer();
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: screen,
      ),
    ),
  );
  // Entrance() and the services-screen skeleton use Future.delayed, so pump
  // past every staggered delay before asserting.
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Renders [screen] in both languages: every string in [ar] must appear in the
/// Arabic build, every string in [en] in the English build — and the English
/// wording must be absent from the Arabic build.
void bilingualTest(
  String description,
  Widget Function() screen, {
  required List<String> ar,
  required List<String> en,
}) {
  // Content further down a scroll view is built but off-screen, so these
  // finders must not skip offstage widgets.
  Finder text(String value) =>
      find.textContaining(value, skipOffstage: false);

  testWidgets('$description — Arabic', (tester) async {
    await pumpScreen(tester, screen(), locale: 'ar');
    for (final value in ar) {
      expect(text(value), findsWidgets,
          reason: 'missing Arabic text: $value');
    }
    for (final value in en) {
      expect(text(value), findsNothing,
          reason: 'English leaked into the Arabic build: $value');
    }
  });

  testWidgets('$description — English', (tester) async {
    await pumpScreen(tester, screen(), locale: 'en');
    for (final value in en) {
      expect(text(value), findsWidgets,
          reason: 'missing English text: $value');
    }
  });
}

void main() {
  bilingualTest(
    'Services screen',
    () => const ServicesScreen(),
    ar: ['الخدمات', 'صيانة السيارات', 'خدمات أخرى', 'الأكثر طلباً في مسقط'],
    en: ['Services', 'Car service', 'Other services', 'Popular in Muscat'],
  );

  // "مفتوح"/"Open" was asserted here until 2026-07-25: the header used to
  // print an "Open" pill for every workshop regardless of its hours. The page
  // shows the real opening hours instead, so there is no such badge to find.
  bilingualTest(
    'Service detail screen',
    () => const ServiceDetailScreen(offeringId: 'o-p1-express'),
    ar: ['صيانة سريعة', 'المدة', 'سعر ثابت', 'ما الذي يشمله السعر'],
    en: ['Express service', 'Duration', 'Fixed price', "What's included"],
  );

  bilingualTest(
    'Booking screen',
    () => const BookingScreen(offeringId: 'o-p1-express'),
    ar: ['الوقت والمكان', 'زيارة الورشة', 'لوحة السيارة', 'الإجمالي'],
    en: ['Time & place', 'Visit workshop', 'Car plate', 'Total'],
  );

  bilingualTest(
    'Bookings screen (empty state)',
    () => const RequestsScreen(),
    ar: ['حجوزاتي', 'لا حجوزات بعد', 'حجز صيانة'],
    en: ['Bookings', 'No bookings yet', 'Book service'],
  );

  // Only the above-the-fold rows: this screen is a CustomScrollView, so
  // slivers past the viewport are never built for the finder to see.
  bilingualTest(
    'Listing detail screen',
    () => const ListingDetailScreen(listingId: 'g1'),
    ar: ['اسم السيارة', 'الحالة', 'اسأل عن السعر', 'الممشى'],
    en: ['Car name', 'Condition', 'Ask about price', 'Mileage'],
  );

  // The seller block sits below the fold in a CustomScrollView, so this
  // asserts only what the first viewport builds.
  bilingualTest(
    'Product detail screen',
    () => const ProductDetailScreen(productId: 'pr1'),
    ar: ['قطعة أصلية', 'رقم القطعة', 'شامل ضريبة القيمة المضافة', 'الوصف'],
    en: ['Genuine / OEM', 'Part no.', 'Includes 5% VAT', 'Description'],
  );

  bilingualTest(
    'Post ad screen',
    () => const PostAdScreen(),
    ar: ['انشر إعلان سيارة', 'السيارة', 'المواصفات', 'الشركة المصنعة'],
    en: ['Post a car ad', 'VEHICLE', 'SPECIFICATIONS', 'Make'],
  );

  // "To"/"From" are omitted deliberately — they appear as substrings of the
  // untranslated make name ("Toyota"), which would make the assertion lie.
  bilingualTest(
    'Make filter screen',
    () => const MakeFilterScreen(makeName: 'Toyota'),
    ar: ['اختر الموديل', 'اختر السنة'],
    en: ['Choose model', 'Choose year'],
  );

  bilingualTest(
    'Register screen',
    () => const RegisterScreen(),
    ar: ['أكمل بياناتك', 'التوثيق عبر', 'الاسم الكامل', 'توثيق ومتابعة'],
    en: ['Complete your details', 'Verify with', 'Full name',
        'Verify and continue'],
  );

  bilingualTest(
    'Add car screen',
    () => const AddCarScreen(),
    ar: [
      'أضف سيارتك',
      'الشركة المصنعة',
      'الموديل',
      'رقم اللوحة العمانية',
      'نوع الوقود / المحرك',
      'كهربائي',
    ],
    en: [
      'Add your car',
      'Make',
      'Model',
      'Oman plate number',
      'Fuel / powertrain',
      'Electric',
    ],
  );

  // The EV parts are new listings, and their spec sheets are the reason an EV
  // owner can buy with confidence — so they get the same bilingual guarantee.
  bilingualTest(
    'Product detail screen — EV charging cable',
    () => const ProductDetailScreen(productId: 'pr7'),
    ar: ['كيبل شحن', 'نوع القابس', 'مخصصة لـ', 'الوصف'],
    en: ['Type 2 charging cable', 'Connector', 'For: Electric', 'Description'],
  );

  // The My Car page with an empty garage: the state a first-run user meets,
  // and the one that must not print English at an Arabic reader.
  bilingualTest(
    'My Car page (no car yet)',
    () => const MaintenanceScreen(),
    ar: ['سيارتي', 'ابدأ دفتر صيانة سيارتك', 'دفتر صيانة', 'أضف سيارة'],
    en: ['My car', 'Start your car\'s maintenance book', 'maintenance book',
        'Add car'],
  );

  bilingualTest(
    'Start choice screen',
    () => const StartChoiceScreen(),
    ar: ['كيف تود أن تبدأ؟', 'أضف سيارتي الآن', 'موصى به', 'ليس الآن'],
    en: ['How would you like to start?', 'Add my car now', 'Recommended',
        'Not now'],
  );
}
