import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/service_provider.dart';
import '../data/models/workshop_earnings.dart';
import '../data/models/workshop_metrics.dart';
import '../di/providers.dart';
import 'auth_state.dart';
import 'operator_queue_state.dart';
import 'reviews_state.dart';

/// Which workshop the person driving the workshop panel *is*.
///
/// Two ways to be one, and the panel has to tell them apart:
///
/// * **A real workshop account** — it registered (§11), so it owns a
///   [ServiceProvider] and this returns that. Everything the panel shows is
///   genuinely theirs.
/// * **The pilot's role switcher** — someone flipped the role in Settings on an
///   account that never applied. There is no workshop to be, so this falls
///   back to the first approved one on the marketplace and
///   [isStandingInForDemo] goes true, which is what the panel's banner reads.
///
/// The fallback is announced rather than silent. A panel that quietly shows
/// somebody else's earnings as if they were yours is the kind of thing that
/// gets believed.
final activeWorkshopProvider = Provider<ServiceProvider?>((ref) {
  final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
  final userId = ref.watch(authProvider).profile?.id;
  final owned = userId == null ? null : marketplace.providerOwnedBy(userId);
  if (owned != null) return owned;
  final approved = marketplace.visibleProviders;
  return approved.isEmpty ? null : approved.first;
});

/// True when [activeWorkshopProvider] is standing in for a workshop this
/// account does not own — the pilot's demo path.
final isStandingInForDemoProvider = Provider<bool>((ref) {
  final userId = ref.watch(authProvider).profile?.id;
  if (userId == null) return true;
  return ref.watch(serviceMarketplaceRepositoryProvider)
          .providerOwnedBy(userId) ==
      null;
});

/// The active workshop's jobs, out of the whole marketplace queue.
final workshopJobsProvider = Provider((ref) {
  final workshop = ref.watch(activeWorkshopProvider);
  final queue = ref.watch(operatorQueueProvider);
  if (workshop == null) return queue.take(0).toList(growable: false);
  return [
    for (final r in queue)
      if (r.offering.provider.id == workshop.id) r,
  ];
});

/// The active workshop's earnings (§3).
///
/// Computed in the repository, not here and not in the widget — this provider
/// only decides *which* workshop and *which* bookings to hand it (§14).
final workshopEarningsProvider = Provider<WorkshopEarnings>((ref) {
  final workshop = ref.watch(activeWorkshopProvider);
  if (workshop == null) return WorkshopEarnings.empty;
  return ref.watch(serviceMarketplaceRepositoryProvider).earningsFor(
        workshop.id,
        ref.watch(operatorQueueProvider),
      );
});

/// The active workshop's derived performance figures (§4).
final workshopMetricsProvider = Provider<WorkshopMetrics>((ref) {
  final workshop = ref.watch(activeWorkshopProvider);
  if (workshop == null) return WorkshopMetrics.empty;
  return ref.watch(serviceMarketplaceRepositoryProvider).metricsFor(
        workshop.id,
        ref.watch(operatorQueueProvider),
        ref.watch(reviewsProvider),
      );
});
