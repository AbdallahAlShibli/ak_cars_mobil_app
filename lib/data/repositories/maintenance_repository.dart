import '../models/maintenance.dart';
import '../models/powertrain.dart';
import '../services/maintenance_service.dart';
import 'warm_cache.dart';

/// One maintenance book per registered car, plus the countdown each implies.
///
/// [dueItems] is the domain rule the maintenance screen renders: remaining =
/// interval − (currentOdometer − lastServiceOdometer), with month-based items
/// measured from the record date instead. It lives here, not in a widget or a
/// Riverpod provider, so it is unit-testable without a widget tree and so a
/// server-computed version can replace it without touching the UI.
abstract interface class MaintenanceRepository {
  /// Loads the books so [books] can be read synchronously on the first frame.
  Future<void> warmUp();

  /// The books as of the last load or write, keyed by car id.
  Map<String, MaintenanceBook> get books;

  /// This car's book, or an empty one when the car has never been written to.
  /// Never null: a registered car always has a schedule, it just may have no
  /// history in it yet.
  MaintenanceBook bookFor(String carId);

  Future<Map<String, MaintenanceBook>> fetchBooks();

  /// Creates the empty book a newly registered car starts with. Idempotent.
  Future<MaintenanceBook> createBook(String carId);

  Future<void> removeBook(String carId);

  Future<MaintenanceBook> updateOdometer(String carId, int km);

  Future<MaintenanceBook> addRecord(String carId, ServiceRecord record);

  Future<MaintenanceBook> updateRecord(String carId, ServiceRecord record);

  Future<MaintenanceBook> removeRecord(String carId, String recordId);

  Future<MaintenanceBook> setKmInterval(String carId, String itemKey, int? km);

  Future<MaintenanceBook> setMonthInterval(
      String carId, String itemKey, int? months);

  Future<MaintenanceBook> saveCustomItem(
      String carId, CustomMaintenanceItem item);

  Future<MaintenanceBook> removeCustomItem(String carId, String itemId);

