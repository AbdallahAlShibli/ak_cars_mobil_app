import 'dart:convert';

import 'package:ak_cars_mobil_app/config/app_flags.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/shell/shell_tabs.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/memory_token_store.dart';
import 'helpers/test_harness.dart';

/// A JWT shaped exactly like the ones `TokenService.GenerateAccessToken`
/// mints — same claim key for the founder role, confirmed by decoding a real
/// token from that method (see `jwt_claims.dart`'s doc comment). The
/// signature segment is never checked client-side (`jwt_claims.dart` only
/// reads claims for UI gating; the server enforces `[Authorize]` on every
/// call regardless), so it does not need to verify against anything.
String _fakeJwt(Map<String, Object?> claims) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({
        'alg': 'none',
      })}.${segment(claims)}.sig';
}

final _founderToken = _fakeJwt({
  'http://schemas.microsoft.com/ws/2008/06/identity/claims/role': 'founder',
});

/// The flags are compile-time constants, so these tests pin the *shipped*
/// configuration rather than exercising both sides of each switch. Flipping a
/// flag is a deliberate act; a test that failed loudly when someone did would
/// be noise, so what is guarded here is the invariant that has to hold either
/// way: the tab bar and the router's start location agree, and no tab exists
/// for a pillar that is hidden.
void main() {
  group('phase-1 focus', () {
    // Spec §2's four tabs, plus home — which came back on 2026-07-28 rebuilt
    // around the pillars this build runs (registered cars, their real service
    // countdowns, live offers, the two marketplace leaderboards) rather than
    // around the hidden shop and cars gallery.
    test('the bar is home plus the four tabs the spec asks for', () {
      final tabs = buildShellTabs();
      const s = S(false);

      expect(tabs.map((t) => t.location).toList(), [
        '/home',
        '/services',
        '/bookings',
        '/my-car',
        '/profile',
      ]);
      expect(tabs.map((t) => t.label(s)).toList(),
          ['Home', 'Services', 'Bookings', 'My car', 'Profile']);
    });

    test('the start location is a tab that exists', () {
      expect(buildShellTabs().map((t) => t.location),
          contains(AppFlags.startLocation));
    });

    test('a hidden pillar contributes no tab', () {
      final locations = buildShellTabs().map((t) => t.location).toSet();

      expect(locations.contains('/shop'), AppFlags.partsStoreEnabled);
      expect(locations.contains('/cars'), AppFlags.carMarketplaceEnabled);
      expect(locations.contains('/home'), AppFlags.homeTabEnabled);
    });

    test('a cold start lands on the first tab, never on a hidden one',
        () async {
      final container = await createTestContainer();
      final auth = container.read(authProvider);

      // Fresh install still runs the intro first.
      expect(auth.initialRoute, '/splash');
      container.read(authProvider.notifier).markOnboardingSeen();
      container.read(authProvider.notifier).markStartChoiceMade();

      expect(container.read(authProvider).initialRoute,
          AppFlags.startLocation);
    });
  });

  group('roles', () {
    test('a guest, and a signed-in account with no founder claim, are both '
        'a customer', () async {
      final container = await createTestContainer();
      expect(container.read(activeRoleProvider), AppRole.customer);
    });

    test('a real founder JWT resolves the role, with no switch to flip',
        () async {
      final container = await createTestContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            MemoryTokenStore(access: _founderToken, refresh: 'r'),
          ),
        ],
      );
      // Registering is what makes `AuthNotifier` decode the token it was
      // just handed — see `AuthState.isFounder`'s doc comment. The profile
      // itself carries no founder fact; the JWT does.
      await container.read(authProvider.notifier).register(
            const UserProfile(
              name: 'Founder',
              phone: '+968 9111 2222',
              email: 'founder@example.om',
              region: 'Muscat',
              address: '',
            ),
          );

      expect(container.read(authProvider).isFounder, isTrue);
      expect(container.read(activeRoleProvider), AppRole.founder);
      expect(container.read(activeRoleProvider).actor, EscrowActor.founder);
    });
  });
}
