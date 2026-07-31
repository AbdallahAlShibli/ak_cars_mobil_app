import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../models/maintenance.dart';
import 'mock_service_base.dart';
import 'prefs_collection.dart';

/// One maintenance book per registered car.
///
/// Everything here comes from data the *user* enters (odometer readings,
/// manual records, their own extra items) plus service records written when a
/// booking they placed was completed — the app never reads anything from the
/// car itself, and it never seeds a car with a history it did not have.
///
/// Phase 2: implement `RestMaintenanceService` against
/// `GET /user/vehicles/{carId}/maintenance` and the nested
/// `…/records`, `…/items`, `…/odometer`, `…/intervals` resources. Every method
/// below is already shaped as one of those calls: it names the car, carries
/// only the changed part, and answers with the whole book so the client never
/// has to reconstruct one from a patch.
abstract interface class MaintenanceService {
  /// `GET /user/vehicles/maintenance` — every book the user has.
  Future<Map<String, MaintenanceBook>> fetchBooks();

  /// `POST /user/vehicles/{carId}/maintenance` — creates the empty book a
  /// newly registered car starts with. Idempotent: creating one that already
  /// exists returns the existing book rather than wiping it.
  Future<MaintenanceBook> createBook(String carId);

  /// `DELETE /user/vehicles/{carId}/maintenance`.
  Future<void> removeBook(String carId);

  /// `PUT /user/vehicles/{carId}/maintenance/odometer`.
  Future<MaintenanceBook> updateOdometer(String carId, int km);

  /// `POST /user/vehicles/{carId}/maintenance/records`. Upserts by record id,
  /// which is what makes a repeated booking-completion event harmless.
  Future<MaintenanceBook> addRecord(String carId, ServiceRecord record);

  /// `PUT /user/vehicles/{carId}/maintenance/records/{recordId}`.
  Future<MaintenanceBook> updateRecord(String carId, ServiceRecord record);

  /// `DELETE /user/vehicles/{carId}/maintenance/records/{recordId}`.
  Future<MaintenanceBook> removeRecord(String carId, String recordId);

  /// `PUT /user/vehicles/{carId}/maintenance/intervals/{itemKey}`. A null
  /// interval clears the override and puts the item back on its default.
  Future<MaintenanceBook> setKmInterval(String carId, String itemKey, int? km);

  Future<MaintenanceBook> setMonthInterval(
    String carId,
    String itemKey,
    int? months,
  );

  /// `POST /user/vehicles/{carId}/maintenance/items` — the owner's own extra
  /// line. Upserts by item id.
  Future<MaintenanceBook> saveCustomItem(
    String carId,
    CustomMaintenanceItem item,
  );

  /// `DELETE /user/vehicles/{carId}/maintenance/items/{itemId}` — removes the
  /// item and the records filed under it, since they no longer have a line to
  /// belong to.
  Future<MaintenanceBook> removeCustomItem(String carId, String itemId);
}

