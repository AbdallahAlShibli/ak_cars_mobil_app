import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/core/widgets/sand_widgets.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/garage/maintenance_screen.dart';
import 'package:ak_cars_mobil_app/features/garage/my_cars_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_harness.dart';

/// Maintenance is per car.
///
/// These tests pin the promise the My Car redesign makes: every registered car
/// owns its own maintenance book, a fresh car is never shown a history it did
/// not have, the owner can enter their real history by hand, and a booking
/// only ever writes a record when it was actually completed and released — on
/// the car it was placed for.

const _camry = Car(
  id: 'c1',
  make: 'Toyota',
  model: 'Camry',
  year: 2021,
  plate: '12345 AB',
  odometerKm: 128450,
  powertrain: Powertrain.petrol,
);

const _patrol = Car(
  id: 'c2',
  make: 'Nissan',
  model: 'Patrol',
  year: 2019,
  odometerKm: 64000,
  powertrain: Powertrain.diesel,
);

const _tesla = Car(
  id: 'ev1',
  make: 'Tesla',
  model: 'Model Y',
  year: 2024,
  odometerKm: 21000,
  powertrain: Powertrain.electric,
);

/// The simulator would walk a booking forward under the test's feet, and the
/// 72-hour approval window is not something a unit test should wait out.
Future<ProviderContainer> _container({List<Car> garage = const []}) async {
  final container = await createDataContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.forEnvironment(
          AppEnvironment.development,
        ).copyWith(simulateProviderLifecycle: false),
      ),
    ],
  );
  for (final car in garage) {
    await container.read(garageProvider.notifier).add(car);
  }
  return container;
}

ServiceRecord _record({
  required String id,
  required String itemKey,
  required int odometerKm,
  required DateTime date,
  String workshop = 'Al Noor Workshop',
}) => ServiceRecord(
  id: id,
  title: const L('خدمة', 'Service'),
  workshop: workshop,
  odometerKm: odometerKm,
  date: date,
  itemKey: itemKey,
);

/// Walks a booking all the way to "released to the workshop" — the only
/// ending that means the work happened.
Future<void> _complete(ProviderContainer container, String id) async {
  final requests = container.read(requestsProvider.notifier);
  await requests.fire(
    id,
    EscrowEvent.confirmFundsHeld,
    actor: EscrowActor.founder,
  );
  await requests.fire(id, EscrowEvent.acceptJob, actor: EscrowActor.workshop);
  await requests.fire(id, EscrowEvent.startWork, actor: EscrowActor.workshop);
  await requests.fire(
    id,
    EscrowEvent.submitProof,
    actor: EscrowActor.workshop,
    proof: testProof(id),
  );
  await requests.fire(id, EscrowEvent.approve, actor: EscrowActor.customer);
}

