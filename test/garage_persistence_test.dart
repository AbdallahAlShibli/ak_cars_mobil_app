import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ak_cars_mobil_app/app/bootstrap.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

/// Registering a car has to outlive the launch that did it.
///
/// The reported bug: the car form saved, the garage showed the car, and the
/// next cold start came back empty — so the Save button looked like it had
/// never done anything. The mock services stand in for the server's storage
/// as well as its API, and they were keeping the user's own records in a
/// field.
void main() {
  const camry = Car(
    id: 'c1',
    make: 'Toyota',
    model: 'Camry',
    year: 2021,
    nickname: 'Work car',
    trim: 'GLE',
    color: 'White',
    powertrain: Powertrain.hybrid,
    plate: '12345 AB',
    odometerKm: 128450,
    governorate: 'Muscat',
    wilayat: 'Seeb',
  );

  /// One launch of the app over storage that persists between calls — the
  /// same container wiring `main()` builds, minus the widget tree.
  Future<ProviderContainer> launch() async {
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await AppBootstrap.warmUp(container);
    return container;
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('a registered car is still there after a cold start', () async {
    final first = await launch();
    await first.read(garageProvider.notifier).add(camry);

    final second = await launch();
    expect(
      second.read(garageProvider),
      [camry],
      reason:
          'every detail entered on the form has to come back, not just '
          'the make and model',
    );
    expect(second.read(primaryCarProvider), camry);
  });

  test('the mileage entered at registration reaches the next launch', () async {
    final first = await launch();
    await first.read(garageProvider.notifier).add(camry);
    await first.read(garageProvider.notifier).setOdometer(camry.id, 128450);

    final second = await launch();
    expect(second.read(garageProvider).single.odometerKm, 128450);
    // The maintenance book is what every countdown is measured from, so the
    // reading has to survive there too — a restored car with an empty book
    // would have lost history it never actually lost.
    expect(
      second.read(maintenanceBookProvider(camry.id)).currentOdometerKm,
      128450,
    );
  });

  test('an edit made on one launch is what the next one loads', () async {
    final first = await launch();
    await first.read(garageProvider.notifier).add(camry);
    await first
        .read(garageProvider.notifier)
        .update(camry.copyWith(nickname: 'Dad\'s car'));

    final second = await launch();
    expect(second.read(garageProvider).single.nickname, 'Dad\'s car');
  });

  test('a removed car does not come back on the next launch', () async {
    final first = await launch();
    await first.read(garageProvider.notifier).add(camry);
    await first.read(garageProvider.notifier).remove(camry.id);

    final second = await launch();
    expect(second.read(garageProvider), isEmpty);
    expect(second.read(maintenanceProvider), isEmpty);
  });

  test('a fresh install starts with an empty garage', () async {
    expect((await launch()).read(garageProvider), isEmpty);
  });

  test('storage written by an older build does not wedge the launch', () async {
    SharedPreferences.setMockInitialValues({'akcars_garage': 'not json'});
    expect((await launch()).read(garageProvider), isEmpty);
  });
}
