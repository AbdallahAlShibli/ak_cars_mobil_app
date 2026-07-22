import '../../config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../models/car.dart';
import 'mock_service_base.dart';

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

class MockGarageService with MockServiceBase implements GarageService {
  MockGarageService({required this.config});

  @override
  final AppConfig config;

  /// Starts empty: a fresh install has no saved cars.
  final List<Car> _cars = [];

  @override
  Future<List<Car>> fetchCars() => respond(List<Car>.unmodifiable(_cars));

  @override
  Future<Car> addCar(Car car) {
    _cars.add(car);
    return respond(car);
  }

  @override
  Future<void> removeCar(String carId) {
    _cars.removeWhere((c) => c.id == carId);
    return respond(null);
  }

  @override
  Future<Car> updateCar(Car car) {
    _cars[_indexOf(car.id)] = car;
    return respond(car);
  }

  @override
  Future<Car> updatePlate(String carId, String plate) {
    final index = _indexOf(carId);
    final updated = _cars[index].copyWith(plate: plate);
    _cars[index] = updated;
    return respond(updated);
  }

  @override
  Future<Car> updateOdometer(String carId, int km) {
    final index = _indexOf(carId);
    final updated = _cars[index].copyWith(odometerKm: km);
    _cars[index] = updated;
    return respond(updated);
  }

  @override
  Future<List<Car>> setPrimary(String carId) {
    final car = _cars.removeAt(_indexOf(carId));
    _cars.insert(0, car);
    return respond(List<Car>.unmodifiable(_cars));
  }

  int _indexOf(String carId) {
    final index = _cars.indexWhere((c) => c.id == carId);
    if (index < 0) throw NotFoundException('Car $carId not found');
    return index;
  }
}
