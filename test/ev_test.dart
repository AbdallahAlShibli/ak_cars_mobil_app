import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/data/services/challenge_service.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/garage/add_car_screen.dart';
import 'package:ak_cars_mobil_app/features/garage/maintenance_screen.dart';
import 'package:ak_cars_mobil_app/features/garage/my_cars_screen.dart';
import 'package:ak_cars_mobil_app/features/home/home_screen.dart';
import 'package:ak_cars_mobil_app/features/services/services_screen.dart';
import 'package:ak_cars_mobil_app/features/shop/product_detail_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'helpers/test_harness.dart';
import 'fakes/data/mock_ids.dart';

/// AK Cars serves petrol, diesel, hybrid and electric owners. These tests pin
/// the behaviour that makes an EV owner a first-class user rather than a petrol
/// user with the wrong reminders: the powertrain is saved and shown, the
/// maintenance list follows it, EV services and parts exist and are findable,
/// and the weekly challenge is one they can actually do.
///
/// They also pin the honesty rules. The app reads nothing from the car, so an
/// EV's battery health may never appear as a live number.

const _tesla = Car(
  id: 'ev1',
  make: 'Tesla',
  model: 'Model Y',
  year: 2024,
  plate: '4477 EV',
  odometerKm: 21000,
  governorate: 'Muscat',
  wilayat: 'Seeb',
  powertrain: Powertrain.electric,
);

const _camry = Car(
  id: 'c1',
  make: 'Toyota',
  model: 'Camry',
  year: 2021,
  plate: '12345 AB',
  odometerKm: 128450,
  governorate: 'Muscat',
  wilayat: 'Seeb',
  powertrain: Powertrain.petrol,
);

/// A car whose owner never said what it runs on — the pre-existing case that
/// must keep behaving exactly as it did before the field existed.
const _unstated = Car(id: 'u1', make: 'Nissan', model: 'Patrol', year: 2019);

Future<ProviderContainer> containerWith(List<Car> garage) async {
  final container = await createTestContainer();
  for (final car in garage) {
    await container.read(garageProvider.notifier).add(car);
  }
  return container;
}

Future<void> settle(WidgetTester tester) async {
  // Entrance() and the services skeleton use Future.delayed, which schedules
  // no frame — pump real time past all of them.
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  String locale = 'en',
  double height = 1600,
}) async {
  tester.view.physicalSize = Size(402 * 3, height * 3);
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
  await settle(tester);
}

