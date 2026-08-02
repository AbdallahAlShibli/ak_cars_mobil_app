import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/guid.dart';
import '../core/i18n/strings.dart';
import '../data/models/car.dart';
import '../data/models/maintenance.dart';
import '../data/models/powertrain.dart';
import '../data/models/service_request.dart';
import '../di/providers.dart';
import 'garage_state.dart';

/// Every registered car's maintenance book, keyed by car id.
///
/// One book per car: adding a car opens an empty one, removing a car takes its
/// book with it, and nothing a user logs on one car can move another car's
/// countdown. Everything shown is computed from data the user enters (odometer
/// readings, manual records, their own extra items) plus records written when
/// a booking they placed was completed. The app never reads anything from the
/// car itself, and items with no record never show a percentage.
class MaintenanceNotifier extends Notifier<Map<String, MaintenanceBook>> {
  /// This notifier deliberately depends on nothing from the garage.
  ///
  /// The dependency runs the other way — `GarageNotifier` opens and closes a
  /// book as cars come and go, and forwards mileage here — so that the two
  /// cannot form a cycle and so that a garage edit never invalidates a
  /// maintenance write that is already in flight. Providers *derived* from
  /// both (which car the page is showing, a car's due list) sit outside both
  /// notifiers, further down this file.
  @override
  Map<String, MaintenanceBook> build() =>
      ref.read(maintenanceRepositoryProvider).books;

  MaintenanceBook bookFor(String carId) =>
      state[carId] ?? MaintenanceBook.empty(carId);

  /// Opens the empty book a newly registered car starts with. Called by the
  /// garage when a car is saved; harmless to call twice.
  Future<void> openBook(String carId) async {
    _apply(await ref.read(maintenanceRepositoryProvider).createBook(carId));
  }

  Future<void> closeBook(String carId) async {
    await ref.read(maintenanceRepositoryProvider).removeBook(carId);
    state = {
      for (final e in state.entries)
        if (e.key != carId) e.key: e.value,
    };
  }

  /// Records this car's mileage in its book.
  ///
  /// Screens call `GarageNotifier.setOdometer`, which writes the saved car and
  /// then this — one reading, one car, stored in one place, so the garage card
  /// and the maintenance page can never disagree about the same vehicle.
  Future<void> updateOdometer(String carId, int km) async {
    if (km <= 0) return;
    _apply(await ref.read(maintenanceRepositoryProvider)
        .updateOdometer(carId, km));
  }

  Future<void> addRecord(String carId, ServiceRecord record) async {
    _apply(await ref.read(maintenanceRepositoryProvider)
        .addRecord(carId, record));
  }

  Future<void> updateRecord(String carId, ServiceRecord record) async {
    _apply(await ref.read(maintenanceRepositoryProvider)
        .updateRecord(carId, record));
  }

  Future<void> removeRecord(String carId, String recordId) async {
    _apply(await ref.read(maintenanceRepositoryProvider)
        .removeRecord(carId, recordId));
  }

  /// Sets both intervals for one item in a single step, which is how the
  /// manual-entry sheet presents them. A null clears the override and puts the
  /// item back on its default.
  Future<void> setIntervals(
    String carId,
    String itemKey, {
    int? km,
    int? months,
  }) async {
    final repository = ref.read(maintenanceRepositoryProvider);
    await repository.setKmInterval(carId, itemKey, km);
    _apply(await repository.setMonthInterval(carId, itemKey, months));
  }

  Future<void> saveCustomItem(String carId, CustomMaintenanceItem item) async {
    _apply(await ref.read(maintenanceRepositoryProvider)
        .saveCustomItem(carId, item));
  }

  Future<void> removeCustomItem(String carId, String itemId) async {
    _apply(await ref.read(maintenanceRepositoryProvider)
        .removeCustomItem(carId, itemId));
  }

  /// Writes the record a *completed and released* booking earned.
  ///
  /// Only that ending counts. A booking that was cancelled, rejected, refunded
  /// or is still under dispute proves no work was done, so it must never reset
  /// a countdown — the caller decides that by only calling this on
  /// [EscrowState.releasedToWorkshop], and the guards here make a repeat of the
  /// same event a no-op.
  Future<void> logCompletedBooking(ServiceRequest request) async {
    final carId = request.car.id;
    final book = state[carId];
    // An ad-hoc car booked without registering it has no book to write to.
    if (book == null) return;
    if (book.hasRecordForBooking(request.id)) return;

    final itemKey = request.maintenanceItemKey ??
        _itemKeyForCategory(request.offering.categorySlug, request.car);
    if (itemKey == null) return;

    await addRecord(
      carId,
      ServiceRecord(
        // Derived from the booking rather than random, so a duplicate event
        // upserts the same row instead of appending a second one.
        id: derivedGuid('service-record', request.id),
        title: request.offering.name,
        workshop: request.offering.provider.name.en,
        odometerKm: book.projectedOdometerKm() ?? request.car.odometerKm ?? 0,
        date: DateTime.now(),
        itemKey: itemKey,
        bookingId: request.id,
      ),
    );
  }

