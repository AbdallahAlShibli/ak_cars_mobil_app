import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_role.dart';
import '../di/providers.dart';
import 'admin_state.dart';
import 'auth_state.dart';

/// Which of the app's three roles (spec §6) this session actually is.
///
/// **Derived from real account facts, never from a local switch.** There used
/// to be a device-local "role switcher" in Settings that let any signed-in
/// account preview any panel — useful for the pilot, but it meant a customer
/// account could open the founder's dispute queue by tapping a row. This now
/// answers the same question the switcher used to ask, but from facts the
/// backend actually decided:
///
/// * [AppRole.founder] — [AuthState.isFounder], decoded off the JWT's role
///   claim (see `jwt_claims.dart`). Nothing else grants this.
/// * [AppRole.workshop] — the signed-in account owns a real
///   [ServiceProvider] (`providerOwnedBy`, keyed on `ownerUserId`, so a
///   workshop's staff member does **not** get this just by being linked to
///   the roster) and that workshop is [ServiceProvider.isApproved]. A
///   pending or rejected application is still [AppRole.customer] — the
///   application's own status lives on the profile screen, not behind a
///   role change.
/// * [AppRole.customer] — everyone else, including a guest.
final activeRoleProvider = Provider<AppRole>((ref) {
  // A workshop's approval can change from the founder's own panel mid-session
  // — `adminRevisionProvider` is what every other provider built on the
  // roster (`rosterProvider`, `pendingApplicationsProvider`, ...) watches for
  // exactly that reason (see `admin_state.dart`); `AdminActions` bumps it
  // after every write. `WarmCacheNotice` covers the other case — a cache
  // refilled wholesale at sign-in — which is why this registers there too.
  ref.watch(adminRevisionProvider);
  ref.read(warmCacheNoticeProvider).register(ref);
  if (ref.watch(authProvider).isFounder) return AppRole.founder;

  final userId = ref.watch(authProvider).profile?.id;
  if (userId != null) {
    final owned =
        ref.watch(serviceMarketplaceRepositoryProvider).providerOwnedBy(userId);
    if (owned != null && owned.isApproved) return AppRole.workshop;
  }

  return AppRole.customer;
});
