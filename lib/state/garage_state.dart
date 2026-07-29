import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/car.dart';
import '../di/providers.dart';
import 'maintenance_state.dart';

/// The user's saved cars.
///
/// Registering a car is optional — every screen must stay usable with an
/// empty garage.
///
/// Each mutation applies locally first and then persists. The screens call
/// these without awaiting and read the result on the next frame, so an
/// await-then-assign order would drop a frame and, on the plate editor,
/// visibly lag the field.
class GarageNotifier extends Notifier<List<Car>> {
  @override
  List<Car> build() =>
      // Warmed at bootstrap, so a returning user's cars are on the first
      // frame. This used to start empty, which made the repository
      // write-only: nothing ever read the saved cars back.
      ref.watch(garageRepositoryProvider).cars;

  Future<void> add(Car car) async {
    state = [...state, car];
    await ref.read(garageRepositoryProvider).addCar(car);
    // Every registered car owns its own maintenance schedule, opened empty
    // here — the right default items for its powertrain and no history it
    // did not have.
    await ref.read(maintenanceProvider.notifier).openBook(car.id);
  }

  Future<void> remove(String carId) async {
    state = state.where((c) => c.id != carId).toList();
    await ref.read(garageRepositoryProvider).removeCar(carId);
    await ref.read(maintenanceProvider.notifier).closeBook(carId);
  }

  /// Puts a removed car back where it was — the undo action on the garage's
  /// swipe-to-delete, so a mis-swipe is not a re-typing job.
  ///
  /// The maintenance book does not come back with it: removing the car deleted
  /// it, and re-deriving one would be inventing history. Undo restores the car,
  /// not its past.
  Future<void> restore(Car car, int index) async {
    final at = index.clamp(0, state.length);
    state = [...state]..insert(at, car);
    await ref.read(garageRepositoryProvider).addCar(car);
    await ref.read(maintenanceProvider.notifier).openBook(car.id);
    if (at == 0) await setPrimary(car.id);
  }

  /// Replaces a saved car with an edited copy.
  Future<void> update(Car car) async {
    state = [
      for (final c in state)
        if (c.id == car.id) car else c,
    ];
    await ref.read(garageRepositoryProvider).updateCar(car);
  }

  Future<void> setPrimary(String carId) async {
    final car = state.firstWhereOrNull((c) => c.id == carId);
    if (car == null) return;
    state = [car, ...state.where((c) => c.id != carId)];
    await ref.read(garageRepositoryProvider).setPrimary(carId);
  }

  Future<void> setPlate(String carId, String plate) async {
    state = [
      for (final c in state)
        if (c.id == carId) c.copyWith(plate: plate) else c,
    ];
    await ref.read(garageRepositoryProvider).updatePlate(carId, plate);
  }

  /// Records this car's mileage — on the car *and* in its maintenance book.
  ///
  /// The single entry point for mileage. Two stores held the same fact before
  /// this, and they drifted: the garage card and the maintenance page could
  /// show different readings for the same vehicle, and the maintenance one
  /// belonged to whichever car happened to be default at the time.
  Future<void> setOdometer(String carId, int km) async {
    if (km <= 0) return;
    state = [
      for (final c in state)
        if (c.id == carId) c.copyWith(odometerKm: km) else c,
    ];
    await ref.read(garageRepositoryProvider).updateOdometer(carId, km);
    await ref.read(maintenanceProvider.notifier).updateOdometer(carId, km);
  }
}

final garageProvider =
    NotifierProvider<GarageNotifier, List<Car>>(GarageNotifier.new);

/// Primary car = first in the garage, or null when browsing without one.
final primaryCarProvider =
    Provider<Car?>((ref) => ref.watch(garageProvider).firstOrNull);

/// A single saved car by id, or null once it has been deleted. The edit
/// screen watches this so it closes itself instead of editing a ghost.
final carByIdProvider = Provider.family<Car?, String>(
  (ref, id) => ref.watch(garageProvider).firstWhereOrNull((c) => c.id == id),
);
