import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/features/challenge/challenge_screen.dart';
import 'package:ak_cars_mobil_app/features/cars/cars_screen.dart';
import 'package:ak_cars_mobil_app/features/garage/maintenance_screen.dart';
import 'package:ak_cars_mobil_app/features/cars/cars_filter_screen.dart';
import 'package:ak_cars_mobil_app/features/home/home_screen.dart';
import 'package:ak_cars_mobil_app/features/profile/profile_screen.dart';
import 'package:ak_cars_mobil_app/features/settings/settings_screen.dart';
import 'package:ak_cars_mobil_app/features/search/search_screen.dart';
import 'package:ak_cars_mobil_app/features/services/service_detail_screen.dart';
import 'package:ak_cars_mobil_app/features/shop/product_detail_screen.dart';
import 'package:ak_cars_mobil_app/features/shop/shop_screen.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'helpers/test_harness.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_ids.dart';

/// Pumps a screen inside the real theme + localization stack. Any layout
/// overflow or build exception fails the test.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  String locale = 'ar',
  bool dark = false,
  List<Car> garage = const [],
  double height = 874,
}) async {
  final container = await createTestContainer();
  for (final car in garage) {
    await container.read(garageProvider.notifier).add(car);
  }
  // Phone-sized surface like the design frames (402×874 logical). A taller one
  // is passed for long scrolling pages: a `ListView` does not build a child
  // that is off-screen, so a section below the fold cannot be found at all.
  tester.view.physicalSize = Size(402 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
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
  await tester.pump(const Duration(milliseconds: 500));
  return container;
}

void main() {
  testWidgets('Home renders in Arabic RTL (light)', (tester) async {
    await pumpScreen(tester, const HomeScreen(), height: 2400);
    expect(find.text('أهلاً بك!'), findsOneWidget);
    expect(find.text('مساعدة طريق'), findsOneWidget);
    // The three sections the home-page spec fixes, plus the supporting ones.
    // With an empty garage section 1 is the invitation, so it keeps the
    // "سياراتي" heading rather than claiming to show a status.
    expect(find.text('سياراتي'), findsOneWidget);
    expect(find.text('عروض هذا الأسبوع'), findsOneWidget);
    expect(find.text('ورش موثوقة'), findsOneWidget);
    expect(find.text('الأكثر حجزاً'), findsOneWidget);
    expect(find.text('من AK Cars'), findsOneWidget);
    // With an empty garage the car list is one invitation, not a stand-in car,
    // and there is nothing to recommend for.
    expect(find.text('سجّل سيارتك'), findsOneWidget);
    expect(find.text('مقترح لسيارتك'), findsNothing);
    // "أحدث الإعلانات" was asserted here until the phase-1 refocus: the ads
    // rail belongs to the cars marketplace, which is now behind
    // AppFlags.carMarketplaceEnabled and absent from this build.
    expect(find.text('أحدث الإعلانات'), findsNothing);
  });

  testWidgets('Home renders in English LTR', (tester) async {
    await pumpScreen(tester, const HomeScreen(), locale: 'en', height: 2400);
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Roadside'), findsOneWidget);
    expect(find.text('My cars'), findsOneWidget);
    expect(find.text("This week's offers"), findsOneWidget);
    expect(find.text('Trusted workshops'), findsOneWidget);
    expect(find.text('Most booked'), findsOneWidget);
  });

  testWidgets('Home runs car status → offers → workshops, in that order',
      (tester) async {
    // The order the home-page handoff fixes (§1). Asserted by position rather
    // than by presence, because "the three sections exist somewhere on the
    // page" is not what the spec asks for — the sequence is the point:
    // حاجة → فرصة → طمأنة.
    await pumpScreen(
      tester,
      const HomeScreen(),
      locale: 'en',
      height: 2600,
      garage: const [
        Car(
          id: 'c9',
          make: 'Toyota',
          model: 'Camry',
          year: 2021,
          odometerKm: 128450,
          governorate: 'Muscat',
          powertrain: Powertrain.petrol,
        ),
      ],
    );

    double y(String heading) => tester.getTopLeft(find.text(heading)).dy;

    expect(y('My car status'), lessThan(y("This week's offers")));
    expect(y("This week's offers"), lessThan(y('Trusted workshops')));
    // The supporting rails sit below all three.
    expect(y('Trusted workshops'), lessThan(y('Suggested for your car')));
  });

  testWidgets('Home offer cards show the discount, the old price and the '
      'deadline', (tester) async {
    await pumpScreen(tester, const HomeScreen(), locale: 'en', height: 2600);

    // Qurum publishes 6 for tyre fitting and is running a validated offer at
    // 4.5 — a 25% saving with an end date. The card carries all four numbers,
    // and the discounted price keeps its half rial rather than rounding up to
    // a price nobody charges.
    expect(find.text('25% off'), findsWidgets);
    expect(find.textContaining('4.5', findRichText: true), findsWidgets);
    expect(find.text('6 OMR'), findsWidgets);
    expect(find.textContaining('ends in'), findsWidgets);
    // …and the section says what it is showing, without claiming more.
    expect(
      find.textContaining('Real discounts from approved workshops'),
      findsOneWidget,
    );
  });

  testWidgets('Home says "overdue" in the alert colour, and still books',
      (tester) async {
    const camry = Car(
      id: 'c9',
      make: 'Toyota',
      model: 'Camry',
      year: 2021,
      odometerKm: 128450,
      governorate: 'Muscat',
      powertrain: Powertrain.petrol,
    );
    final container = await pumpScreen(
      tester,
      const HomeScreen(),
      locale: 'en',
      height: 2600,
      garage: const [camry],
    );

    // An oil change logged 40,000 km and two years ago is well past both of
    // its intervals — the state §1 asks for by name.
    await container.read(maintenanceProvider.notifier).addRecord(
          camry.id,
          ServiceRecord(
            id: 'r1',
            title: const L('زيت', 'Oil'),
            workshop: 'Al Noor',
            odometerKm: 88000,
            date: DateTime.now().subtract(const Duration(days: 730)),
            itemKey: MaintenanceType.oil.key,
          ),
        );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Overdue — book now'), findsOneWidget);
    expect(find.text('Book now'), findsNothing);
  });

  testWidgets('Home shows a registered car with its own details',
      (tester) async {
    await pumpScreen(
      tester,
      const HomeScreen(),
      locale: 'en',
      height: 2400,
      garage: const [
        Car(
          id: 'c9',
          make: 'Toyota',
          model: 'Land Cruiser',
          year: 2020,
          plate: '5566 AA',
          odometerKm: 88000,
          governorate: 'Muscat',
          powertrain: Powertrain.petrol,
        ),
      ],
    );

    expect(find.text('Toyota Land Cruiser 2020'), findsOneWidget);
    expect(find.text('Default car'), findsOneWidget);
    // Details the owner entered, and nothing they did not.
    expect(find.text('5566 AA'), findsOneWidget);
    expect(find.text('88,000 km'), findsOneWidget);
    expect(find.text('Petrol'), findsOneWidget);
    // Section 1's heading, once there is a car to have a status.
    expect(find.text('My car status'), findsOneWidget);
    // A car with no logged service shows no countdown. It asks for the one
    // fact that would start one, naming the service rather than asking for
    // "your service history" in the abstract, and offers the button that opens
    // the record sheet.
    expect(
      find.textContaining('When did you last do engine oil'),
      findsOneWidget,
    );
    expect(find.text('Add last engine oil'), findsOneWidget);
    // Every reminder is also a booking button (spec §1).
    expect(find.text('Book now'), findsWidgets);
    // Now there is a car, so there is something to suggest for it.
    expect(find.text('Suggested for your car'), findsOneWidget);
  });

  testWidgets('Home renders in dark "Ink" theme', (tester) async {
    // With a car, so the picture, the meta chips and the countdown strip are
    // all exercised in dark too — any overflow fails this test.
    await pumpScreen(
      tester,
      const HomeScreen(),
      dark: true,
      height: 2400,
      garage: const [
        Car(
          id: 'c9',
          make: 'Nissan',
          model: 'Patrol',
          year: 2019,
          plate: '7788 CD',
          odometerKm: 45000,
          governorate: 'Dhofar',
        ),
      ],
    );
    expect(find.text('أهلاً بك!'), findsOneWidget);
    expect(find.text('Nissan Patrol 2019'), findsOneWidget);
    expect(find.text('حالة سيارتي'), findsOneWidget);
    expect(find.text('ورش موثوقة'), findsOneWidget);
  });

  testWidgets('Maintenance screen asks for a car before it shows a schedule',
      (tester) async {
    await pumpScreen(tester, const MaintenanceScreen());
    // The tab is titled "سيارتي" since the four-tab refocus.
    expect(find.text('سيارتي'), findsOneWidget);
    // Nothing to follow up with an empty garage, and nothing invented to
    // illustrate the page with.
    expect(find.text('ابدأ دفتر صيانة سيارتك'), findsOneWidget);
    expect(find.text('زيت المحرك + الفلتر'), findsNothing);
  });

  testWidgets('Challenge screen shows steps, streak and stats',
      (tester) async {
    await pumpScreen(tester, const ChallengeScreen());
    expect(find.text('تحدي الأسبوع'), findsOneWidget);
    expect(find.text('افحص ضغط الإطارات الأربعة'), findsOneWidget);
    expect(find.text('3 أسابيع متتالية'), findsOneWidget);
    expect(find.text('2,450'), findsOneWidget);
    expect(find.text('أكمل التحدي'), findsOneWidget);
  });

  testWidgets('Settings screen shows language + theme controls',
      (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('كريمي — الافتراضي'), findsOneWidget);
    expect(find.text('داكن'), findsOneWidget);
    expect(find.text('تلقائي حسب النظام'), findsOneWidget);
  });

  testWidgets('Cars market renders categories, makes and ads grid',
      (tester) async {
    await pumpScreen(tester, const CarsScreen());
    expect(find.text('سوق السيارات'), findsOneWidget);
    expect(find.text('أضف إعلانك'), findsOneWidget);
    expect(find.text('الكل'), findsOneWidget);
    expect(find.text('دفع رباعي'), findsOneWidget);
    expect(find.text('المزيد'), findsOneWidget);
  });

  testWidgets('Cars market renders in dark "Ink" theme', (tester) async {
    await pumpScreen(tester, const CarsScreen(), dark: true);
    expect(find.text('سوق السيارات'), findsOneWidget);
  });

  testWidgets('Parts shop renders in Arabic light + dark', (tester) async {
    await pumpScreen(tester, const ShopScreen(), locale: 'en');
    expect(find.text('Parts shop'), findsOneWidget);
    await pumpScreen(tester, const ShopScreen(), locale: 'en', dark: true);
    expect(find.text('Parts shop'), findsOneWidget);
  });

  // The shop block is what a buyer checks before paying a stranger, so both
  // its states are pinned: a VAT-registered seller prints its Oman VATIN, and
  // one that is not registered says so instead of showing an empty field.
  testWidgets('Product page prints the seller VAT number', (tester) async {
    // pr1 → Al Noor Workshop, VAT registered.
    await pumpScreen(tester, const ProductDetailScreen(productId: mockIdPr1),
        locale: 'en');
    await tester.scrollUntilVisible(find.text('Shop details'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('OM1100047382'), findsOneWidget);
    expect(find.textContaining('VAT invoice'), findsOneWidget);
  });

  testWidgets('Product page says when the seller is not VAT registered',
      (tester) async {
    // pr5 → Sohar Speed Garage, no VATIN in the demo data.
    await pumpScreen(tester, const ProductDetailScreen(productId: mockIdPr5),
        locale: 'en');
    await tester.scrollUntilVisible(find.text('Shop details'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Not VAT registered'), findsOneWidget);
    expect(find.textContaining('VAT invoice'), findsNothing);
  });

  // Same two states on the service side, where the card is shared code.
  testWidgets('Service page prints the workshop VAT number', (tester) async {
    // Al Noor Workshop's express service, VAT registered.
    await pumpScreen(tester, ServiceDetailScreen(offeringId: mockOfferingId(mockIdP1, mockIdExpress)),
        locale: 'en');
    await tester.scrollUntilVisible(find.text('Workshop details'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('OM1100047382'), findsOneWidget);
  });

  testWidgets('Service page says when the workshop is not VAT registered',
      (tester) async {
    // Sohar Speed Garage's express service, no VATIN in the demo data.
    await pumpScreen(tester, ServiceDetailScreen(offeringId: mockOfferingId(mockIdP3, mockIdExpress)),
        locale: 'en');
    await tester.scrollUntilVisible(find.text('Workshop details'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Not VAT registered'), findsOneWidget);
  });

  testWidgets('Profile hub renders in dark "Ink" theme (English)',
      (tester) async {
    await pumpScreen(tester, const ProfileScreen(), locale: 'en', dark: true);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('My cars'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
  });

  testWidgets('Profile hub is translated to Arabic', (tester) async {
    await pumpScreen(tester, const ProfileScreen(), locale: 'ar');
    expect(find.text('حسابي'), findsWidgets);
    expect(find.text('سياراتي'), findsOneWidget);
    expect(find.text('المدفوعات'), findsOneWidget);
    expect(find.text('الدعم'), findsOneWidget);
  });

  testWidgets('Cars filter: accordion sections + Make/Model + live count',
      (tester) async {
    await pumpScreen(
      tester,
      const CarsFilterScreen(initial: CarsFilter()),
      locale: 'en',
    );
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Clear Filters'), findsOneWidget);
    // Accordion section headers (sooq-cars parity).
    expect(find.text('Make and Model'), findsOneWidget);
    expect(find.text('Sub-Model'), findsOneWidget);
    expect(find.text('Fuel Type'), findsOneWidget);
    expect(find.text('Cylinders'), findsOneWidget);
    // Make and Model section opens first ⇒ its Select Car button shows.
    expect(find.text('Select Car'), findsOneWidget);
    // Apply bar previews the live result count (whole feed = 12).
    expect(find.text('Show 12 results'), findsOneWidget);
    // City lives near the end of the lazy accordion list — scroll to it.
    await tester.scrollUntilVisible(find.text('City'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('City'), findsOneWidget);
  });

  testWidgets('Cars filter: expanding a section and picking narrows count',
      (tester) async {
    await pumpScreen(
      tester,
      const CarsFilterScreen(initial: CarsFilter()),
      locale: 'en',
    );
    // Expand Body Type, pick SUV ⇒ 3 SUVs in the seed feed.
    await tester.tap(find.text('Body Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SUV'));
    await tester.pump();
    expect(find.text('Show 3 results'), findsOneWidget);
  });

  testWidgets('Cars filter: Select Car opens the make brand grid',
      (tester) async {
    await pumpScreen(
      tester,
      const CarsFilterScreen(initial: CarsFilter()),
      locale: 'en',
    );
    await tester.tap(find.text('Select Car'));
    await tester.pumpAndSettle();
    expect(find.text('Select make'), findsOneWidget);
    expect(find.text('Toyota'), findsWidgets);
    expect(find.text('Nissan'), findsWidgets);
  });

  testWidgets('Cars filter is usable in dark mode', (tester) async {
    await pumpScreen(
      tester,
      const CarsFilterScreen(initial: CarsFilter(bodyTypes: {'SUV'})),
      locale: 'en',
      dark: true,
    );
    expect(find.text('Filters'), findsOneWidget);
    // SUV pre-selected ⇒ 3 SUVs in the seed feed (Armada, 2 Patrols).
    expect(find.text('Show 3 results'), findsOneWidget);
  });

  testWidgets('Cars filter Price section uses Min/Max input fields',
      (tester) async {
    await pumpScreen(
      tester,
      const CarsFilterScreen(initial: CarsFilter()),
      locale: 'en',
    );
    await tester.scrollUntilVisible(find.text('Price Range'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Price Range'));
    await tester.pumpAndSettle();
    // Two OMR text fields, not a slider.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Min'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);
  });

  testWidgets('Cars filter Sub-Model lists model-prefixed trims',
      (tester) async {
    await pumpScreen(
      tester,
      const CarsFilterScreen(
          initial: CarsFilter(make: 'Toyota', model: 'Camry')),
      locale: 'en',
    );
    await tester.tap(find.text('Sub-Model'));
    await tester.pumpAndSettle();
    expect(find.text('Camry LE'), findsOneWidget);
    expect(find.text('Camry XSE'), findsOneWidget);
  });

  testWidgets('Cars filter offers the whole spec catalog, not just the '
      'values present in the feed', (tester) async {
    await pumpScreen(
      tester,
      const CarsFilterScreen(initial: CarsFilter()),
      locale: 'en',
    );
    await tester.scrollUntilVisible(find.text('Fuel Type'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Fuel Type'));
    await tester.pumpAndSettle();
    // All five fuels, including ones nobody is currently selling.
    for (final fuel in [
      'Petrol',
      'Diesel',
      'Hybrid',
      'Plug-in Hybrid',
      'Electric',
    ]) {
      expect(find.text(fuel), findsOneWidget, reason: '$fuel option missing');
    }

    await tester.scrollUntilVisible(find.text('Transmission'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Transmission'));
    await tester.pumpAndSettle();
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('CVT'), findsOneWidget);
    expect(find.text('Dual-clutch (DCT)'), findsOneWidget);
  });

  // "الأكثر مبيعاً" / "Best sellers" was asserted here until 2026-07-25. The
  // rail sorts by rating and nothing in the catalogue records sales, so it is
  // now titled "الأعلى تقييماً" / "Top rated" — what it actually shows.
  testWidgets('Parts shop is translated to Arabic', (tester) async {
    await pumpScreen(tester, const ShopScreen(), locale: 'ar');
    expect(find.text('متجر القطع'), findsOneWidget);
    expect(find.text('الأعلى تقييماً'), findsWidgets);
  });

  // The home pill carried a "search services, parts, cars" hint but only
  // navigated to /services. These pin the search it now actually runs.
  // Parts and car ads are excluded from search while their pillars are behind
  // a flag — see searchResultsProvider. These assertions moved with them: the
  // query still runs, it just has one catalogue to search.
  testWidgets('Search returns no parts or cars while those pillars are hidden',
      (tester) async {
    await pumpScreen(tester, const SearchScreen(), locale: 'en');
    await tester.enterText(find.byType(TextField).first, 'denso');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Parts ·'), findsNothing);
    expect(find.textContaining('Nothing found'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'camry 2017');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Cars ·'), findsNothing);
  });

  testWidgets('Search spans the service catalogue', (tester) async {
    await pumpScreen(tester, const SearchScreen(), locale: 'en');
    await tester.enterText(find.byType(TextField).first, 'battery');
    await tester.pump(const Duration(milliseconds: 300));
    // Five services mention a battery — the EV health check, the high-voltage
    // diagnostic, the charging check, the roadside boost and battery
    // replacement.
    Finder row(String label) => find.text(label, skipOffstage: false);
    expect(row('Services · 5'), findsOneWidget);
    expect(row('High-voltage battery diagnostic'), findsOneWidget);

    // Sections show three rows and offer the rest behind "Show all".
    await tester.tap(find.text('Show all (5)'));
    await tester.pump();
    expect(row('Battery replacement'), findsOneWidget);
    expect(row('Roadside assistance'), findsOneWidget);
  });

  testWidgets('Search matches an Arabic place name', (tester) async {
    // Regions are stored as English keys ("Bawshar, Muscat"), so an Arabic
    // search only works if the localized name is matched too.
    await pumpScreen(tester, const SearchScreen(), locale: 'ar');
    await tester.enterText(find.byType(TextField).first, 'مسقط');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('الخدمات'), findsWidgets);
  });

  testWidgets('Search says so when nothing matches', (tester) async {
    await pumpScreen(tester, const SearchScreen(), locale: 'en');
    await tester.enterText(find.byType(TextField).first, 'zzzznotathing');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Nothing found'), findsOneWidget);
  });

  // The banner used to advertise a fixed "Up to 15% off batteries" that no
  // product had to honour, and showed one thing at a time. The carousel now
  // pages through every real discount, deepest first: the LED kit at 9.50
  // down from 12.00 is 21%, then the cabin filter at 20%, then the battery.
  testWidgets('Parts shop offers slider pages through the real discounts',
      (tester) async {
    await pumpScreen(tester, const ShopScreen(), locale: 'en');
    expect(find.textContaining('Up to 15% off'), findsNothing);
    expect(find.text('-21%'), findsWidgets);
    expect(find.text('LED headlight kit'), findsWidgets);

    // Swiping reaches the next offer — the point of making it a slider.
    await tester.drag(find.byType(PageView).first, const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Cabin air filter'), findsWidgets);
    expect(find.text('-20%'), findsWidgets);
  });

  testWidgets('Parts shop searches by part number and brand', (tester) async {
    await pumpScreen(tester, const ShopScreen(), locale: 'en');
    // pr1 is the only Denso part, and 90915-YZZE1 is its part number typed
    // without the hyphen — both must find it and nothing else.
    await tester.enterText(find.byType(TextField).first, '90915 yzze1');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Genuine oil filter'), findsOneWidget);
    expect(find.text('Battery 70Ah AGM'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'denso');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Genuine oil filter'), findsOneWidget);
  });
}