  /// The schedule line a booked category resets on *this* car, or null when
  /// the category maps to nothing this car actually tracks — an "express
  /// service" booked for an electric car has no engine oil to reset.
  ///
  /// The powertrain comes off the booking's own car rather than the garage:
  /// this notifier stays free of any dependency on the garage (see [build]).
  String? _itemKeyForCategory(String categorySlug, Car car) {
    final type = MaintenanceTypeX.forCategory(categorySlug);
    if (type == null) return null;
    return type.appliesTo(car.powertrain) ? type.key : null;
  }

  void _apply(MaintenanceBook book) =>
      state = {...state, book.carId: book};
}

final maintenanceProvider =
    NotifierProvider<MaintenanceNotifier, Map<String, MaintenanceBook>>(
        MaintenanceNotifier.new);

/// One car's book. Always answers — a registered car with no history yet has
/// an empty book, not a missing one.
final maintenanceBookProvider = Provider.family<MaintenanceBook, String>(
  (ref, carId) =>
      ref.watch(maintenanceProvider)[carId] ?? MaintenanceBook.empty(carId),
);

/// The car the My Car page is showing.
///
/// Defaults to the primary car — switching the default in the garage switches
/// this page with it — and can be pointed at another saved car from the page's
/// own car switcher. Holding an id rather than a `Car` means a car edited or
/// removed elsewhere resolves correctly on the next read.
final selectedMaintenanceCarIdProvider = StateProvider<String?>((ref) => null);

/// The resolved car for the My Car page: the explicit selection when it is
/// still in the garage, the primary car otherwise, null with an empty garage.
final maintenanceCarProvider = Provider<Car?>((ref) {
  final selectedId = ref.watch(selectedMaintenanceCarIdProvider);
  if (selectedId != null) {
    final selected = ref.watch(carByIdProvider(selectedId));
    if (selected != null) return selected;
  }
  return ref.watch(primaryCarProvider);
});

/// The primary car's powertrain, or null when there is no saved car or the
/// owner has not recorded one. Every powertrain-aware screen reads this rather
/// than reaching into the garage itself.
final primaryPowertrainProvider = Provider<Powertrain?>(
  (ref) => ref.watch(primaryCarProvider)?.powertrain,
);

/// True when the saved car is driven by electricity alone.
final isElectricCarProvider = Provider<bool>(
  (ref) => ref.watch(primaryPowertrainProvider)?.isFullyElectric ?? false,
);

/// The computed schedule for one specific car — never a percentage without a
/// record, and only the items that car actually has (no oil change on an EV).
///
/// Everything that shows a countdown for a named car (the garage strip on each
/// card, the home mini card) reads this rather than a shared list, which is
/// what stopped a second car from showing the first car's due dates.
final maintenanceDueForCarProvider = Provider.family<List<DueItem>, String>(
  (ref, carId) => ref.watch(maintenanceRepositoryProvider).dueItems(
        ref.watch(maintenanceBookProvider(carId)),
        powertrain: ref.watch(carByIdProvider(carId))?.powertrain,
      ),
);

/// The schedule for the car the My Car page is showing.
final maintenanceDueProvider = Provider<List<DueItem>>((ref) {
  final car = ref.watch(maintenanceCarProvider);
  if (car == null) return const [];
  return ref.watch(maintenanceDueForCarProvider(car.id));
});

/// The book the My Car page is showing.
final maintenanceBookForSelectedCarProvider = Provider<MaintenanceBook?>((ref) {
  final car = ref.watch(maintenanceCarProvider);
  if (car == null) return null;
  return ref.watch(maintenanceBookProvider(car.id));
});

/// Which car and which schedule line a booking started from.
///
/// Set when the owner taps "Book" on a maintenance item and read by the
/// booking screen, so the request that gets placed knows what it is for. It
/// carries context only — nothing is written to the book until the booking is
/// actually completed and released.
class MaintenanceBookingIntent {
  const MaintenanceBookingIntent({
    required this.carId,
    required this.itemKey,
    required this.title,
  });

  final String carId;
  final String itemKey;

  /// The item's label, so the booking screen can say what this request is for
  /// without re-deriving it.
  final L title;

  @override
  bool operator ==(Object other) =>
      other is MaintenanceBookingIntent &&
      other.carId == carId &&
      other.itemKey == itemKey &&
      other.title == title;

  @override
  int get hashCode => Object.hash(carId, itemKey, title);
}

final maintenanceBookingIntentProvider =
    StateProvider<MaintenanceBookingIntent?>((ref) => null);
