import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ak_cars_mobil_app/config/app_flags.dart';
import 'package:ak_cars_mobil_app/app/bootstrap.dart';
import 'package:ak_cars_mobil_app/core/constants/app_constants.dart';
import 'package:ak_cars_mobil_app/data/models/user_profile.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

/// The intro is a *first launch* thing. It used to replay on every cold start:
/// the router always began at `/splash`, and the two flags that were supposed
/// to prevent that were only ever held in memory.
///
/// These tests restart the app the only way that proves it — by throwing the
/// container away and building a fresh one over the same SharedPreferences,
/// which is what a real cold start does.
void main() {
  const profile = UserProfile(
    name: 'Salim',
    phone: '+96890000000',
    email: 'salim@example.com',
    region: 'Muscat',
    address: 'Al Khuwair',
  );

  /// A cold start: new container, same stored preferences.
  Future<ProviderContainer> relaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.notifier).restore();
    return container;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('first run', () {
    test('a fresh install opens on the splash', () async {
      final container = await relaunch();

      expect(container.read(authProvider).onboardingSeen, isFalse);
      expect(container.read(authProvider).initialRoute, '/splash');
    });

    test('finishing onboarding survives a cold start', () async {
      final first = await relaunch();
      first.read(authProvider.notifier).markOnboardingSeen();
      expect(first.read(authProvider).initialRoute, '/start-choice');

      // The bug: this came back as /splash, so the tour ran again.
      final second = await relaunch();
      expect(second.read(authProvider).onboardingSeen, isTrue);
      expect(second.read(authProvider).initialRoute, '/start-choice');
    });

    test('answering the car question sends later launches to home', () async {
      final first = await relaunch();
      first.read(authProvider.notifier).markOnboardingSeen();
      first.read(authProvider.notifier).markStartChoiceMade();

      final second = await relaunch();
      expect(second.read(authProvider).initialRoute, AppFlags.startLocation);
    });

    test('registering counts as having finished the intro', () async {
      final first = await relaunch();
      await first.read(authProvider.notifier).register(profile);

      final second = await relaunch();
      expect(second.read(authProvider).initialRoute, AppFlags.startLocation);
    });

    test('a registered user is still registered after a cold start', () async {
      final first = await relaunch();
      await first.read(authProvider.notifier).register(profile);
      expect(first.read(authProvider).isRegistered, isTrue);

      // The bug: the profile lived in a field on the mock service, so this
      // came back anonymous and the next checkout re-ran the sign-up form.
      final second = await relaunch();
      expect(second.read(authProvider).isRegistered, isTrue);
      expect(second.read(authProvider).profile?.name, 'Salim');
    });

    test('signing out clears the identity but never replays the intro',
        () async {
      final first = await relaunch();
      await first.read(authProvider.notifier).register(profile);
      await first.read(authProvider.notifier).signOut();

      final second = await relaunch();
      expect(second.read(authProvider).isRegistered, isFalse);
      expect(second.read(authProvider).initialRoute, AppFlags.startLocation);
    });

    test('a corrupt stored profile does not wedge the launch', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefsOnboardingSeen: true,
        AppConstants.prefsStartChoiceMade: true,
        AppConstants.prefsProfile: 'not json',
      });

      final container = await relaunch();
      expect(container.read(authProvider).isRegistered, isFalse);
      expect(container.read(authProvider).initialRoute, AppFlags.startLocation);
    });

    test('bootstrap restores the session before the first frame', () async {
      final seeded = await relaunch();
      await seeded.read(authProvider.notifier).register(profile);

      // The real launch path, rather than calling restore() by hand.
      final container = await AppBootstrap.createContainer();
      addTearDown(container.dispose);

      expect(container.read(authProvider).isRegistered, isTrue);
      expect(container.read(authProvider).initialRoute, AppFlags.startLocation);
    });
  });
}
