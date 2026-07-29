import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_cars_data.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_catalog_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'helpers/test_harness.dart';


void main() {
  group('cars filter', () {
    const feed = MockCarsData.galleryListings;
    const specs = MockCatalogData.specCatalog;

    test('body type + make narrow the feed', () {
      const f = CarsFilter(bodyTypes: {'SUV'});
      final suvs = f.apply(feed, specs);
      expect(suvs, isNotEmpty);
      expect(suvs.every((l) => l.bodyType == 'SUV'), isTrue);

      const nissan = CarsFilter(make: 'Nissan');
      expect(nissan.apply(feed, specs).every((l) => l.make == 'Nissan'), isTrue);
    });

    test('multi-select facets OR within a facet, AND across facets', () {
      // Two fuels OR'd together must widen, never narrow.
      const petrol = CarsFilter(fuels: {'Petrol'});
      const both = CarsFilter(fuels: {'Petrol', 'Diesel'});
      expect(petrol.apply(feed, specs).every((l) => l.fuel == 'Petrol'), isTrue);
      expect(both.apply(feed, specs).length,
          greaterThan(petrol.apply(feed, specs).length));

      // Cylinders facet uses ints.
      const v8 = CarsFilter(cylinders: {8});
      expect(v8.apply(feed, specs).every((l) => l.cylinders == 8), isTrue);
      expect(v8.apply(feed, specs), isNotEmpty);

      // Across facets is AND: SUV + 8-cyl.
      const suvV8 = CarsFilter(bodyTypes: {'SUV'}, cylinders: {8});
      expect(
          suvV8.apply(feed, specs).every((l) => l.bodyType == 'SUV' && l.cylinders == 8),
          isTrue);
    });

    test('max mileage excludes higher-odometer listings', () {
      const f = CarsFilter(maxMileage: 100000);
      expect(f.apply(feed, specs).every((l) => l.mileageValue <= 100000), isTrue);
      expect(f.apply(feed, specs), isNotEmpty);
    });

    test('year range is inclusive on both ends', () {
      const f = CarsFilter(fromYear: 2018, toYear: 2021);
      final out = f.apply(feed, specs);
      expect(out, isNotEmpty);
      expect(out.every((l) => l.year >= 2018 && l.year <= 2021), isTrue);
    });

    test('price filter excludes "Ask for price" listings', () {
      // g1 is priced null (Ask for price); it must drop out once a price
      // bound is set even though no upper limit excludes it by value.
      const f = CarsFilter(minPrice: 1);
      expect(f.apply(feed, specs).any((l) => l.price == null), isFalse);
    });

    test('sort: price low-to-high orders by ascending price', () {
      const f = CarsFilter(minPrice: 1, sort: GallerySort.priceLowHigh);
      final prices = f.apply(feed, specs).map((l) => l.price!).toList();
      final sorted = [...prices]..sort();
      expect(prices, sorted);
    });

    test('activeCount reflects only the constraints that are set', () {
      expect(const CarsFilter().activeCount, 0);
      expect(
          const CarsFilter(make: 'Toyota', bodyTypes: {'Sedan'}).activeCount,
          2);
      // from/to collapse into one "year" facet.
      expect(const CarsFilter(fromYear: 2015, toYear: 2020).activeCount, 1);
    });
  });

  test('maintenance: remaining = interval − (current − lastServiceOdometer)',
      () async {
    final container = await createDataContainer();
    const camry =
        Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2021);
    await container.read(garageProvider.notifier).add(camry);

    final maintenance = container.read(maintenanceProvider.notifier);
    await container.read(garageProvider.notifier).setOdometer(camry.id, 128450);
    await maintenance.addRecord(
      camry.id,
      ServiceRecord(
        id: 'r-oil-1',
        title: const L('تغيير زيت', 'Oil change'),
        workshop: 'Gulf Auto Care',
        odometerKm: 123000,
        date: DateTime.now().subtract(const Duration(days: 30)),
        itemKey: MaintenanceType.oil.key,
      ),
    );
    await maintenance.setIntervals(camry.id, MaintenanceType.oil.key,
        km: 7000, months: 12);

    final due = container.read(maintenanceDueForCarProvider(camry.id));
    final oil = due.firstWhere((d) => d.type == MaintenanceType.oil);
    // Current 128,450, last oil 123,000, interval 7,000.
    expect(oil.remainingKm, 7000 - (128450 - 123000)); // 1,550
    expect(oil.status, DueStatus.near);

    // No record ⇒ never a percentage.
    final coolant = due.firstWhere((d) => d.type == MaintenanceType.coolant);
    expect(coolant.status, DueStatus.noRecord);
    expect(coolant.progress, isNull);

    // Updating the odometer recomputes.
    await container.read(garageProvider.notifier).setOdometer(camry.id, 130000);
    final oil2 = container
        .read(maintenanceDueForCarProvider(camry.id))
        .firstWhere((d) => d.type == MaintenanceType.oil);
    expect(oil2.remainingKm, 0);
    expect(oil2.status, DueStatus.due);
  });

  test(
      'challenge: completing all steps awards points + badge + streak '
      'and feeds the default car\'s maintenance book', () async {
    final container = await createDataContainer();
    const camry =
        Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2021);
    await container.read(garageProvider.notifier).add(camry);

    final notifier = container.read(challengeProvider.notifier);
    final before = container.read(challengeProvider);
    final recordsBefore =
        container.read(maintenanceBookProvider(camry.id)).records.length;
    expect(before.current, isNotNull);

    // Cannot complete until every step is done.
    expect(await notifier.completeChallenge(), isFalse);

    for (final step in before.current!.steps.where((st) => !st.done)) {
      await notifier.toggleStep(step.id);
    }
    expect(await notifier.completeChallenge(), isTrue);

    final after = container.read(challengeProvider);
    expect(after.points, before.points + before.current!.rewardPoints);
    expect(after.badgeCount, before.badgeCount + 1);
    expect(after.streakWeeks, before.streakWeeks + 1);
    expect(after.completedCount, before.completedCount + 1);
    expect(after.current, isNull);
    expect(after.history.length, before.history.length + 1);

    // The tyre-pressure challenge writes a maintenance record — on the
    // default car's book, not a global one.
    expect(container.read(maintenanceBookProvider(camry.id)).records.length,
        recordsBefore + 1);
  });
}
