import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/maintenance.dart';
import 'package:ak_cars_mobil_app/data/repositories/maintenance_repository.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

final _now = DateTime(2026, 7, 27);

MaintenanceBook _book({
  int? current,
  DateTime? currentAt,
  int? previous,
  DateTime? previousAt,
  List<ServiceRecord> records = const [],
  List<CustomMaintenanceItem> customItems = const [],
  Map<String, int> kmIntervals = const {},
  Map<String, int> monthIntervals = const {},
}) =>
    MaintenanceBook(
      carId: 'car-1',
      currentOdometerKm: current,
      odometerUpdatedAt: currentAt,
      previousOdometerKm: previous,
      previousOdometerAt: previousAt,
      records: records,
      customItems: customItems,
      kmIntervals: kmIntervals,
      monthIntervals: monthIntervals,
    );

ServiceRecord _oilAt(int km, DateTime date) => ServiceRecord(
      id: 'r1',
      title: const L('زيت', 'Oil'),
      workshop: 'Al Khuwair Auto',
      odometerKm: km,
      date: date,
      itemKey: MaintenanceType.oil.key,
    );

void main() {
  group('usage rate', () {
    test('needs two readings — one gives no rate and no projection', () {
      final book = _book(
        current: 100000,
        currentAt: _now.subtract(const Duration(days: 30)),
      );

      expect(book.avgKmPerDay, isNull);
      expect(book.isProjected(now: _now), isFalse);
      // Falls back to the entered reading rather than guessing.
      expect(book.projectedOdometerKm(now: _now), 100000);
    });

    test('projects forward linearly from the last two readings', () {
      final book = _book(
        previous: 99000,
        previousAt: _now.subtract(const Duration(days: 40)),
        current: 100000,
        currentAt: _now.subtract(const Duration(days: 20)),
      );

      // 1,000 km over 20 days = 50 km/day; 20 days since the last entry.
      expect(book.avgKmPerDay, 50);
      expect(book.projectedOdometerKm(now: _now), 101000);
      expect(book.isProjected(now: _now), isTrue);
    });

    test('a reading entered today is not an estimate', () {
      final book = _book(
        previous: 99000,
        previousAt: _now.subtract(const Duration(days: 20)),
        current: 100000,
        currentAt: _now,
      );

      expect(book.projectedOdometerKm(now: _now), 100000);
      expect(book.isProjected(now: _now), isFalse);
    });

    test('an odometer that went backwards yields no rate', () {
      final book = _book(
        previous: 100000,
        previousAt: _now.subtract(const Duration(days: 20)),
        current: 99000,
        currentAt: _now.subtract(const Duration(days: 5)),
      );

      expect(book.avgKmPerDay, isNull);
    });
  });

  group('due items', () {
    late MaintenanceRepository repository;

    setUp(() async {
      final container = await createDataContainer();
      repository = container.read(maintenanceRepositoryProvider);
    });

    test('the distance countdown measures against the projection', () {
      final book = _book(
        previous: 99000,
        previousAt: _now.subtract(const Duration(days: 40)),
        current: 100000,
        currentAt: _now.subtract(const Duration(days: 20)),
        records: [_oilAt(97000, _now.subtract(const Duration(days: 60)))],
      );

      final oil = repository
          .dueItems(book, now: _now)
          .firstWhere((d) => d.type == MaintenanceType.oil);

      // Last change at 97,000 + a 5,000 km interval = due at 102,000; the
      // projection says the car reads 101,000 today.
      expect(oil.remainingKm, 1000);
      expect(oil.estimated, isTrue);
    });

    test('whichever of distance and time runs out first decides', () {
      // Barely any distance covered, but the service was 14 months ago and
      // the oil interval is 6 months.
      final book = _book(
        current: 97200,
        currentAt: _now,
        records: [_oilAt(97000, _now.subtract(const Duration(days: 430)))],
      );

      final oil = repository
          .dueItems(book, now: _now)
          .firstWhere((d) => d.type == MaintenanceType.oil);

      expect(oil.remainingKm, greaterThan(0));
      expect(oil.remainingMonths, lessThan(0));
      expect(oil.status, DueStatus.due);
    });

    test('an item with no record never reports a percentage', () {
      final book = _book(current: 100000, currentAt: _now);

      for (final item in repository.dueItems(book, now: _now)) {
        expect(item.status, DueStatus.noRecord, reason: item.key);
        expect(item.progress, isNull);
        expect(item.needsSetup, isTrue);
      }
    });

    test('a km-only item with no odometer entry reports no record', () {
      // A logged oil change but the owner has never entered a reading: the
      // time counter still applies, so this one is measurable. Strip the
      // record instead and the item has nothing at all to measure.
      final book = _book(
        records: [_oilAt(97000, _now.subtract(const Duration(days: 10)))],
      );

      final oil = repository
          .dueItems(book, now: _now)
          .firstWhere((d) => d.type == MaintenanceType.oil);

      expect(oil.remainingKm, isNull);
      expect(oil.remainingMonths, isNotNull);
      expect(oil.estimated, isFalse);
    });

    test('an edited interval changes when the item falls due', () {
      final records = [_oilAt(97000, _now.subtract(const Duration(days: 5)))];
      final at = _book(current: 100000, currentAt: _now, records: records);

      // Default 5,000 km: 97,000 + 5,000 = 102,000, so 2,000 km left.
      expect(
        repository
            .dueItems(at, now: _now)
            .firstWhere((d) => d.type == MaintenanceType.oil)
            .remainingKm,
        2000,
      );

      // The owner's own 10,000 km interval moves it out by another 5,000.
      final widened = _book(
        current: 100000,
        currentAt: _now,
        records: records,
        kmIntervals: {MaintenanceType.oil.key: 10000},
      );
      final oil = repository
          .dueItems(widened, now: _now)
          .firstWhere((d) => d.type == MaintenanceType.oil);
      expect(oil.remainingKm, 7000);
      expect(oil.status, DueStatus.good);

      // …and narrowing it past the distance already covered makes it overdue.
      final narrowed = _book(
        current: 100000,
        currentAt: _now,
        records: records,
        kmIntervals: {MaintenanceType.oil.key: 2000},
      );
      expect(
        repository
            .dueItems(narrowed, now: _now)
            .firstWhere((d) => d.type == MaintenanceType.oil)
            .status,
        DueStatus.due,
      );
    });

    test('a custom item counts down against its own interval', () {
      const wipers = CustomMaintenanceItem(
        id: 'custom-1',
        title: 'Wiper blades',
        intervalMonths: 12,
      );
      final book = _book(
        current: 100000,
        currentAt: _now,
        customItems: const [wipers],
        records: [
          ServiceRecord(
            id: 'w1',
            title: const L('Wiper blades', 'Wiper blades'),
            workshop: 'Self',
            odometerKm: 99000,
            date: _now.subtract(const Duration(days: 400)),
            itemKey: 'custom-1',
          ),
        ],
      );

      final item = repository.dueItems(book, now: _now).byKey('custom-1')!;
      expect(item.isCustom, isTrue);
      // The owner's words, unchanged and untranslated on both sides.
      expect(item.title.en, 'Wiper blades');
      expect(item.title.ar, 'Wiper blades');
      expect(item.remainingMonths, lessThan(0));
      expect(item.status, DueStatus.due);
    });

    test('a custom item with no interval keeps its record but no progress', () {
      const item = CustomMaintenanceItem(id: 'custom-2', title: 'Roof rack');
      final book = _book(
        current: 100000,
        currentAt: _now,
        customItems: const [item],
        records: [
          ServiceRecord(
            id: 'rr1',
            title: const L('Roof rack', 'Roof rack'),
            workshop: 'Self',
            odometerKm: 99500,
            date: _now.subtract(const Duration(days: 30)),
            itemKey: 'custom-2',
          ),
        ],
      );

      final due = repository.dueItems(book, now: _now).byKey('custom-2')!;
      expect(due.progress, isNull, reason: 'nothing to measure against');
      expect(due.lastRecord, isNotNull, reason: 'but the history is real');
      expect(due.needsSetup, isFalse);
    });
  });
}
