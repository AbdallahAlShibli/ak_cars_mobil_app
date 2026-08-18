import '../models/car.dart';
import '../models/maintenance.dart';
import 'garage_service.dart';
import 'maintenance_service.dart';
import 'token_store.dart';

/// A user-owned dataset a guest is allowed to build *before* they have an
/// account, and which has to travel with them once they get one.
///
/// The garage and its maintenance books are the only two: rule 3 of first
/// launch (`StartChoiceScreen`) asks for a car as step 3 of 3, which is well
/// before the registration gate that `ensureRegistered` puts in front of
/// bookings, orders and ads. Everything else the app stores is either
/// reference data owned by the server or a transaction that already requires
/// a session.
abstract interface class GuestDataAdopter {
  /// Uploads whatever this device holds for a guest into the session that has
  /// just started, then drops the local copy.
  ///
  /// Must be safe to call when there is nothing to adopt, and safe to call
  /// again after a partial failure — every write it makes is idempotent on an
  /// id the client already chose, so a retry re-sends rather than duplicates.
  Future<void> adoptGuestData();
}

/// Routes the garage to the device while nobody is signed in, and to the API
/// once somebody is.
///
/// **Why this exists.** `/user/vehicles` is `[Authorize]`d — reasonably, since
/// a vehicle belongs to a user. But the app deliberately lets a guest register
/// a car: it is step 3 of 3 of first launch, and `AuthState` documents the rule
/// as "browsing is open, but transactions require a completed registration" —
/// a garage entry is neither. Binding the garage straight to the REST service
/// therefore broke first launch: every write answered `401`, the optimistic
/// state told the user their car was saved, and it was gone by the next cold
/// start.
///
/// [local] is the same prefs-backed store the mock data source uses. That is
/// not a shortcut: it *is* "the device standing in for the server", which is
/// exactly what a guest's garage needs, and sharing the store means a car
/// survives switching `AK_DATA_SOURCE` rather than appearing to vanish.
class SessionGarageService implements GarageService, GuestDataAdopter {
  /// Positional in the order `local, remote, tokens` — the same shape the
  /// other injected services use (`ApiAuthService`, `ApiGarageService`).
  const SessionGarageService(this._local, this._remote, this._tokens);

  final GarageService _local;
  final GarageService _remote;
  final TokenStore _tokens;

  /// Which store owns this call.
  ///
  /// Strict, unlike [TokenStore.mayHaveSession]: that one guesses "maybe" on an
  /// unreadable store because its callers only risk a wasted request. Here the
  /// guess decides *where a write lands*, and the safe failure is the device —
  /// a local write is never lost, it is adopted at the next sign-in, whereas a
  /// remote write on a store that turned out to be empty is a `401` and the
  /// user's data on the floor.
  Future<GarageService> get _store async {
    try {
      return await _tokens.hasSession() ? _remote : _local;
    } catch (_) {
      return _local;
    }
  }

  @override
  Future<List<Car>> fetchCars() async => (await _store).fetchCars();

  @override
  Future<Car> addCar(Car car) async => (await _store).addCar(car);

  @override
  Future<void> removeCar(String carId) async => (await _store).removeCar(carId);

  @override
  Future<Car> updateCar(Car car) async => (await _store).updateCar(car);

  @override
  Future<Car> updatePlate(String carId, String plate) async =>
      (await _store).updatePlate(carId, plate);

  @override
  Future<Car> updateOdometer(String carId, int km) async =>
      (await _store).updateOdometer(carId, km);

  @override
  Future<List<Car>> setPrimary(String carId) async =>
      (await _store).setPrimary(carId);

  @override
  Future<void> adoptGuestData() async {
    final pending = await _local.fetchCars();
    if (pending.isEmpty) return;

    // In order, so the server's `SortOrder` ends up matching the order the
    // user put them in. `AddVehicleCommand` is idempotent on the car id and
    // honours the one the client chose, so the ids the maintenance books are
    // filed under survive the trip.
    for (final car in pending) {
      await _remote.addCar(car);
    }

    // Only once every car is up. A partial upload leaves the local copy alone
    // so the next sign-in finishes the job instead of losing the remainder.
    for (final car in pending) {
      await _local.removeCar(car.id);
    }
  }
}

/// The maintenance books' half of the same rule — see [SessionGarageService]
/// for why this indirection exists at all.
class SessionMaintenanceService
    implements MaintenanceService, GuestDataAdopter {
  const SessionMaintenanceService(this._local, this._remote, this._tokens);

  final MaintenanceService _local;
  final MaintenanceService _remote;
  final TokenStore _tokens;

  Future<MaintenanceService> get _store async {
    try {
      return await _tokens.hasSession() ? _remote : _local;
    } catch (_) {
      return _local;
    }
  }

  @override
  Future<Map<String, MaintenanceBook>> fetchBooks() async =>
      (await _store).fetchBooks();

  @override
  Future<MaintenanceBook> createBook(String carId) async =>
      (await _store).createBook(carId);

  @override
  Future<void> removeBook(String carId) async =>
      (await _store).removeBook(carId);

  @override
  Future<MaintenanceBook> updateOdometer(String carId, int km) async =>
      (await _store).updateOdometer(carId, km);

  @override
  Future<MaintenanceBook> addRecord(String carId, ServiceRecord record) async =>
      (await _store).addRecord(carId, record);

  @override
  Future<MaintenanceBook> updateRecord(
    String carId,
    ServiceRecord record,
  ) async =>
      (await _store).updateRecord(carId, record);

  @override
  Future<MaintenanceBook> removeRecord(String carId, String recordId) async =>
      (await _store).removeRecord(carId, recordId);

  @override
  Future<MaintenanceBook> setKmInterval(
    String carId,
    String itemKey,
    int? km,
  ) async =>
      (await _store).setKmInterval(carId, itemKey, km);

  @override
  Future<MaintenanceBook> setMonthInterval(
    String carId,
    String itemKey,
    int? months,
  ) async =>
      (await _store).setMonthInterval(carId, itemKey, months);

  @override
  Future<MaintenanceBook> saveCustomItem(
    String carId,
    CustomMaintenanceItem item,
  ) async =>
      (await _store).saveCustomItem(carId, item);

  @override
  Future<MaintenanceBook> removeCustomItem(String carId, String itemId) async =>
      (await _store).removeCustomItem(carId, itemId);

  @override
  Future<void> adoptGuestData() async {
    final books = await _local.fetchBooks();
    if (books.isEmpty) return;

    for (final book in books.values) {
      await _remote.createBook(book.carId);

      // Custom items before the records filed against them: removing an item
      // takes its records with it, so the reverse order would upload history
      // that the next write could drop.
      for (final item in book.customItems) {
        await _remote.saveCustomItem(book.carId, item);
      }
      for (final record in book.records) {
        await _remote.addRecord(book.carId, record);
      }
      for (final entry in book.kmIntervals.entries) {
        await _remote.setKmInterval(book.carId, entry.key, entry.value);
      }
      for (final entry in book.monthIntervals.entries) {
        await _remote.setMonthInterval(book.carId, entry.key, entry.value);
      }

      // The reading last. `updateOdometer` is what stamps the previous-reading
      // history the projections are derived from, so it has to be the final
      // word on this book rather than something a later write shifts.
      final km = book.currentOdometerKm;
      if (km != null && km > 0) {
        await _remote.updateOdometer(book.carId, km);
      }
    }

    for (final carId in books.keys) {
      await _local.removeBook(carId);
    }
  }
}
