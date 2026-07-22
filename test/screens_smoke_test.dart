import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/features/challenge/challenge_screen.dart';
import 'package:ak_cars_mobil_app/features/cars/cars_screen.dart';
import 'package:ak_cars_mobil_app/features/garage/maintenance_screen.dart';
import 'package:ak_cars_mobil_app/features/cars/cars_filter_screen.dart';
import 'package:ak_cars_mobil_app/features/home/home_screen.dart';
import 'package:ak_cars_mobil_app/features/profile/profile_screen.dart';
import 'package:ak_cars_mobil_app/features/settings/settings_screen.dart';
import 'package:ak_cars_mobil_app/features/shop/shop_screen.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';

import 'helpers/test_harness.dart';

/// Pumps a screen inside the real theme + localization stack. Any layout
/// overflow or build exception fails the test.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  String locale = 'ar',
  bool dark = false,
}) async {
  final container = await createTestContainer();
  // Phone-sized surface like the design frames (402×874 logical).
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
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
}

void main() {
  testWidgets('Home renders in Arabic RTL (light)', (tester) async {
    await pumpScreen(tester, const HomeScreen());
    expect(find.text('أهلاً بك!'), findsOneWidget);
    expect(find.textContaining('متابعة الصيانة'), findsOneWidget);
    expect(find.text('مساعدة طريق'), findsOneWidget);
    expect(find.text('الأكثر بحثاً'), findsOneWidget);
  });

  testWidgets('Home renders in English LTR', (tester) async {
    await pumpScreen(tester, const HomeScreen(), locale: 'en');
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.textContaining('Maintenance'), findsWidgets);
    expect(find.text('Roadside'), findsOneWidget);
  });

  testWidgets('Home renders in dark "Ink" theme', (tester) async {
    await pumpScreen(tester, const HomeScreen(), dark: true);
    expect(find.text('أهلاً بك!'), findsOneWidget);
  });

  testWidgets('Maintenance screen computes due items from entered data',
      (tester) async {
    await pumpScreen(tester, const MaintenanceScreen());
    expect(find.text('متابعة الصيانة'), findsOneWidget);
    expect(find.text('زيت المحرك + الفلتر'), findsOneWidget);
    // 128,450 − 123,000 = 5,450 consumed of 7,000 ⇒ 1,550 remaining.
    expect(find.textContaining('1,550'), findsWidgets);
    // Coolant has no record ⇒ no percentage, manual-record CTA instead.
    expect(find.text('لا يوجد سجل'), findsOneWidget);
    expect(find.text('أضف سجلاً يدوياً'), findsOneWidget);
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

  testWidgets('Parts shop is translated to Arabic', (tester) async {
    await pumpScreen(tester, const ShopScreen(), locale: 'ar');
    expect(find.text('متجر القطع'), findsOneWidget);
    expect(find.text('الأكثر مبيعاً'), findsOneWidget);
  });
}
