import 'package:ak_cars_mobil_app/data/models/car.dart';
import 'package:ak_cars_mobil_app/data/services/garage_service.dart';
import 'package:ak_cars_mobil_app/data/services/session_routed_services.dart';
import 'package:ak_cars_mobil_app/data/services/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A guest's garage.
///
/// Rule 3 of first launch asks for a car as step 3 of 3 — before any account
/// exists — while `GET/POST /user/vehicles` is `[Authorize]`d. Binding the
/// garage straight to the REST service therefore answered `401` on the app's
/// very first interaction, told the user their car was saved anyway, and lost
/// it by the next cold start. These tests pin the arrangement that fixes it.
void main() {
  group('SessionGarageService', () {
    test('a guest writes to the device, never to the API', () async {
      final local = _FakeGarage();
      final remote = _FakeGarage();
      final garage = SessionGarageService(local, remote, _Tokens(false));

      await garage.addCar(_car('a'));

      expect(local.cars.map((c) => c.id), ['a']);
      expect(remote.cars, isEmpty,
          reason: 'a guest has no session, so this could only have been a 401');
      expect(await garage.fetchCars(), hasLength(1),
          reason: 'and the guest must be able to read their own car back');
    });

    test('a signed-in user writes to the API, never to the device', () async {
      final local = _FakeGarage();
      final remote = _FakeGarage();
      final garage = SessionGarageService(local, remote, _Tokens(true));

      await garage.addCar(_car('a'));

      expect(remote.cars.map((c) => c.id), ['a']);
      expect(local.cars, isEmpty);
    });

    test('an unreadable token store routes to the device, not the API',
        () async {
      final local = _FakeGarage();
      final remote = _FakeGarage();
      final garage = SessionGarageService(local, remote, _Tokens.broken());

      await garage.addCar(_car('a'));

      // The safe guess when the keystore will not answer: a local write is
      // adopted at the next sign-in, whereas a remote write for a session that
      // turned out not to exist is a 401 and the user's car on the floor.
      expect(local.cars.map((c) => c.id), ['a']);
      expect(remote.cars, isEmpty);
    });

    test('registering hands the guest\'s cars to the server, ids intact',
        () async {
      final local = _FakeGarage();
      final remote = _FakeGarage();
      final tokens = _Tokens(false);
      final garage = SessionGarageService(local, remote, tokens);

      await garage.addCar(_car('a'));
      await garage.addCar(_car('b'));

      tokens.signedIn = true;
      await garage.adoptGuestData();

      // Ids survive the trip — `AddVehicleCommand` honours the one the client
      // chose, which is what keeps each maintenance book attached to its car.
      expect(remote.cars.map((c) => c.id), ['a', 'b']);
      expect(local.cars, isEmpty, reason: 'the device copy is handed over, '
          'not duplicated — otherwise it would be re-adopted every sign-in');
      expect(await garage.fetchCars(), hasLength(2));
    });

    test('a failed hand-over keeps the device copy for the next attempt',
        () async {
      final local = _FakeGarage();
      final remote = _FakeGarage()..failWrites = true;
      final garage = SessionGarageService(local, remote, _Tokens(false));

      await garage.addCar(_car('a'));

      await expectLater(garage.adoptGuestData(), throwsA(isA<Exception>()));
      expect(local.cars.map((c) => c.id), ['a'],
          reason: 'clearing before the upload lands is how data goes missing');
    });

    test('nothing to adopt is not an error', () async {
      final garage =
          SessionGarageService(_FakeGarage(), _FakeGarage(), _Tokens(true));
      await expectLater(garage.adoptGuestData(), completes);
    });
  });
}

Car _car(String id) => Car(id: id, make: 'Toyota', model: 'Camry', year: 2020);

/// Overrides only [hasSession] — the base constructor's `FlutterSecureStorage`
/// is never touched, so this needs no platform channel.
class _Tokens extends TokenStore {
  _Tokens(this.signedIn);

  _Tokens.broken() : signedIn = null;

  /// Null stands for a store that throws: no platform channel, a locked
  /// keystore, a keychain refusing on a restored backup.
  bool? signedIn;

  @override
  Future<bool> hasSession() async {
    final answer = signedIn;
    if (answer == null) throw Exception('keystore unavailable');
    return answer;
  }
}

class _FakeGarage implements GarageService {
  final List<Car> cars = [];
  bool failWrites = false;

  @override
  Future<List<Car>> fetchCars() async => List.unmodifiable(cars);

  @override
  Future<Car> addCar(Car car) async {
    if (failWrites) throw Exception('offline');
    cars.add(car);
    return car;
  }

  @override
  Future<void> removeCar(String carId) async =>
      cars.removeWhere((c) => c.id == carId);

  @override
  Future<Car> updateCar(Car car) async => car;

  @override
  Future<Car> updatePlate(String carId, String plate) async => _byId(carId);

  @override
  Future<Car> updateOdometer(String carId, int km) async => _byId(carId);

  @override
  Future<List<Car>> setPrimary(String carId) async => List.unmodifiable(cars);

  Car _byId(String id) => cars.firstWhere((c) => c.id == id);
}
