import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_router/go_router.dart';

import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/garage/add_car_screen.dart';
import 'package:ak_cars_mobil_app/features/garage/my_cars_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'helpers/test_harness.dart';

const _camry = Car(
  id: 'c1',
  make: 'Toyota',
  model: 'Camry',
  year: 2021,
  plate: '12345 AB',
  odometerKm: 128450,
  governorate: 'Muscat',
  wilayat: 'Seeb',
);

const _patrol = Car(id: 'c2', make: 'Nissan', model: 'Patrol', year: 2019);

Future<ProviderContainer> pumpGarage(
  WidgetTester tester, {
  String locale = 'en',
  bool dark = false,
  List<Car> garage = const [],
}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = await createTestContainer();
  for (final car in garage) {
    await container.read(garageProvider.notifier).add(car);
  }

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
        home: const MyCarsScreen(),
      ),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

/// Garage + editor behind a real router, so the edit round trip (card →
/// editor → back to the card) is exercised the way the app wires it.
Future<ProviderContainer> pumpGarageWithRouter(
  WidgetTester tester, {
  required List<Car> garage,
  String locale = 'en',
}) async {
  // Tall surface: the car form is a lazy ListView, so a field below the fold
  // is never built for a finder to see. The fields these tests assert on sit
  // past one phone viewport now that the form also asks for the powertrain.
  tester.view.physicalSize = const Size(402 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = await createTestContainer();
  for (final car in garage) {
    await container.read(garageProvider.notifier).add(car);
  }

  final router = GoRouter(
    initialLocation: '/garage',
    routes: [
      GoRoute(
        path: '/garage',
        builder: (context, state) => const MyCarsScreen(),
      ),
      GoRoute(
        path: '/garage/edit/:id',
        builder: (context, state) =>
            AddCarScreen(carId: state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The text field inside the labelled row [label] on the car form.
Finder fieldUnder(String label) => find.descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.byType(TextField),
    );

void main() {
  group('garage state', () {
    test('hydrates from the repository instead of starting empty', () async {
      final container = await createDataContainer();
      // Saved before anything reads the provider — the equivalent of a
      // returning user whose cars already exist on the server.
      await container.read(garageRepositoryProvider).addCar(_camry);

      expect(container.read(garageProvider), [_camry]);
      expect(container.read(primaryCarProvider), _camry);
    });

    test('update replaces the saved car and persists', () async {
      final container = await createDataContainer();
      final garage = container.read(garageProvider.notifier);
      await garage.add(_camry);

      final renamed = _camry.copyWith(nickname: 'Work car', color: 'White');
      await garage.update(renamed);

      expect(container.read(garageProvider).single.nickname, 'Work car');
      expect(container.read(garageProvider).single.color, 'White');
      // …and the write reached the data layer, not just the UI state.
      expect(await container.read(garageRepositoryProvider).fetchCars(),
          [renamed]);
    });

    test('setOdometer records mileage; a junk reading is ignored', () async {
      final container = await createDataContainer();
      final garage = container.read(garageProvider.notifier);
      await garage.add(_patrol);

      await garage.setOdometer(_patrol.id, 64000);
      expect(container.read(garageProvider).single.odometerKm, 64000);

      await garage.setOdometer(_patrol.id, 0);
      expect(container.read(garageProvider).single.odometerKm, 64000);
    });

    test('restore puts a removed car back at its old position', () async {
      final container = await createDataContainer();
      final garage = container.read(garageProvider.notifier);
      await garage.add(_camry);
      await garage.add(_patrol);

      await garage.remove(_patrol.id);
      expect(container.read(garageProvider), [_camry]);

      await garage.restore(_patrol, 1);
      expect(container.read(garageProvider), [_camry, _patrol]);
      expect(await container.read(garageRepositoryProvider).fetchCars(),
          [_camry, _patrol]);
    });

    test('restoring the default car keeps it default', () async {
      final container = await createDataContainer();
      final garage = container.read(garageProvider.notifier);
      await garage.add(_camry);
      await garage.add(_patrol);

      await garage.remove(_camry.id);
      await garage.restore(_camry, 0);

      expect(container.read(primaryCarProvider), _camry);
    });

    test('setPrimary promotes a car for services and the shop', () async {
      final container = await createDataContainer();
      final garage = container.read(garageProvider.notifier);
      await garage.add(_camry);
      await garage.add(_patrol);

      await garage.setPrimary(_patrol.id);
      expect(container.read(primaryCarProvider), _patrol);
      expect(await container.read(garageRepositoryProvider).fetchCars(),
          [_patrol, _camry]);
    });
  });

  group('my cars screen', () {
    testWidgets('empty state invites adding a car, in both languages',
        (tester) async {
      await pumpGarage(tester);
      expect(find.textContaining('No cars in your garage'), findsOneWidget);
      expect(find.textContaining('Add car'), findsOneWidget);

      await pumpGarage(tester, locale: 'ar');
      expect(find.textContaining('لا سيارات في مرآبك'), findsOneWidget);
      expect(find.textContaining('No cars'), findsNothing);
    });

    testWidgets('default car shows its plate, mileage and actions',
        (tester) async {
      await pumpGarage(tester, garage: const [_camry]);

      expect(find.text('Toyota Camry 2021'), findsOneWidget);
      expect(find.text('DEFAULT'), findsOneWidget);
      // Plate is split into number + letters on the mini plate.
      expect(find.text('12345'), findsOneWidget);
      expect(find.text('AB'), findsOneWidget);
      expect(find.textContaining('128,450'), findsOneWidget);
      expect(find.text('Book service'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('a nickname replaces the make/model heading', (tester) async {
      await pumpGarage(tester, garage: [
        _camry.copyWith(nickname: 'Work car'),
      ]);

      expect(find.text('Work car'), findsOneWidget);
      // The full name stays visible underneath, not lost.
      expect(find.textContaining('Toyota Camry 2021'), findsWidgets);
    });

    testWidgets('an incomplete car is nudged to fill in what is missing',
        (tester) async {
      await pumpGarage(tester, garage: const [_patrol]);
      expect(find.textContaining('plate'), findsWidgets);
      expect(find.textContaining('Not recorded yet'), findsOneWidget);

      // A complete car gets no nudge.
      await pumpGarage(tester, garage: const [_camry]);
      expect(find.textContaining('to book services faster'), findsNothing);
    });

    testWidgets('extra cars are listed under their own heading',
        (tester) async {
      await pumpGarage(tester, garage: const [_camry, _patrol]);

      expect(find.text('Other cars'), findsOneWidget);
      expect(find.text('Nissan Patrol 2019'), findsOneWidget);
      expect(find.textContaining('No mileage saved'), findsOneWidget);
    });

    testWidgets('the overflow menu promotes another car to default',
        (tester) async {
      final container =
          await pumpGarage(tester, garage: const [_camry, _patrol]);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make default'));
      await tester.pumpAndSettle();

      expect(container.read(primaryCarProvider), _patrol);
    });

    testWidgets('updating mileage from the card saves it', (tester) async {
      final container = await pumpGarage(tester, garage: const [_patrol]);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '64000');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(container.read(garageProvider).single.odometerKm, 64000);
      // The reading feeds *that car's* maintenance book too, so the garage
      // card and the maintenance page cannot disagree about the same car's
      // mileage.
      expect(
          container.read(maintenanceBookProvider(_patrol.id)).currentOdometerKm,
          64000);
    });

    testWidgets('swiping a car away removes it and offers an undo',
        (tester) async {
      final container =
          await pumpGarage(tester, garage: const [_camry, _patrol]);

      await tester.drag(
          find.text('Nissan Patrol 2019'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(container.read(garageProvider), [_camry]);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(container.read(garageProvider), [_camry, _patrol]);
    });

    testWidgets('renders in the dark "Ink" theme', (tester) async {
      await pumpGarage(tester, dark: true, garage: const [_camry, _patrol]);
      expect(find.text('Toyota Camry 2021'), findsOneWidget);
      expect(find.text('Nissan Patrol 2019'), findsOneWidget);
    });

    testWidgets('renders in Arabic (RTL) without English leaking through',
        (tester) async {
      await pumpGarage(tester,
          locale: 'ar',
          garage: [_camry.copyWith(nickname: 'سيارة العمل'), _patrol]);

      expect(find.text('سيارة العمل'), findsOneWidget);
      expect(find.textContaining('سيارات أخرى'), findsOneWidget);
      expect(find.text('احجز خدمة'), findsOneWidget);
      expect(find.text('DEFAULT'), findsNothing);
      expect(find.text('Book service'), findsNothing);
      expect(find.textContaining('Other cars'), findsNothing);
    });
  });

  group('editing a saved car', () {
    testWidgets('the editor opens prefilled with the saved details',
        (tester) async {
      await pumpGarageWithRouter(tester, garage: const [_camry]);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit car'), findsOneWidget);
      expect(find.text('Toyota'), findsOneWidget);
      expect(find.text('Camry'), findsOneWidget);
      expect(find.text('2021'), findsOneWidget);
      // Plate is split back into its number and letters.
      expect(tester.widget<TextField>(fieldUnder('Current mileage (km)')).controller?.text,
          '128450');
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('saving an edit updates the car and returns to the garage',
        (tester) async {
      final container =
          await pumpGarageWithRouter(tester, garage: const [_camry]);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldUnder('Nickname'), 'Work car');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = container.read(garageProvider).single;
      expect(saved.nickname, 'Work car');
      // Editing one field must not wipe the others.
      expect(saved.plate, '12345 AB');
      expect(saved.odometerKm, 128450);
      expect(saved.id, _camry.id, reason: 'an edit must not create a new car');
      // Back on the garage, showing the new name.
      expect(find.text('Work car'), findsOneWidget);
    });

    testWidgets('clearing the mileage field clears it on the car',
        (tester) async {
      final container =
          await pumpGarageWithRouter(tester, garage: const [_camry]);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldUnder('Current mileage (km)'), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(container.read(garageProvider).single.odometerKm, isNull);
    });

    testWidgets('deleting from the editor removes the car and goes back',
        (tester) async {
      final container =
          await pumpGarageWithRouter(tester, garage: const [_camry]);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(container.read(garageProvider), isEmpty);
      expect(find.textContaining('No cars in your garage'), findsOneWidget);
    });
  });
}