/// Stands in for the server *and* the table it would keep the books in.
///
/// Persisted for the same reason the garage is: the mileage entered when a car
/// is registered, and every record logged against it since, is the user's own
/// data. Kept only in memory it vanished on the next launch, so a car
/// restored from the device would come back with an empty history it had not
/// actually lost.
class MockMaintenanceService
    with MockServiceBase
    implements MaintenanceService {
  MockMaintenanceService({
    required this.config,
    required SharedPreferences prefs,
  }) : _storage = PrefsCollection<MaintenanceBook>(
         prefs: prefs,
         key: AppConstants.prefsMaintenance,
         fromJson: MaintenanceBook.fromJson,
         toJson: (book) => book.toJson(),
       ) {
    for (final book in _storage.load()) {
      _books[book.carId] = book;
    }
  }

  @override
  final AppConfig config;

  final PrefsCollection<MaintenanceBook> _storage;

  /// Seeded from the device on construction. Empty on a fresh install: no
  /// cars means no maintenance history either — the demo book that used to
  /// live here made every first run show services a car had never had.
  final Map<String, MaintenanceBook> _books = {};

  @override
  Future<Map<String, MaintenanceBook>> fetchBooks() =>
      respond(Map<String, MaintenanceBook>.unmodifiable(_books));

  @override
  Future<MaintenanceBook> createBook(String carId) =>
      _store(_books[carId] ??= MaintenanceBook.empty(carId));

  @override
  Future<void> removeBook(String carId) {
    _books.remove(carId);
    _save();
    return respond(null);
  }

  @override
  Future<MaintenanceBook> updateOdometer(String carId, int km) {
    if (km <= 0) return respond(_book(carId));
    final book = _book(carId);
    // The reading being replaced becomes the previous one, which is what
    // gives the book a usage rate to project from (spec §4). A correction
    // downwards (typo, wrong car) is not a second data point, so it replaces
    // the reading without shifting history.
    final forward = km >= (book.currentOdometerKm ?? 0);
    // Built rather than copied: clearing the previous reading has to be
    // distinguishable from leaving it alone, and `copyWith`'s null means
    // "unchanged" (see ARCHITECTURE.md §4).
    return _store(
      MaintenanceBook(
        carId: carId,
        currentOdometerKm: km,
        odometerUpdatedAt: DateTime.now(),
        previousOdometerKm: forward ? book.currentOdometerKm : null,
        previousOdometerAt: forward ? book.odometerUpdatedAt : null,
        records: book.records,
        customItems: book.customItems,
        kmIntervals: book.kmIntervals,
        monthIntervals: book.monthIntervals,
      ),
    );
  }

  @override
  Future<MaintenanceBook> addRecord(String carId, ServiceRecord record) {
    final book = _book(carId);
    // Upsert, not append: the completion of one booking writes one record no
    // matter how many times the event reaches us.
    return _store(
      book.copyWith(
        records: [
          record,
          for (final r in book.records)
            if (r.id != record.id) r,
        ],
      ),
    );
  }

  @override
  Future<MaintenanceBook> updateRecord(String carId, ServiceRecord record) {
    final book = _book(carId);
    return _store(
      book.copyWith(
        records: [
          for (final r in book.records)
            if (r.id == record.id) record else r,
        ],
      ),
    );
  }

  @override
  Future<MaintenanceBook> removeRecord(String carId, String recordId) {
    final book = _book(carId);
    return _store(
      book.copyWith(
        records: [
          for (final r in book.records)
            if (r.id != recordId) r,
        ],
      ),
    );
  }

  @override
  Future<MaintenanceBook> setKmInterval(String carId, String itemKey, int? km) {
    final book = _book(carId);
    return _store(
      book.copyWith(kmIntervals: _withInterval(book.kmIntervals, itemKey, km)),
    );
  }

  @override
  Future<MaintenanceBook> setMonthInterval(
    String carId,
    String itemKey,
    int? months,
  ) {
    final book = _book(carId);
    return _store(
      book.copyWith(
        monthIntervals: _withInterval(book.monthIntervals, itemKey, months),
      ),
    );
  }

  @override
  Future<MaintenanceBook> saveCustomItem(
    String carId,
    CustomMaintenanceItem item,
  ) {
    final book = _book(carId);
    final replaced = book.customItemById(item.id) != null;
    return _store(
      book.copyWith(
        customItems: [
          for (final c in book.customItems)
            if (c.id == item.id) item else c,
          if (!replaced) item,
        ],
      ),
    );
  }

  @override
  Future<MaintenanceBook> removeCustomItem(String carId, String itemId) {
    final book = _book(carId);
    return _store(
      book.copyWith(
        customItems: [
          for (final c in book.customItems)
            if (c.id != itemId) c,
        ],
        // The records filed under it go too: a record whose item no longer
        // exists would sit in the history with nothing to reset.
        records: [
          for (final r in book.records)
            if (r.itemKey != itemId) r,
        ],
        kmIntervals: {
          for (final e in book.kmIntervals.entries)
            if (e.key != itemId) e.key: e.value,
        },
        monthIntervals: {
          for (final e in book.monthIntervals.entries)
            if (e.key != itemId) e.key: e.value,
        },
      ),
    );
  }

  /// The car's book, created on demand — a write against a car registered
  /// before this feature existed must not 404.
  MaintenanceBook _book(String carId) =>
      _books[carId] ??= MaintenanceBook.empty(carId);

  /// The single write path: every mutation above ends here, so no change can
  /// reach memory without also reaching the device.
  Future<MaintenanceBook> _store(MaintenanceBook book) {
    _books[book.carId] = book;
    _save();
    return respond(book);
  }

  void _save() => _storage.save(_books.values);

  static Map<String, int> _withInterval(
    Map<String, int> intervals,
    String itemKey,
    int? value,
  ) => {
    for (final e in intervals.entries)
      if (e.key != itemKey) e.key: e.value,
    if (value != null && value > 0) itemKey: value,
  };
}
