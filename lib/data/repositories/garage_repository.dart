import '../models/car.dart';
import '../services/garage_service.dart';
import 'warm_cache.dart';

/// The user's saved cars. Registering a car is optional, so every read may
/// legitimately come back empty.
abstract interface class GarageRepository {
  /// Loads the saved cars so [cars] can be read synchronously on the first
  /// frame. Without this the garage state starts empty and a returning user's
  /// cars only exist for as long as the session that created them.
  Future<void> warmUp();

  /// The cars as of the last load or write.
  List<Car> get cars;

  Future<List<Car>> fetchCars();

  Future<Car> addCar(Car car);

  Future<void> removeCar(String carId);

  Future<Car> updateCar(Car car);

  Future<Car> updatePlate(String carId, String plate);

  Future<Car> updateOdometer(String carId, int km);

  Future<List<Car>> setPrimary(String carId);
}

class GarageRepositoryImpl implements GarageRepository {
  GarageRepositoryImpl(this._service);

  final GarageService _service;

  final _cars = WarmCache<List<Car>>(fallback: const []);

  @override
  Future<void> warmUp() => _cars.load(_service.fetchCars);

  @override
  List<Car> get cars => _cars.value;

  @override
  Future<List<Car>> fetchCars() => _cars.load(_service.fetchCars);

  @override
  Future<Car> addCar(Car car) =>
      _store(_service.addCar(car), (cars, saved) => [...cars, saved]);

  @override
  Future<void> removeCar(String carId) async {
    await _service.removeCar(carId);
    _cars.put([
      for (final c in _cars.value)
        if (c.id != carId) c,
    ]);
  }

  @override
  Future<Car> updateCar(Car car) => _store(_service.updateCar(car), _replace);

  @override
  Future<Car> updatePlate(String carId, String plate) =>
      _store(_service.updatePlate(carId, plate), _replace);

  @override
  Future<Car> updateOdometer(String carId, int km) =>
      _store(_service.updateOdometer(carId, km), _replace);

  @override
  Future<List<Car>> setPrimary(String carId) async {
    final updated = await _service.setPrimary(carId);
    _cars.put(updated);
    return updated;
  }

  /// Keeps the warm cache in step with a write that returns a single car.
  Future<Car> _store(
    Future<Car> write,
    List<Car> Function(List<Car> cars, Car saved) apply,
  ) async {
    final saved = await write;
    _cars.put(apply(_cars.value, saved));
    return saved;
  }

  static List<Car> _replace(List<Car> cars, Car saved) => [
        for (final c in cars)
          if (c.id == saved.id) saved else c,
      ];
}