Future<ServiceRequest> _book(
  ProviderContainer container, {
  required Car car,
  required String offeringId,
  String? maintenanceItemKey,
}) => container
    .read(requestsProvider.notifier)
    .place(
      CreateServiceRequestDraft(
        offering: MockServiceData.offerings.firstWhere(
          (o) => o.id == offeringId,
        ),
        car: car,
        plate: '12345 AB',
        fulfillment: Fulfillment.workshop,
        slot: 'Mon 3 Aug · 10:30',
        addOnIds: const {},
        maintenanceItemKey: maintenanceItemKey,
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  String locale = 'en',
  double height = 2600,
  double width = 402,
}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // Behind a real router: the "Book service" action navigates to the services
  // tab, which is the same wiring the app uses.
  final router = GoRouter(
    initialLocation: '/my-car',
    routes: [
      GoRoute(path: '/my-car', builder: (context, state) => screen),
      GoRoute(path: '/garage', builder: (context, state) => screen),
      GoRoute(
        path: '/services',
        builder: (context, state) => const Scaffold(body: Text('services')),
      ),
      GoRoute(
        path: '/add-car',
        builder: (context, state) => const Scaffold(body: Text('add car')),
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
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // -------------------------------------------------------------- one per car
  group('a book per car', () {
    test('registering a car opens an empty book for it', () async {
      final container = await _container(garage: const [_camry]);

      final book = container.read(maintenanceBookProvider(_camry.id));
      expect(book.carId, _camry.id);
      expect(book.records, isEmpty, reason: 'no history it did not have');
      expect(book.customItems, isEmpty);
      expect(book.isFresh, isTrue);
      // …and it reached the data layer, not just the UI state.
      expect(
        container.read(maintenanceRepositoryProvider).books.keys,
        contains(_camry.id),
      );

      // The schedule is the right one for a petrol car, with nothing due.
      final due = container.read(maintenanceDueForCarProvider(_camry.id));
      expect(
        due.map((d) => d.type),
        containsAll(const [MaintenanceType.oil, MaintenanceType.tyres]),
      );
      expect(due.every((d) => d.status == DueStatus.noRecord), isTrue);
      expect(due.every((d) => d.progress == null), isTrue);
    });

    test('an electric car opens with EV items and no oil line', () async {
      final container = await _container(garage: const [_tesla]);
      final types = container
          .read(maintenanceDueForCarProvider(_tesla.id))
          .map((d) => d.type)
          .toSet();

      expect(types, isNot(contains(MaintenanceType.oil)));
      expect(
        types,
        containsAll(const [
          MaintenanceType.battery12v,
          MaintenanceType.evBattery,
          MaintenanceType.brakeFluid,
        ]),
      );
    });

    test('a combustion car keeps its oil line', () async {
      final container = await _container(garage: const [_camry, _tesla]);
      expect(
        container
            .read(maintenanceDueForCarProvider(_camry.id))
            .map((d) => d.type),
        contains(MaintenanceType.oil),
      );
    });

    test('two cars keep entirely separate records', () async {
      final container = await _container(garage: const [_camry, _patrol]);
      final maintenance = container.read(maintenanceProvider.notifier);

      await maintenance.addRecord(
        _camry.id,
        _record(
          id: 'oil-camry',
          itemKey: MaintenanceType.oil.key,
          odometerKm: 123000,
          date: DateTime.now().subtract(const Duration(days: 20)),
        ),
      );

      expect(
        container.read(maintenanceBookProvider(_camry.id)).records,
        hasLength(1),
      );
      expect(
        container.read(maintenanceBookProvider(_patrol.id)).records,
        isEmpty,
      );

      final patrolOil = container
          .read(maintenanceDueForCarProvider(_patrol.id))
          .firstWhere((d) => d.type == MaintenanceType.oil);
      expect(
        patrolOil.status,
        DueStatus.noRecord,
        reason: "the Camry's oil change is not the Patrol's",
      );
      expect(patrolOil.progress, isNull);
    });

    test('each car keeps its own mileage', () async {
      final container = await _container(garage: const [_camry, _patrol]);
      final garage = container.read(garageProvider.notifier);

      await garage.setOdometer(_camry.id, 129000);
      await garage.setOdometer(_patrol.id, 65000);

      expect(
        container.read(maintenanceBookProvider(_camry.id)).currentOdometerKm,
        129000,
      );
      expect(
        container.read(maintenanceBookProvider(_patrol.id)).currentOdometerKm,
        65000,
      );
      // The car and its book hold the same number — one fact, one place.
      expect(container.read(carByIdProvider(_camry.id))!.odometerKm, 129000);
      expect(container.read(carByIdProvider(_patrol.id))!.odometerKm, 65000);
    });

    test('removing a car takes its book with it', () async {
      final container = await _container(garage: const [_camry, _patrol]);
      await container
          .read(maintenanceProvider.notifier)
          .addRecord(
            _camry.id,
            _record(
              id: 'oil-camry',
              itemKey: MaintenanceType.oil.key,
              odometerKm: 123000,
              date: DateTime.now(),
            ),
          );

      await container.read(garageProvider.notifier).remove(_camry.id);

      expect(container.read(maintenanceProvider).keys, [_patrol.id]);
      expect(
        container.read(maintenanceRepositoryProvider).books.keys,
        isNot(contains(_camry.id)),
      );
    });

    test('switching the default car switches the page to its book', () async {
      final container = await _container(garage: const [_camry, _tesla]);
      await container
          .read(maintenanceProvider.notifier)
          .addRecord(
            _camry.id,
            _record(
              id: 'oil-camry',
              itemKey: MaintenanceType.oil.key,
              odometerKm: 123000,
              date: DateTime.now().subtract(const Duration(days: 10)),
            ),
          );

      expect(container.read(maintenanceCarProvider), _camry);
      expect(
        container.read(maintenanceDueProvider).map((d) => d.type),
        contains(MaintenanceType.oil),
      );

      await container.read(garageProvider.notifier).setPrimary(_tesla.id);

      expect(container.read(maintenanceCarProvider), _tesla);
      final due = container.read(maintenanceDueProvider);
      expect(due.map((d) => d.type), isNot(contains(MaintenanceType.oil)));
      expect(
        due.every((d) => d.status == DueStatus.noRecord),
        isTrue,
        reason: "the Camry's history must not follow the Tesla",
      );
    });

    test('the page can be pointed at a car that is not the default', () async {
      final container = await _container(garage: const [_camry, _patrol]);
      container.read(selectedMaintenanceCarIdProvider.notifier).state =
          _patrol.id;

      expect(container.read(maintenanceCarProvider), _patrol);

      // A selection pointing at a car that has since been deleted falls back
      // to the default rather than showing an empty page.
      await container.read(garageProvider.notifier).remove(_patrol.id);
      expect(container.read(maintenanceCarProvider), _camry);
    });
  });

  // ------------------------------------------------------------ manual entry
  group('entering real history by hand', () {
    test('a first manual record starts that item\'s countdown', () async {
      final container = await _container(garage: const [_camry]);
      final maintenance = container.read(maintenanceProvider.notifier);

      // Before: nothing claimed.
      expect(
        container
            .read(maintenanceDueForCarProvider(_camry.id))
            .firstWhere((d) => d.type == MaintenanceType.oil)
            .status,
        DueStatus.noRecord,
      );

      await container
          .read(garageProvider.notifier)
          .setOdometer(_camry.id, 128450);
      await maintenance.addRecord(
        _camry.id,
        _record(
          id: 'oil-1',
          itemKey: MaintenanceType.oil.key,
          odometerKm: 126000,
          date: DateTime.now().subtract(const Duration(days: 40)),
        ),
      );

      final oil = container
          .read(maintenanceDueForCarProvider(_camry.id))
          .firstWhere((d) => d.type == MaintenanceType.oil);
      // Default 5,000 km interval from 126,000 ⇒ due at 131,000.
      expect(oil.remainingKm, 131000 - 128450);
      expect(oil.progress, isNotNull);
      expect(oil.needsSetup, isFalse);
      expect(oil.lastRecord!.workshop, 'Al Noor Workshop');
    });

    test('editing the interval moves when the item falls due', () async {
      final container = await _container(garage: const [_camry]);
      final maintenance = container.read(maintenanceProvider.notifier);
      await container
          .read(garageProvider.notifier)
          .setOdometer(_camry.id, 128450);
      await maintenance.addRecord(
        _camry.id,
        _record(
          id: 'oil-1',
          itemKey: MaintenanceType.oil.key,
          odometerKm: 126000,
          date: DateTime.now().subtract(const Duration(days: 10)),
        ),
      );

      await maintenance.setIntervals(
        _camry.id,
        MaintenanceType.oil.key,
        km: 10000,
        months: 12,
      );
      expect(
        container
            .read(maintenanceDueForCarProvider(_camry.id))
            .firstWhere((d) => d.type == MaintenanceType.oil)
            .remainingKm,
        136000 - 128450,
      );

      // Clearing the override puts the item back on its default.
      await maintenance.setIntervals(_camry.id, MaintenanceType.oil.key);
      expect(
        container.read(maintenanceBookProvider(_camry.id)).kmIntervals,
        isEmpty,
      );
      expect(
        container
            .read(maintenanceDueForCarProvider(_camry.id))
            .firstWhere((d) => d.type == MaintenanceType.oil)
            .remainingKm,
        131000 - 128450,
      );
    });

    test('a record can be edited and removed', () async {
      final container = await _container(garage: const [_camry]);
      final maintenance = container.read(maintenanceProvider.notifier);
      final record = _record(
        id: 'oil-1',
        itemKey: MaintenanceType.oil.key,
        odometerKm: 126000,
        date: DateTime.now().subtract(const Duration(days: 10)),
      );
      await maintenance.addRecord(_camry.id, record);

      await maintenance.updateRecord(
        _camry.id,
        record.copyWith(odometerKm: 125000, notes: '5W-30'),
      );
      final updated = container
          .read(maintenanceBookProvider(_camry.id))
          .records
          .single;
      expect(updated.odometerKm, 125000);
      expect(updated.notes, '5W-30');

      await maintenance.removeRecord(_camry.id, record.id);
      expect(
        container.read(maintenanceBookProvider(_camry.id)).records,
        isEmpty,
      );
    });
  });

  // ----------------------------------------------------------- custom items
  group('the owner\'s own items', () {
    const wipers = CustomMaintenanceItem(
      id: 'custom-wipers',
      title: 'Wiper blades',
      intervalMonths: 12,
    );

    test(
      'a custom item is added, edited, and deleted with its records',
      () async {
        final container = await _container(garage: const [_camry, _patrol]);
        final maintenance = container.read(maintenanceProvider.notifier);

        await maintenance.saveCustomItem(_camry.id, wipers);
        expect(container.read(maintenanceBookProvider(_camry.id)).customItems, [
          wipers,
        ]);
        // It belongs to this car alone.
        expect(
          container.read(maintenanceBookProvider(_patrol.id)).customItems,
          isEmpty,
        );

        final due = container
            .read(maintenanceDueForCarProvider(_camry.id))
            .byKey(wipers.id)!;
        expect(due.isCustom, isTrue);
        // The owner's words, verbatim and untranslated on both sides.
        expect(due.title.en, 'Wiper blades');
        expect(due.title.ar, 'Wiper blades');

        // Editing replaces rather than duplicating.
        await maintenance.saveCustomItem(
          _camry.id,
          const CustomMaintenanceItem(
            id: 'custom-wipers',
            title: 'Wiper blades (front)',
            intervalKm: 20000,
            intervalMonths: 12,
          ),
        );
        final items = container
            .read(maintenanceBookProvider(_camry.id))
            .customItems;
        expect(items, hasLength(1));
        expect(items.single.title, 'Wiper blades (front)');
        expect(items.single.intervalKm, 20000);

        await maintenance.addRecord(
          _camry.id,
          _record(
            id: 'w1',
            itemKey: wipers.id,
            odometerKm: 127000,
            date: DateTime.now(),
          ),
        );
        expect(
          container.read(maintenanceBookProvider(_camry.id)).records,
          hasLength(1),
        );

        // Deleting the item takes its records with it — a record with no line to
        // belong to would sit in the history resetting nothing.
        await maintenance.removeCustomItem(_camry.id, wipers.id);
        final after = container.read(maintenanceBookProvider(_camry.id));
        expect(after.customItems, isEmpty);
        expect(after.records, isEmpty);
        expect(
          container
              .read(maintenanceDueForCarProvider(_camry.id))
              .byKey(wipers.id),
          isNull,
        );
      },
    );

    test('custom items survive the data layer', () async {
      final container = await _container(garage: const [_camry]);
      await container
          .read(maintenanceProvider.notifier)
          .saveCustomItem(_camry.id, wipers);

      final stored = await container
          .read(maintenanceRepositoryProvider)
          .fetchBooks();
      expect(stored[_camry.id]!.customItems, [wipers]);
    });
  });

  // -------------------------------------------------------------- bookings
  group('a booking only counts when it is finished', () {
    test(
      'a completed booking writes one record on the right car and item',
      () async {
        final container = await _container(garage: const [_camry, _patrol]);
        final request = await _book(
          container,
          car: _camry,
          offeringId: 'o-p1-express',
          maintenanceItemKey: MaintenanceType.oil.key,
        );

        // Nothing is written while the booking is merely placed.
        expect(
          container.read(maintenanceBookProvider(_camry.id)).records,
          isEmpty,
        );

        await _complete(container, request.id);

        final records = container
            .read(maintenanceBookProvider(_camry.id))
            .records;
        expect(records, hasLength(1));
        expect(records.single.itemKey, MaintenanceType.oil.key);
        expect(records.single.bookingId, request.id);
        expect(records.single.isManual, isFalse);
        // …on the car it was booked for, and no other.
        expect(
          container.read(maintenanceBookProvider(_patrol.id)).records,
          isEmpty,
        );
        // And the countdown actually restarted.
        expect(
          container
              .read(maintenanceDueForCarProvider(_camry.id))
              .firstWhere((d) => d.type == MaintenanceType.oil)
              .status,
          isNot(DueStatus.noRecord),
        );
      },
    );

    test('the same release event twice writes one record', () async {
      final container = await _container(garage: const [_camry]);
      final request = await _book(
        container,
        car: _camry,
        offeringId: 'o-p1-express',
        maintenanceItemKey: MaintenanceType.oil.key,
      );
      await _complete(container, request.id);

      // The approval timer and the expiry sweep can both arrive here; neither
      // may double the history.
      await container
          .read(maintenanceProvider.notifier)
          .logCompletedBooking(
            container
                .read(requestsProvider)
                .firstWhere((r) => r.id == request.id),
          );
      await container.read(requestsProvider.notifier).sweepExpiredApprovals();

      expect(
        container.read(maintenanceBookProvider(_camry.id)).records,
        hasLength(1),
      );
    });

    test(
      'a booking with no maintenance context maps from its category',
      () async {
        final container = await _container(garage: const [_camry]);
        final request = await _book(
          container,
          car: _camry,
          offeringId: 'o-p1-express',
        );
        await _complete(container, request.id);

        expect(
          container
              .read(maintenanceBookProvider(_camry.id))
              .records
              .single
              .itemKey,
          MaintenanceType.oil.key,
        );
      },
    );

    test(
      'a category that maps to nothing this car has writes nothing',
      () async {
        // An express service on an electric car: there is no engine oil to
        // reset, so nothing is logged rather than something invented.
        final container = await _container(garage: const [_tesla]);
        final request = await _book(
          container,
          car: _tesla,
          offeringId: 'o-p1-express',
        );
        await _complete(container, request.id);

        expect(
          container.read(maintenanceBookProvider(_tesla.id)).records,
          isEmpty,
        );
      },
    );

    test('a cancelled booking resets nothing', () async {
      final container = await _container(garage: const [_camry]);
      final request = await _book(
        container,
        car: _camry,
        offeringId: 'o-p1-express',
        maintenanceItemKey: MaintenanceType.oil.key,
      );

      await container
          .read(requestsProvider.notifier)
          .fire(
            request.id,
            EscrowEvent.cancelBooking,
            actor: EscrowActor.customer,
          );

      expect(
        container.read(maintenanceBookProvider(_camry.id)).records,
        isEmpty,
      );
      expect(
        container
            .read(maintenanceDueForCarProvider(_camry.id))
            .firstWhere((d) => d.type == MaintenanceType.oil)
            .status,
        DueStatus.noRecord,
      );
    });

    test('a rejected (refunded) booking resets nothing', () async {
      final container = await _container(garage: const [_camry]);
      final request = await _book(
        container,
        car: _camry,
        offeringId: 'o-p1-express',
        maintenanceItemKey: MaintenanceType.oil.key,
      );
      final requests = container.read(requestsProvider.notifier);

      await requests.fire(
        request.id,
        EscrowEvent.confirmFundsHeld,
        actor: EscrowActor.founder,
      );
      await requests.fire(
        request.id,
        EscrowEvent.rejectJob,
        actor: EscrowActor.workshop,
      );

      expect(
        container.read(requestsProvider).single.escrow,
        EscrowState.refunded,
      );
      expect(
        container.read(maintenanceBookProvider(_camry.id)).records,
        isEmpty,
      );
    });

    test('an unresolved dispute resets nothing; resolving for the workshop '
        'does', () async {
      final container = await _container(garage: const [_camry]);
      final request = await _book(
        container,
        car: _camry,
        offeringId: 'o-p1-express',
        maintenanceItemKey: MaintenanceType.oil.key,
      );
      final requests = container.read(requestsProvider.notifier);

      await requests.fire(
        request.id,
        EscrowEvent.confirmFundsHeld,
        actor: EscrowActor.founder,
      );
      await requests.fire(
        request.id,
        EscrowEvent.acceptJob,
        actor: EscrowActor.workshop,
      );
      await requests.fire(
        request.id,
        EscrowEvent.startWork,
        actor: EscrowActor.workshop,
      );
      await requests.fire(
        request.id,
        EscrowEvent.submitProof,
        actor: EscrowActor.workshop,
        proof: testProof(request.id),
      );
      await requests.fire(
        request.id,
        EscrowEvent.raiseIssue,
        actor: EscrowActor.customer,
      );

      // The customer says the work is not right — nothing is claimed yet.
      expect(
        container.read(maintenanceBookProvider(_camry.id)).records,
        isEmpty,
      );

      await requests.fire(
        request.id,
        EscrowEvent.resolveInFavourOfWorkshop,
        actor: EscrowActor.founder,
      );

      // The founder found for the workshop: the work stands, so it is logged.
      expect(
        container.read(maintenanceBookProvider(_camry.id)).records,
        hasLength(1),
      );
    });

    test('a dispute resolved for the customer resets nothing', () async {
      final container = await _container(garage: const [_camry]);
      final request = await _book(
        container,
        car: _camry,
        offeringId: 'o-p1-express',
        maintenanceItemKey: MaintenanceType.oil.key,
      );
      final requests = container.read(requestsProvider.notifier);

      await requests.fire(
        request.id,
        EscrowEvent.confirmFundsHeld,
        actor: EscrowActor.founder,
      );
      await requests.fire(
        request.id,
        EscrowEvent.acceptJob,
        actor: EscrowActor.workshop,
      );
      await requests.fire(
        request.id,
        EscrowEvent.startWork,
        actor: EscrowActor.workshop,
      );
      await requests.fire(
        request.id,
        EscrowEvent.submitProof,
        actor: EscrowActor.workshop,
        proof: testProof(request.id),
      );
      await requests.fire(
        request.id,
        EscrowEvent.raiseIssue,
        actor: EscrowActor.customer,
      );
      await requests.fire(
        request.id,
        EscrowEvent.resolveInFavourOfCustomer,
        actor: EscrowActor.founder,
      );

      expect(
        container.read(maintenanceBookProvider(_camry.id)).records,
        isEmpty,
      );
    });

    test('a booking for an unregistered car writes nothing', () async {
      // Booked without saving the car: there is no book to file it against,
      // and the app must not invent one.
      final container = await _container();
      const adhoc = Car(
        id: 'adhoc',
        make: 'Selected',
        model: 'car',
        year: 2020,
      );
      final request = await _book(
        container,
        car: adhoc,
        offeringId: 'o-p1-express',
      );
      await _complete(container, request.id);

      expect(container.read(maintenanceProvider), isEmpty);
    });
  });

  // --------------------------------------------------------------- the page
  group('the My Car page', () {
    testWidgets('asks for a car when the garage is empty', (tester) async {
      await _pump(tester, await _container(), const MaintenanceScreen());

      expect(find.text('No car yet'), findsOneWidget);
      expect(find.text('Add car'), findsOneWidget);
      expect(find.textContaining('Engine oil'), findsNothing);
    });

    testWidgets('shows the setup state for a fresh car, not a countdown', (
      tester,
    ) async {
      await _pump(
        tester,
        await _container(garage: const [_camry]),
        const MaintenanceScreen(),
      );

      expect(
        find.textContaining('Start Toyota Camry 2021\'s maintenance book'),
        findsOneWidget,
      );
      expect(find.text('Engine oil + filter'), findsOneWidget);
      expect(find.text('No record yet'), findsWidgets);
      expect(find.text('Add last service'), findsWidgets);
      expect(find.text('Book service'), findsWidgets);
      expect(
        find.textContaining('No services recorded for this car yet'),
        findsOneWidget,
      );
      // Nothing claimed about how far along anything is.
      expect(find.byType(SandProgressBar), findsNothing);
    });

    testWidgets('the manual-entry sheet saves a first record and an interval', (
      tester,
    ) async {
      final container = await _container(garage: const [_camry]);
      await _pump(tester, container, const MaintenanceScreen());

      await tester.tap(find.text('Add last service').first);
      await tester.pumpAndSettle();

      expect(find.text('Add last service'), findsWidgets);
      expect(
        find.textContaining('Engine oil + filter · Toyota Camry 2021'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 123000'),
        '126000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Al Noor Workshop'),
        'Gulf Auto Care',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 5W-30 synthetic'),
        '5W-30 synthetic',
      );
      await tester.enterText(find.widgetWithText(TextField, '5000'), '7000');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final book = container.read(maintenanceBookProvider(_camry.id));
      final record = book.records.single;
      expect(record.itemKey, MaintenanceType.oil.key);
      expect(record.odometerKm, 126000);
      expect(record.workshop, 'Gulf Auto Care');
      expect(record.notes, '5W-30 synthetic');
      expect(book.kmIntervals[MaintenanceType.oil.key], 7000);

      // The countdown now exists, computed from what the owner entered.
      final oil = container
          .read(maintenanceDueForCarProvider(_camry.id))
          .firstWhere((d) => d.type == MaintenanceType.oil);
      expect(oil.status, isNot(DueStatus.noRecord));
      expect(oil.progress, isNotNull);
    });

    testWidgets('a custom item can be added from the page', (tester) async {
      final container = await _container(garage: const [_camry]);
      await _pump(tester, container, const MaintenanceScreen());

      await tester.tap(find.text('Add your own item'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Wiper blades'),
        'Spark plugs',
      );
      await tester.enterText(find.widgetWithText(TextField, '20000'), '40000');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save item'));
      await tester.pumpAndSettle();

      final custom = container
          .read(maintenanceBookProvider(_camry.id))
          .customItems
          .single;
      expect(custom.title, 'Spark plugs');
      expect(custom.intervalKm, 40000);
      expect(find.text('Spark plugs'), findsWidgets);
      expect(find.text('Your item'), findsWidgets);
    });

    testWidgets('tapping Book leaves the car and item behind for the booking', (
      tester,
    ) async {
      final container = await _container(garage: const [_camry]);
      await _pump(tester, container, const MaintenanceScreen());

      await tester.tap(find.text('Book service').first);
      await tester.pumpAndSettle();

      final intent = container.read(maintenanceBookingIntentProvider)!;
      expect(intent.carId, _camry.id);
      expect(intent.itemKey, MaintenanceType.oil.key);
    });

    testWidgets('the page switches with the car', (tester) async {
      // Wider surface: the car switcher is a horizontal rail, and the second
      // chip sits past the right edge of a phone viewport.
      final container = await _container(garage: const [_camry, _tesla]);
      await _pump(tester, container, const MaintenanceScreen(), width: 700);

      expect(find.text('Engine oil + filter'), findsOneWidget);

      await tester.tap(find.text('Tesla Model Y 2024'));
      await tester.pumpAndSettle();

      expect(find.text('Engine oil + filter'), findsNothing);
      expect(find.text('EV battery health inspection'), findsOneWidget);
    });

    testWidgets('renders in Arabic without English leaking through', (
      tester,
    ) async {
      await _pump(
        tester,
        await _container(garage: const [_camry]),
        const MaintenanceScreen(),
        locale: 'ar',
      );

      expect(find.text('جدول الصيانة'), findsOneWidget);
      expect(find.text('لا يوجد سجل'), findsWidgets);
      expect(find.text('أضف آخر خدمة'), findsWidgets);
      expect(find.text('أضف بنداً خاصاً بك'), findsOneWidget);
      expect(find.text('سجل الخدمات'), findsOneWidget);
      expect(find.text('Maintenance schedule'), findsNothing);
      expect(find.text('No record yet'), findsNothing);
      expect(find.text('Add last service'), findsNothing);
    });
  });

  // ------------------------------------------------------------- the garage
  group('the garage strip', () {
    testWidgets('each card reads its own car\'s book', (tester) async {
      final container = await _container(garage: const [_camry, _patrol]);
      final maintenance = container.read(maintenanceProvider.notifier);
      await container
          .read(garageProvider.notifier)
          .setOdometer(_camry.id, 128450);
      await maintenance.addRecord(
        _camry.id,
        _record(
          id: 'oil-camry',
          itemKey: MaintenanceType.oil.key,
          odometerKm: 126000,
          date: DateTime.now().subtract(const Duration(days: 10)),
        ),
      );

      await _pump(tester, container, const MyCarsScreen(), height: 2000);

      // The Camry has a real countdown; the Patrol says it has none, rather
      // than borrowing the Camry's.
      expect(find.text('Engine oil'), findsOneWidget);
      expect(
        find.textContaining('No service record for this car yet'),
        findsOneWidget,
      );
    });
  });
}