  /// Upcoming items computed from [book]. Never reports a percentage for an
  /// item with no record — that is the whole point of the redesign that
  /// replaced the old fabricated "health score".
  ///
  /// [powertrain] selects which built-in items the car actually has: an
  /// electric car gets no engine-oil countdown, and gains the 12V battery,
  /// cabin filter, brake fluid and battery-health lines instead. Null (the
  /// owner has not said) keeps the combustion set. The owner's own custom
  /// items are appended whatever the car runs on.
  List<DueItem> dueItems(
    MaintenanceBook book, {
    DateTime? now,
    Powertrain? powertrain,
  });
}

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl(this._service);

  final MaintenanceService _service;

  final _books =
      WarmCache<Map<String, MaintenanceBook>>(fallback: const {});

  /// Threshold at which an item stops being "good" and starts being "near".
  static const _nearThreshold = 0.6;

  /// Average days per month, used to age month-based intervals.
  static const _daysPerMonth = 30.4;

  @override
  Future<void> warmUp() => _books.load(_service.fetchBooks);

  @override
  Map<String, MaintenanceBook> get books => _books.value;

  @override
  MaintenanceBook bookFor(String carId) =>
      _books.value[carId] ?? MaintenanceBook.empty(carId);

  @override
  Future<Map<String, MaintenanceBook>> fetchBooks() =>
      _books.load(_service.fetchBooks);

  @override
  Future<MaintenanceBook> createBook(String carId) =>
      _store(_service.createBook(carId));

  @override
  Future<void> removeBook(String carId) async {
    await _service.removeBook(carId);
    _books.put({
      for (final e in _books.value.entries)
        if (e.key != carId) e.key: e.value,
    });
  }

  @override
  Future<MaintenanceBook> updateOdometer(String carId, int km) =>
      _store(_service.updateOdometer(carId, km));

  @override
  Future<MaintenanceBook> addRecord(String carId, ServiceRecord record) =>
      _store(_service.addRecord(carId, record));

  @override
  Future<MaintenanceBook> updateRecord(String carId, ServiceRecord record) =>
      _store(_service.updateRecord(carId, record));

  @override
  Future<MaintenanceBook> removeRecord(String carId, String recordId) =>
      _store(_service.removeRecord(carId, recordId));

  @override
  Future<MaintenanceBook> setKmInterval(
          String carId, String itemKey, int? km) =>
      _store(_service.setKmInterval(carId, itemKey, km));

  @override
  Future<MaintenanceBook> setMonthInterval(
          String carId, String itemKey, int? months) =>
      _store(_service.setMonthInterval(carId, itemKey, months));

  @override
  Future<MaintenanceBook> saveCustomItem(
          String carId, CustomMaintenanceItem item) =>
      _store(_service.saveCustomItem(carId, item));

  @override
  Future<MaintenanceBook> removeCustomItem(String carId, String itemId) =>
      _store(_service.removeCustomItem(carId, itemId));

  /// Keeps the warm cache in step with every write.
  Future<MaintenanceBook> _store(Future<MaintenanceBook> write) async {
    final updated = await write;
    _books.put({..._books.value, updated.carId: updated});
    return updated;
  }

  @override
  List<DueItem> dueItems(
    MaintenanceBook book, {
    DateTime? now,
    Powertrain? powertrain,
  }) {
    final today = now ?? DateTime.now();
    return [
      for (final item in book.itemsFor(powertrain))
        _computeDue(book, item, today, powertrain),
    ];
  }

  /// Distance *and* time, whichever runs out first (spec §4).
  ///
  /// Both counters are computed where the data allows it and the more
  /// consumed of the two decides the item's status, because that is the one
  /// that actually falls due. The distance counter measures against the
  /// *projected* odometer, so a reading entered three weeks ago does not make
  /// an oil change look further off than it is — and the resulting item is
  /// marked [DueItem.estimated] so the screen can say so.
  DueItem _computeDue(
    MaintenanceBook book,
    MaintenanceItem item,
    DateTime now,
    Powertrain? powertrain,
  ) {
    final last = book.lastRecordOf(item.key);
    if (last == null) {
      return DueItem(
        item: item,
        status: DueStatus.noRecord,
        powertrain: powertrain,
      );
    }

    final rule = MaintenanceRule.resolve(item, book);
    final odometer = book.projectedOdometerKm(now: now);
    final estimated = book.isProjected(now: now);

    int? remainingKm;
    double? kmProgress;
    if (rule.intervalKm != null && odometer != null) {
      final interval = rule.intervalKm!;
      remainingKm = (last.odometerKm + interval) - odometer;
      kmProgress = ((interval - remainingKm) / interval).clamp(0.0, 1.0);
    }

    int? remainingMonths;
    double? monthProgress;
    if (rule.intervalMonths != null) {
      final interval = rule.intervalMonths!;
      final elapsedMonths =
          (now.difference(last.date).inDays / _daysPerMonth).floor();
      remainingMonths = interval - elapsedMonths;
      monthProgress = (elapsedMonths / interval).clamp(0.0, 1.0);
    }

    // Neither counter is computable — a km-only item whose owner has never
    // entered an odometer reading, or a custom item with no interval at all.
    // The record is still carried so the screen can show it; what it must not
    // do is draw a progress bar it cannot justify.
    if (kmProgress == null && monthProgress == null) {
      return DueItem(
        item: item,
        status: DueStatus.noRecord,
        lastRecord: last,
        powertrain: powertrain,
      );
    }

    final progress = [?kmProgress, ?monthProgress]
        .reduce((a, b) => a > b ? a : b);
    final exhausted =
        (remainingKm != null && remainingKm <= 0) ||
            (remainingMonths != null && remainingMonths <= 0);

    return DueItem(
      item: item,
      status: _statusFor(exhausted: exhausted, progress: progress),
      progress: progress,
      remainingKm: remainingKm,
      remainingMonths: remainingMonths,
      lastRecord: last,
      powertrain: powertrain,
      estimated: estimated && remainingKm != null,
    );
  }

  DueStatus _statusFor({required bool exhausted, required double progress}) {
    if (exhausted) return DueStatus.due;
    return progress >= _nearThreshold ? DueStatus.near : DueStatus.good;
  }
}
