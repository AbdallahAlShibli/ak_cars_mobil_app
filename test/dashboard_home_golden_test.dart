import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/features/workshop_dashboard/dashboard_home_screen.dart';

import 'helpers/test_harness.dart';

/// Pixel golden coverage for the dashboard home screen — new to this repo
/// (no `matchesGoldenFile` reference images existed anywhere in it before
/// this file). `workshop_dashboard_test.dart`'s RTL/LTR "smoke" tests only
/// assert the screen builds and the right strings appear; these assert the
/// actual rendered pixels do not drift, in both directions and both themes.
///
/// The reference PNGs under `test/goldens/` were generated on this machine
/// with `flutter test --update-goldens`. A golden test is only as portable
/// as the font rendering underneath it — this repo has no prior golden
/// baseline to match conventions against, so these intentionally do not load
/// real app fonts (`loadAppFonts()`/golden_toolkit is not a dependency here);
/// Flutter's default test font substitution is deterministic across runs on
/// the same engine version, which is enough to catch a broken layout without
/// pulling in a new package for it. A real font mismatch across machines
/// would show up as every pixel differing, not a few — regenerate with
/// `--update-goldens` if that happens on a different machine/CI image than
/// this baseline was captured on.
void main() {
  // `AppTheme` pulls its Arabic/English text themes from `google_fonts`,
  // which by default fetches the actual font files over the network on
  // first use and caches them — fine for the running app, but it makes a
  // golden test's pixels depend on network reachability and an unversioned
  // remote file, and this repo bundles no local `.ttf` fallback for
  // `allowRuntimeFetching = false` to fall back to. `debugDisableGoogleFonts`
  // skips both `GoogleFonts.*` call sites in `AppTheme` entirely, so every
  // run (including CI, with no network at all) renders with Flutter's
  // built-in test font instead: slower to eyeball, but the same on every
  // machine, which is the one property a golden test actually needs.
  setUpAll(() => AppTheme.debugDisableGoogleFonts = true);
  tearDownAll(() => AppTheme.debugDisableGoogleFonts = false);

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required String locale,
    required bool dark,
  }) async {
    final container = await createTestContainer();
    tester.view.physicalSize = const Size(402 * 3, 1400 * 3);
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
          home: const DashboardHomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Dashboard home — Arabic RTL, light', (tester) async {
    await pumpDashboard(tester, locale: 'ar', dark: false);
    await expectLater(
      find.byType(DashboardHomeScreen),
      matchesGoldenFile('goldens/dashboard_home_ar_light.png'),
    );
  });

  testWidgets('Dashboard home — English LTR, light', (tester) async {
    await pumpDashboard(tester, locale: 'en', dark: false);
    await expectLater(
      find.byType(DashboardHomeScreen),
      matchesGoldenFile('goldens/dashboard_home_en_light.png'),
    );
  });

  testWidgets('Dashboard home — Arabic RTL, dark', (tester) async {
    await pumpDashboard(tester, locale: 'ar', dark: true);
    await expectLater(
      find.byType(DashboardHomeScreen),
      matchesGoldenFile('goldens/dashboard_home_ar_dark.png'),
    );
  });
}
