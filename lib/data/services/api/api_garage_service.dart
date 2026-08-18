import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../models/car.dart';
import '../garage_service.dart';

/// The signed-in user's saved cars, over REST (§12).
class ApiGarageService implements GarageService {
  const ApiGarageService(this._client);

  final ApiClient _client;

  @override
  Future<List<Car>> fetchCars() async =>
      (await _client.getList(ApiEndpoints.garage)).map(Car.fromJson).toList();

  @override
  Future<Car> addCar(Car car) async =>
      Car.fromJson(await _client.post(ApiEndpoints.garage, body: car.toJson()));

  @override
  Future<void> removeCar(String carId) =>
      _client.delete(ApiEndpoints.garageVehicle(carId));

  @override
  Future<Car> updateCar(Car car) async => Car.fromJson(
        await _client.put(
          ApiEndpoints.garageVehicle(car.id),
          body: car.toJson(),
        ),
      );

  @override
  Future<Car> updatePlate(String carId, String plate) async => Car.fromJson(
        await _client.patch(
          ApiEndpoints.garageVehicle(carId),
          body: {'plate': plate},
        ),
      );

  @override
  Future<Car> updateOdometer(String carId, int km) async => Car.fromJson(
        await _client.patch(
          ApiEndpoints.garageVehicle(carId),
          body: {'odometerKm': km},
        ),
      );

  @override
  Future<List<Car>> setPrimary(String carId) async =>
      (await _client.postList(ApiEndpoints.primaryVehicle(carId)))
          .map(Car.fromJson)
          .toList();
}