void main() {
  // ------------------------------------------------------------------ garage
  group('garage identity', () {
    test('an electric car keeps its powertrain through the data layer',
        () async {
      final container = await containerWith(const [_tesla]);

      expect(container.read(primaryCarProvider), _tesla);
      expect(container.read(primaryPowertrainProvider), Powertrain.electric);
      expect(container.read(isElectricCarProvider), isTrue);
      // …and the write reached the repository, not just the UI state.
      final saved = await container.read(garageRepositoryProvider).fetchCars();
      expect(saved.single.powertrain, Powertrain.electric);
    });

    test('make, model and year stay the only required fields', () {
      // Registering a car must stay a 30-second job: the powertrain is
      // optional, and its absence must not make a car look incomplete.
      const bare = Car(id: 'x', make: 'Kia', model: 'EV6', year: 2023);
      expect(bare.powertrain, isNull);
      expect(bare.isElectric, isFalse);
      expect(bare.plugsIn, isFalse);
      expect(
        _camry.copyWith(plate: null).hasFullDetails,
        _camry.hasFullDetails,
        reason: 'powertrain is not part of the "complete your details" nudge',
      );
    });

    testWidgets('the garage card says Electric, in both languages',
        (tester) async {
      await pump(tester, await containerWith(const [_tesla]), const MyCarsScreen());
      expect(find.text('Electric'), findsWidgets);

      await pump(tester, await containerWith(const [_tesla]), const MyCarsScreen(),
          locale: 'ar');
      expect(find.text('كهربائي'), findsWidgets);
      expect(find.text('Electric'), findsNothing);
    });

    testWidgets('a car with no recorded powertrain gets no badge',
        (tester) async {
      await pump(
          tester, await containerWith(const [_unstated]), const MyCarsScreen());
      expect(find.text('Electric'), findsNothing);
      expect(find.text('Petrol'), findsNothing);
    });

    testWidgets('the editor records the powertrain in one tap', (tester) async {
      final container = await containerWith(const [_unstated]);
      tester.view.physicalSize = const Size(402 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // Behind a real router with the garage underneath, because saving pops
      // back to it — the same wiring the app uses.
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
            locale: const Locale('en'),
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
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Fuel / powertrain'), findsOneWidget);
      await tester.tap(find.text('Electric'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = container.read(garageProvider).single;
      expect(saved.powertrain, Powertrain.electric);
      // Recording it must not disturb anything else on the car.
      expect(saved.id, _unstated.id);
      expect(saved.make, 'Nissan');
      expect(saved.year, 2019);
    });
  });

  // ------------------------------------------------------------- maintenance
  group('maintenance follows the powertrain', () {
    test('an electric car is never reminded about engine oil', () async {
      final container = await containerWith(const [_tesla]);
      final due = container.read(maintenanceDueProvider);
      final types = due.map((d) => d.type).toSet();

      expect(types, isNot(contains(MaintenanceType.oil)));
      expect(
        types,
        containsAll(const [
          MaintenanceType.tyres,
          MaintenanceType.coolant,
          MaintenanceType.cabinFilter,
          MaintenanceType.brakeFluid,
          MaintenanceType.battery12v,
          MaintenanceType.evBattery,
        ]),
      );
    });

    test('a petrol car sees exactly what it always saw', () async {
      final container = await containerWith(const [_camry]);
      final maintenance = container.read(maintenanceProvider.notifier);
      await container.read(garageProvider.notifier).setOdometer(_camry.id, 128450);
      await maintenance.addRecord(
        _camry.id,
        ServiceRecord(
          id: 'r-oil-1',
          title: const L('تغيير زيت', 'Oil change'),
          workshop: 'Gulf Auto Care',
          odometerKm: 123000,
          date: DateTime.now().subtract(const Duration(days: 30)),
          itemKey: MaintenanceType.oil.key,
        ),
      );
      await maintenance.setIntervals(_camry.id, MaintenanceType.oil.key,
          km: 7000, months: 12);

      final due = container.read(maintenanceDueProvider);
      expect(
        due.map((d) => d.type).toList(),
        const [
          MaintenanceType.oil,
          MaintenanceType.tyres,
          MaintenanceType.coolant,
        ],
      );
      // The countdown rule is untouched: 128,450 now, last oil at 123,000,
      // interval 7,000.
      final oil = due.firstWhere((d) => d.type == MaintenanceType.oil);
      expect(oil.remainingKm, 7000 - (128450 - 123000));
      expect(oil.status, DueStatus.near);
    });

    test('an unstated powertrain behaves like a combustion car', () async {
      final container = await containerWith(const [_unstated]);
      expect(
        container.read(maintenanceDueProvider).map((d) => d.type).toList(),
        const [
          MaintenanceType.oil,
          MaintenanceType.tyres,
          MaintenanceType.coolant,
        ],
      );
    });

    test('a hybrid keeps its oil change and gains battery-health', () async {
      final container = await containerWith(
          [_camry.copyWith(powertrain: Powertrain.hybrid)]);
      final types =
          container.read(maintenanceDueProvider).map((d) => d.type).toSet();

      expect(types, contains(MaintenanceType.oil));
      expect(types, contains(MaintenanceType.evBattery));
      // 12V and cabin filter stay inside the oil service on a car that has one.
      expect(types, isNot(contains(MaintenanceType.battery12v)));
    });

    test('battery health is never a number the app made up', () async {
      final container = await containerWith(const [_tesla]);
      final battery = container
          .read(maintenanceDueProvider)
          .firstWhere((d) => d.type == MaintenanceType.evBattery);

      // Nothing has inspected this car, so there is nothing to report — no
      // percentage, no state of health, no "estimated" anything.
      expect(battery.status, DueStatus.noRecord);
      expect(battery.progress, isNull);
      expect(battery.lastRecord, isNull);
    });

    test('an EV coolant line says what it actually cools', () async {
      final container = await containerWith(const [_tesla]);
      final coolant = container
          .read(maintenanceDueProvider)
          .firstWhere((d) => d.type == MaintenanceType.coolant);

      expect(coolant.title.en, 'Battery & thermal coolant');
      expect(coolant.powertrain, Powertrain.electric);
      // The same item on a petrol car keeps its old wording.
      expect(MaintenanceType.coolant.titleFor(Powertrain.petrol).en, 'Coolant');
    });

    testWidgets('the maintenance screen says why there is no battery figure',
        (tester) async {
      await pump(tester, await containerWith(const [_tesla]),
          const MaintenanceScreen(),
          height: 3200);

      expect(find.text('Your primary car · Electric'), findsOneWidget);
      expect(find.textContaining('EV battery health inspection'),
          findsOneWidget);
      expect(
        find.textContaining('The app cannot read your car'),
        findsWidgets,
        reason: 'a missing percentage must not read as a bad battery',
      );
      // No oil card on this screen either.
      expect(find.textContaining('Engine oil'), findsNothing);
    });

    test('the home card ranks by urgency instead of asking for oil by name',
        () async {
      final container = await containerWith(const [_tesla]);
      final due = container.read(maintenanceDueProvider);
      final ranked = due.byUrgency;

      // Items with a real countdown rank ahead of items with no record.
      final firstWithoutRecord =
          ranked.indexWhere((d) => d.progress == null);
      final lastWithRecord =
          ranked.lastIndexWhere((d) => d.progress != null);
      if (firstWithoutRecord != -1 && lastWithRecord != -1) {
        expect(lastWithRecord, lessThan(firstWithoutRecord));
      }
      expect(due.mostUrgent, ranked.first);
    });
  });

  // ---------------------------------------------------------------- services
  group('EV services', () {
    test('every EV category is sold by a capable workshop in every region',
        () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final evCategories = marketplace.evCategories;

      expect(evCategories, isNotEmpty);
      for (final category in evCategories) {
        // The capability is the promise: an EV must not be handed to a
        // workshop with no high-voltage training because the data was lazy.
        for (final offering in marketplace.offeringsFor(category.id)) {
          expect(
            offering.provider.can(category.requires),
            isTrue,
            reason: '${offering.provider.name.en} sells ${category.id} '
                'without ${category.requires}',
          );
        }
        for (final region in marketplace.providerRegions) {
          expect(
            marketplace.providerCountFor(category.id, region: region),
            greaterThan(0),
            reason: 'no workshop sells ${category.id} in $region, so the '
                'region filter would widen without being asked',
          );
        }
      }
    });

    test('EV categories are restricted to cars that plug in', () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final evCheck =
          marketplace.categories.firstWhere((c) => c.id == mockIdEvCheck);

      expect(evCheck.evOnly, isTrue);
      expect(evCheck.appliesTo(Powertrain.electric), isTrue);
      expect(evCheck.appliesTo(Powertrain.pluginHybrid), isTrue);
      expect(evCheck.appliesTo(Powertrain.petrol), isFalse);
      expect(evCheck.appliesTo(Powertrain.hybrid), isFalse);
      // Nothing is hidden from an owner who has not filled the field in.
      expect(evCheck.appliesTo(null), isTrue);

      final oilService =
          marketplace.categories.firstWhere((c) => c.id == mockIdExpress);
      expect(oilService.evOnly, isFalse);
      expect(oilService.appliesTo(Powertrain.electric), isTrue,
          reason: 'an EV still needs tyres, AC and the ordinary services');
    });

    test('categoriesFor puts an EV owner\'s services first', () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      final forEv = marketplace.categoriesFor(Powertrain.electric);
      expect(forEv.first.evOnly, isTrue);
      expect(forEv.where((c) => !c.evOnly), isNotEmpty);

      final forPetrol = marketplace.categoriesFor(Powertrain.petrol);
      expect(forPetrol.any((c) => c.evOnly), isFalse);
      expect(marketplace.categoriesFor(null).length,
          marketplace.categories.length);
    });

    test('only EV-certified workshops are counted as such', () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final certified =
          marketplace.providersWith(ProviderCapability.evService);

      expect(certified, isNotEmpty);
      expect(certified.length, lessThan(marketplace.providers.length),
          reason: 'if every workshop were EV-certified the badge would mean '
              'nothing');
      expect(certified.every((p) => p.evCertified), isTrue);
      expect(
        marketplace
            .providersWith(ProviderCapability.evService, region: 'Muscat')
            .every((p) => p.region == 'Muscat'),
        isTrue,
      );
    });

    testWidgets('an EV owner sees EV services on the services page',
        (tester) async {
      await pump(
        tester,
        await containerWith(const [_tesla]),
        const ServicesScreen(),
        height: 3200,
      );

      expect(find.text('Care for your EV'), findsOneWidget);
      expect(find.textContaining('EV health check', skipOffstage: false),
          findsWidgets);
      // The chip states the powertrain, because it decides what is listed.
      expect(find.textContaining('Electric'), findsWidgets);
    });

    testWidgets('the EV rail is Arabic in Arabic', (tester) async {
      await pump(
        tester,
        await containerWith(const [_tesla]),
        const ServicesScreen(),
        locale: 'ar',
        height: 3200,
      );

      expect(find.text('عناية سيارتك الكهربائية'), findsOneWidget);
      expect(find.text('Care for your EV'), findsNothing);
      expect(find.textContaining('فحص السيارة', skipOffstage: false),
          findsWidgets);
    });

    testWidgets('a petrol owner is not offered high-voltage work',
        (tester) async {
      await pump(
        tester,
        await containerWith(const [_camry]),
        const ServicesScreen(),
        height: 3200,
      );

      // The rail is still there — labelled for whom it is — but the shortlist
      // below holds nothing this car cannot be booked in for.
      expect(find.text('Electric-car services'), findsOneWidget);
      expect(
        find.textContaining('High-voltage battery diagnostic',
            skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('searching still finds every service, whatever the car drives',
        (tester) async {
      // Someone shopping for their next car must not be filtered out of the
      // catalogue by the car they have today.
      await pump(
        tester,
        await containerWith(const [_camry]),
        const ServicesScreen(initialQuery: 'battery'),
        height: 3200,
      );

      expect(
        find.textContaining('High-voltage battery diagnostic',
            skipOffstage: false),
        findsWidgets,
      );
    });

    // The parts half of this used to be asserted here too (the EV charging
    // cable, the 12V auxiliary battery). The parts catalogue is behind
    // AppFlags.partsStoreEnabled for phase 1 and searchResultsProvider
    // returns none of it, so what is left to guard is the service side —
    // which is the half the pilot actually sells.
    test('cross-catalogue search surfaces EV services', () async {
      final container = await createTestContainer();

      final english = container.read(searchResultsProvider('EV'));
      expect(english.services.map((o) => o.name.en),
          contains('EV health check'));
      expect(english.parts, isEmpty);

      final arabic = container.read(searchResultsProvider('كهرب'));
      expect(arabic.services, isNotEmpty);

      final charging = container.read(searchResultsProvider('charging'));
      expect(charging.services, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------- shop
  group('EV parts', () {
    test('the EV filter returns parts that suit an EV, and only those',
        () async {
      final container = await createDataContainer();
      final shop = container.read(shopRepositoryProvider);
      const filter = ShopFilter(powertrain: Powertrain.electric);
      final matches = shop.filter(filter);

      expect(matches, isNotEmpty);
      expect(matches.every((p) => p.fitsPowertrain(Powertrain.electric)),
          isTrue);
      expect(matches.map((p) => p.id), contains(mockIdPr7)); // Type 2 cable
      expect(filter.activeCount, 1);
    });

    test('an EV-only part is kept away from a petrol car', () async {
      final container = await createDataContainer();
      final cable = container.read(shopRepositoryProvider).productById(mockIdPr7)!;

      expect(cable.fitsCar(_camry), isFalse);
      expect(cable.fitsCar(_tesla), isTrue);
      // No saved car means nothing to check against — the shop is never
      // locked to one car.
      expect(cable.fitsCar(null), isTrue);
      expect(const ShopFilter(car: _camry).matches(cable), isFalse);
      expect(const ShopFilter(car: _tesla).matches(cable), isTrue);
    });

    test('a charging cable is not sold as "fits all cars"', () async {
      final container = await createDataContainer();
      final shop = container.read(shopRepositoryProvider);

      expect(shop.productById(mockIdPr7)!.universalFit, isFalse,
          reason: 'restricted to a powertrain, so not universal');
      expect(shop.productById(mockIdPr7)!.evOnly, isTrue);
      // A part with no powertrain restriction still is.
      expect(shop.productById(mockIdPr2)!.universalFit, isTrue);
    });

    test('EV parts are findable by what is printed on them', () async {
      final container = await createDataContainer();
      final shop = container.read(shopRepositoryProvider);

      Iterable<String> hits(String query) =>
          shop.products.where((p) => p.matchesQuery(query)).map((p) => p.id);

      expect(hits('type 2'), contains(mockIdPr7));
      expect(hits('T2-32A-5M'), contains(mockIdPr7));
      expect(hits('electric'), containsAll([mockIdPr7, mockIdPr10, mockIdPr11]));
      expect(hits('كهربائي'), contains(mockIdPr12));
    });

    test('every EV part carries the specs a buyer decides on', () async {
      final container = await createDataContainer();
      final shop = container.read(shopRepositoryProvider);
      final evParts = shop.products.where((p) => p.evOnly);

      expect(evParts.length, greaterThanOrEqualTo(6));
      for (final part in evParts) {
        expect(part.specs, isNotEmpty, reason: '${part.id} has no spec sheet');
        expect(part.partNumber, isNotNull, reason: '${part.id} has no part no.');
        expect(part.description, isNotNull);
      }
      // Charging hardware states its connector — the one spec that decides
      // whether it is usable at all.
      for (final part in shop.products.where((p) => p.categoryId == 'charging')) {
        expect(
          part.specs.any((spec) =>
              spec.label.en.contains('Connector') ||
              spec.label.en.contains('From / to')),
          isTrue,
          reason: '${part.id} does not say which connector it is',
        );
      }
    });

    testWidgets('the product page refuses to imply a wrong-powertrain fit',
        (tester) async {
      await pump(
        tester,
        await containerWith(const [_camry]),
        const ProductDetailScreen(productId: mockIdPr7),
        height: 2200,
      );

      expect(find.textContaining('Not for your Toyota Camry 2021'),
          findsOneWidget);
      expect(find.textContaining('Fits all cars'), findsNothing);
      expect(find.textContaining('For: Electric', skipOffstage: false),
          findsWidgets);
    });

    testWidgets('and confirms the fit for the car it is for', (tester) async {
      await pump(
        tester,
        await containerWith(const [_tesla]),
        const ProductDetailScreen(productId: mockIdPr7),
        height: 2200,
      );

      expect(find.textContaining('Fits your Tesla Model Y 2024'),
          findsOneWidget);
    });
  });

  // --------------------------------------------------------------- challenge
  group('weekly challenge', () {
    test('a car that plugs in gets an EV challenge', () async {
      final container = await containerWith(const [_tesla]);
      final board = container.read(challengeProvider);

      expect(board.current, isNotNull);
      expect(board.current!.id, mockIdEvTripCharge);
      expect(
        board.current!.steps.map((step) => step.title.en).join(' '),
        contains('charging'),
      );
      expect(ChallengeTrackX.of(Powertrain.pluginHybrid),
          ChallengeTrack.electric);
    });

    test('everyone else keeps the combustion challenge', () async {
      final petrol = await containerWith(const [_camry]);
      expect(petrol.read(challengeProvider).current!.id, mockIdTyrePressure);

      final unstated = await containerWith(const [_unstated]);
      expect(unstated.read(challengeProvider).current!.id, mockIdTyrePressure);

      final empty = await createTestContainer();
      expect(empty.read(challengeProvider).current!.id, mockIdTyrePressure);
    });

    test('the loyalty balance does not change with the car', () async {
      final petrol = await containerWith(const [_camry]);
      final ev = await containerWith(const [_tesla]);

      expect(ev.read(challengeProvider).points,
          petrol.read(challengeProvider).points);
      expect(ev.read(challengeProvider).streakWeeks,
          petrol.read(challengeProvider).streakWeeks);
      expect(ev.read(challengeProvider).badgeCount,
          petrol.read(challengeProvider).badgeCount);
    });

    // The maintenance record this challenge feeds is written **server-side**,
    // inside the same transaction as the award — see
    // `CompleteChallengeCommand.FeedMaintenanceRecordAsync` in
    // AKCarsMobileAPI. The client used to write its own copy as well, which
    // was harmless only while the mock backend wrote none; against the real
    // API it filed a second, duplicate record against the car's book. Removed
    // 2026-08-10, so what is checked here is the award, and that the client
    // does *not* write a record of its own.
    test('completing the EV challenge awards, and leaves the record to the '
        'server', () async {
      final container = await containerWith(const [_tesla]);
      final challenge = container.read(challengeProvider.notifier);
      final before = container.read(challengeProvider);
      final recordsBefore =
          container.read(maintenanceBookProvider(_tesla.id)).records.length;

      expect(await challenge.completeChallenge(), isFalse);
      for (final step in before.current!.steps.where((st) => !st.done)) {
        await challenge.toggleStep(step.id);
      }
      expect(await challenge.completeChallenge(), isTrue);

      final after = container.read(challengeProvider);
      expect(after.points, before.points + before.current!.rewardPoints);
      expect(after.streakWeeks, before.streakWeeks + 1);
      expect(after.current, isNull);

      expect(
        container.read(maintenanceBookProvider(_tesla.id)).records.length,
        recordsBefore,
        reason: 'the server owns this record; a client-side copy is a '
            'duplicate in the car\'s history',
      );
    });

    test('finishing one track leaves the other alone', () async {
      final container = await containerWith(const [_tesla]);
      final challenge = container.read(challengeProvider.notifier);
      for (final step in container
          .read(challengeProvider)
          .current!
          .steps
          .where((st) => !st.done)) {
        await challenge.toggleStep(step.id);
      }
      await challenge.completeChallenge();

      // Making the petrol car default must not have consumed its challenge.
      await container.read(garageProvider.notifier).add(_camry);
      await container.read(garageProvider.notifier).setPrimary(_camry.id);
      expect(container.read(challengeProvider).current, isNotNull);
      expect(container.read(challengeProvider).current!.id, mockIdTyrePressure);
    });
  });

  // --------------------------------------------------------------- home page
  group('home', () {
    testWidgets('an EV owner gets EV care, not an oil nudge', (tester) async {
      await pump(tester, await containerWith(const [_tesla]), const HomeScreen(),
          height: 3200);

      // The car card names the powertrain the owner recorded.
      expect(find.text('Tesla Model Y 2024'), findsOneWidget);
      expect(find.text('Electric'), findsOneWidget);

      // Every suggestion for this car is one that exists *because* it plugs in.
      expect(find.text('Suggested for your car'), findsOneWidget);
      expect(find.text('for your electric car'), findsWidgets);

      // No oil, anywhere on the page: not in the suggestions, not in the
      // most-booked list (where an oil change is the country's single most
      // booked job), and not in the offers rail either — a workshop's campaign
      // is still an oil-change campaign.
      // Category names are title-case in the catalogue and the workshop's own
      // campaign spells it "Major service", so both spellings are checked
      // rather than one.
      expect(find.textContaining('Express Service'), findsNothing);
      expect(find.textContaining('Major Service'), findsNothing);
      expect(find.textContaining('Major service'), findsNothing);
      expect(find.textContaining('Engine oil'), findsNothing);
      // And the weekly strip offers the EV challenge.
      expect(find.textContaining('Plan your charging'), findsOneWidget);
    });

    testWidgets('a petrol owner is offered the oil service', (tester) async {
      await pump(tester, await containerWith(const [_camry]), const HomeScreen(),
          height: 3200);

      expect(find.text('Petrol'), findsOneWidget);
      expect(find.text('for your electric car'), findsNothing);
      // The oil package is back — on a car that has an engine.
      expect(find.textContaining('Express Service'), findsWidgets);
    });

    testWidgets('EV home copy is Arabic in Arabic', (tester) async {
      await pump(tester, await containerWith(const [_tesla]), const HomeScreen(),
          locale: 'ar', height: 3200);

      expect(find.text('كهربائي'), findsOneWidget);
      expect(find.text('لسيارتك الكهربائية'), findsWidgets);
      expect(find.text('for your electric car'), findsNothing);
      expect(find.text('Suggested for your car'), findsNothing);
    });
  });

  // ---------------------------------------------------------- cars for sale
  group('EV listings', () {
    test('the electric ad carries the facts its prose used to bury', () async {
      final container = await createDataContainer();
      final tesla = container
          .read(carsRepositoryProvider)
          .listings
          .firstWhere((l) => l.id == mockIdG11);

      expect(tesla.plugsIn, isTrue);
      expect(tesla.rangeKm, 533);
      expect(tesla.batteryWarrantyUntilYear, 2032);
      expect(tesla.chargerIncluded, isTrue);

      // A petrol ad states none of them, and "not stated" stays null rather
      // than becoming a zero.
      final camry = container
          .read(carsRepositoryProvider)
          .listings
          .firstWhere((l) => l.id == mockIdG1);
      expect(camry.plugsIn, isFalse);
      expect(camry.rangeKm, isNull);
      expect(camry.batteryWarrantyUntilYear, isNull);
      expect(camry.chargerIncluded, isNull);
    });

    test('the electric fuel filter still selects the electric ads', () async {
      final container = await createDataContainer();
      final specs = container.read(specCatalogProvider);
      final feed = container.read(carsRepositoryProvider).listings;

      const electric = CarsFilter(fuels: {'Electric'});
      final results = electric.apply(feed, specs);
      expect(results, isNotEmpty);
      expect(results.every((l) => l.fuel == 'Electric'), isTrue);
      expect(results.map((l) => l.id), contains(mockIdG11));
    });
  });
}
