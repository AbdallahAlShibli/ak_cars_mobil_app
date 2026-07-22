import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/service_request.dart';
import '../di/providers.dart';
import 'notifications_state.dart';

/// Booked services, newest first.
class RequestsNotifier extends Notifier<List<ServiceRequest>> {
  final List<Timer> _timers = [];

  @override
  List<ServiceRequest> build() {
    ref.onDispose(() {
      for (final t in _timers) {
        t.cancel();
      }
    });
    return const [];
  }

  /// Places a booking: the repository prices and stores it, the inbox is
  /// told, and — in staging only — the simulated provider starts working.
  Future<ServiceRequest> place(CreateServiceRequestDraft draft) async {
    final repository = ref.read(serviceMarketplaceRepositoryProvider);
    final request = await repository.createRequest(draft);
    state = [request, ...state];

    ref.read(notificationsProvider.notifier).adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyRequestPlaced(request),
        );

    if (ref.read(appConfigProvider).simulateProviderLifecycle) {
      _simulateProviderLifecycle(request.id);
    }
    return request;
  }

  /// Moves a request one step forward. Never overrides a terminal status.
  ///
  /// Used by the demo button and the simulated provider today; in production
  /// this is what a pushed status event will call.
  Future<void> advance(String id) async {
    final current = state.firstWhereOrNull((r) => r.id == id);
    final next = current?.status.next;
    if (current == null || next == null) return;

    final updated = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .updateRequestStatus(id, next);
    _replace(updated);

    ref.read(notificationsProvider.notifier).adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyRequestStatus(updated, next),
        );
  }

  /// Sets a status directly (customer approval, dispute).
  Future<void> setStatus(String id, RequestStatus status) async {
    final updated = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .updateRequestStatus(id, status);
    _replace(updated);
  }

  void _replace(ServiceRequest updated) => state = [
        for (final r in state)
          if (r.id == updated.id) updated else r,
      ];

  /// Staging stand-in for the provider portal: accepts after a few seconds,
  /// starts work, then submits completion proof. Delete this once the backend
  /// pushes real status events — see [AppConfig.simulateProviderLifecycle].
  void _simulateProviderLifecycle(String requestId) {
    for (final seconds in const [6, 18, 35]) {
      _timers.add(
        Timer(Duration(seconds: seconds), () => advance(requestId)),
      );
    }
  }
}

final requestsProvider =
    NotifierProvider<RequestsNotifier, List<ServiceRequest>>(
        RequestsNotifier.new);

/// The request the tracking card follows: the first that is not yet complete.
final activeRequestProvider = Provider<ServiceRequest?>((ref) {
  for (final r in ref.watch(requestsProvider)) {
    if (r.status != RequestStatus.completed) return r;
  }
  return null;
});
