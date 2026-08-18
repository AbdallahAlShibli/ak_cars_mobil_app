import 'package:ak_cars_mobil_app/data/models/car.dart';
import 'package:ak_cars_mobil_app/data/models/challenge.dart';
import 'package:ak_cars_mobil_app/data/models/powertrain.dart';
import 'package:ak_cars_mobil_app/data/repositories/challenge_repository.dart';
import 'package:ak_cars_mobil_app/data/repositories/garage_repository.dart';
import 'package:ak_cars_mobil_app/data/services/challenge_service.dart';
import 'package:ak_cars_mobil_app/data/services/garage_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A failed warm-up must be swallowable.
///
/// `AuthNotifier` treats a post-sign-in warm-up as best-effort, so it has to be
/// able to discard the failure. That only works if `warmUp()` returns a
/// genuine `Future<void>`.
///
/// It used to not. `Future<void> warmUp() => Future.wait([...])` compiles —
/// `void` accepts anything — but the object handed back is still a
/// `Future<List<…>>`, so its runtime type argument is `List<…>`, not `void`.
/// `.catchError((_) {})` then rejected the handler's `null` with "the error
/// handler of Future.catchError must return a value of the future's type": an
/// uncaught error thrown *by the error handler*, standing in for whatever
/// really failed.
///
/// `isA<Future<void>>()` cannot catch this — `void` is a top type, so every
/// future satisfies it. Only actually handling an error does.
void main() {
  group('a failing warmUp can be handled', () {
    test('garage — via catchError', () async {
      final repo = GarageRepositoryImpl(_ThrowingGarage());
      await expectLater(repo.warmUp().catchError((_) {}), completes);
    });

    test('garage — via try/catch, and the reason survives', () async {
      final repo = GarageRepositoryImpl(_ThrowingGarage());
      Object? seen;
      try {
        await repo.warmUp();
      } catch (error) {
        seen = error;
      }
      expect(seen, isA<StateError>(),
          reason: 'the real cause must reach the caller, not be replaced by a '
              'complaint about the error handler');
    });

    test('challenge — via catchError', () async {
      // The one that surfaced this: its warm-up failed, and the swallow threw.
      final repo = ChallengeRepositoryImpl(_ThrowingChallenges());
      await expectLater(repo.warmUp().catchError((_) {}), completes);
    });
  });
}

class _ThrowingGarage implements GarageService {
  Never _fail() => throw StateError('offline');

  @override
  Future<List<Car>> fetchCars() async => _fail();

  @override
  Future<Car> addCar(Car car) async => _fail();

  @override
  Future<void> removeCar(String carId) async => _fail();

  @override
  Future<Car> updateCar(Car car) async => _fail();

  @override
  Future<Car> updatePlate(String carId, String plate) async => _fail();

  @override
  Future<Car> updateOdometer(String carId, int km) async => _fail();

  @override
  Future<List<Car>> setPrimary(String carId) async => _fail();
}

class _ThrowingChallenges implements ChallengeService {
  Never _fail() => throw StateError('offline');

  @override
  Future<ChallengeBoard> fetchBoard({Powertrain? powertrain}) async => _fail();

  @override
  Future<ChallengeBoard> toggleStep(String stepId) async => _fail();

  @override
  Future<ChallengeBoard> completeChallenge({Powertrain? powertrain}) async =>
      _fail();
}
