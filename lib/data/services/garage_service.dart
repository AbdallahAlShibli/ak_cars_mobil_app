import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';
import '../models/car.dart';
import 'mock_service_base.dart';
import 'prefs_collection.dart';

/// The user's saved cars.
///
/// Registering a car is optional — the app must stay usable with an empty
/// garage — so every read here can legitimately return an empty list.
///
/// Phase 2: implement `RestGarageService` against `/user/vehicles`.
abstract interface class GarageService {
  Future<List<Car>> fetchCars();

  Future<Car> addCar(Car car);

  Future<void> removeCar(String carId);

  /// Replaces a saved car wholesale. Optional details can be cleared this
  /// way, which a field-by-field patch could not express.
  Future<Car> updateCar(Car car);

  Future<Car> updatePlate(String carId, String plate);

  Future<Car> updateOdometer(String carId, int km);

  /// Promotes a car to primary (first in the list).
  Future<List<Car>> setPrimary(String carId);
}

/// Stands in for the server *and* the vehicles table it would keep them in.
///
/// The saved cars are written to SharedPreferences rather than held in a
/// field: in memory, a registered car existed only for the launch that
/// created it, so a user who added their Camry came back the next morning to
/// an empty garage — and to the rest of the app behaving as if they had never
/// registered one, since the start-choice flag *did* survive. Same reasoning
/// as `MockAuthService`; the REST implementation reads the same cars back
/// from `/user/vehicles`.
class MockGarageService with MockServiceBase implements GarageService {
  MockGarageService({required this.config, required SharedPreferences prefs})
    : _store = PrefsCollection<Car>(
        prefs: prefs,
        key: AppConstants.prefsGarage,
        fromJson: Car.fromJson,
        toJson: (car) => car.toJson(),
      ) {
    _cars.addAll(_store.load());
  }

  @override
  final AppConfig config;

  final PrefsCollection<Car> _store;

  /// Seeded from the device on construction — empty only on a fresh install.
  final List<Car> _cars = [];

  @override
  Future<List<Car>> fetchCars() => respond(List<Car>.unmodifiable(_cars));

  @override
  Future<Car> addCar(Car car) {
    _cars.add(car);
    return _persist(car);
  }

  @override
  Future<void> removeCar(String carId) {
    _cars.removeWhere((c) => c.id == carId);
    return _persist(null);
  }

  @override
  Future<Car> updateCar(Car car) {
    _cars[_indexOf(car.id)] = car;
    return _persist(car);
  }

  @override
  Future<Car> updatePlate(String carId, String plate) {
    final index = _indexOf(carId);
    final updated = _cars[index].copyWith(plate: plate);
    _cars[index] = updated;
    return _persist(updated);
  }

  @override
  Future<Car> updateOdometer(String carId, int km) {
    final index = _indexOf(carId);
    final updated = _cars[index].copyWith(odometerKm: km);
    _cars[index] = updated;
    return _persist(updated);
  }

  @override
  Future<List<Car>> setPrimary(String carId) {
    final car = _cars.removeAt(_indexOf(carId));
    _cars.insert(0, car);
    // Order is the fact being written here: primary = first, so the stored
    // list has to come back in the same order it was saved in.
    return _persist(List<Car>.unmodifiable(_cars));
  }

  int _indexOf(String carId) {
    final index = _cars.indexWhere((c) => c.id == carId);
    if (index < 0) throw NotFoundException('Car $carId not found');
    return index;
  }

  /// The single write path: every mutation above ends here, so no change can
  /// reach memory without also reaching the device.
  Future<T> _persist<T>(T result) {
    _store.save(_cars);
    return respond(result);
  }
}
