import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/vehicle_catalog.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/garage/add_car_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/mock_catalog_service.dart';
import 'helpers/test_harness.dart';

/// The catalogue answers with no makes at start-up (a stale stored answer, a
/// start-up with no connection), then with the real list.
class _EmptyFirstCatalogService extends MockCatalogService {
  var calls = 0;
  bool failAfterFirst = false;

  @override
  Future<VehicleCatalog> fetchVehicleCatalog() async {
    calls++;
    if (calls == 1) return VehicleCatalog.empty;
    if (failAfterFirst) throw const NetworkException('offline');
    return super.fetchVehicleCatalog();
  }
}

/// "Add your car" opened its make picker onto an empty sheet when the
/// start-up catalogue load had come back empty (2026-09-18).
void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    _EmptyFirstCatalogService catalog,
  ) async {
    tester.view.physicalSize = const Size(402 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = await createTestContainer(
      overrides: [catalogServiceProvider.overrideWithValue(catalog)],
    );
    // Read once, as the app's screens do before start-up finishes.
    expect(container.read(vehicleCatalogProvider).makes, isEmpty);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AddCarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('an empty catalogue is fetched again when the picker opens', (
    tester,
  ) async {
    final catalog = _EmptyFirstCatalogService();
    await pump(tester, catalog);

    await tester.tap(find.text('Make'));
    await tester.pumpAndSettle();

    expect(catalog.calls, 2);
    expect(find.text('Pick a make'), findsOneWidget);
    expect(find.text('Toyota'), findsOneWidget);
  });

  testWidgets('if that fetch fails too, it says so instead of opening blank', (
    tester,
  ) async {
    final catalog = _EmptyFirstCatalogService()..failAfterFirst = true;
    await pump(tester, catalog);

    await tester.tap(find.text('Make'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a make'), findsNothing);
    expect(
      find.textContaining("Couldn't load the list of makes"),
      findsOneWidget,
    );
  });

  testWidgets('a search with no match says so', (tester) async {
    await pump(tester, _EmptyFirstCatalogService());

    await tester.tap(find.text('Make'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('No make matches that'), findsOneWidget);
  });
}
