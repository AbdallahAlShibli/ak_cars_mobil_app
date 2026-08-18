import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/escrow.dart';
import '../data/models/proof_of_work.dart';
import '../data/models/quote.dart';
import '../data/models/service_request.dart';
import '../di/providers.dart';
import 'requests_state.dart';

/// Every booking on the marketplace — the two operator panels' queue.
///
/// **Deliberately not `requestsProvider`.** That one is the signed-in
/// customer's own bookings, and it must stay that way: the demo world seeds
/// forty bookings belonging to other people, and putting them in a customer's
/// "My bookings" tab would be the app claiming they are theirs. An operator is
/// asking a different question with different authority, so it gets its own
/// list.
///
/// The two overlap by exactly one booking: the one the person holding the
/// phone placed themselves. [_merged] resolves that in the customer list's
/// favour, because that is the copy the session has been mutating.
class OperatorQueueNotifier extends Notifier<List<ServiceRequest>> {
  /// The marketplace's bookings as last loaded. Replaced wholesale by
  /// [refresh] and patched in place by [fire].
  List<ServiceRequest> _marketplace = const [];

  @override
  List<ServiceRequest> build() {
    // Watched, not read: a booking the user places, or a transition they fire
    // from a customer screen, has to appear in the operator queue without
    // anyone remembering to refresh it.
    final mine = ref.watch(requestsProvider);
    return _merged(mine);
  }

  List<ServiceRequest> _merged(List<ServiceRequest> mine) {
    final byId = <String, ServiceRequest>{
      for (final r in _marketplace) r.id: r,
      for (final r in mine) r.id: r,
    };
    final all = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(all);
  }

  /// Loads the marketplace queue. Called from bootstrap, and again whenever a
  /// panel wants to be sure it is current.
  Future<void> refresh() async {
    _marketplace = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .fetchOperatorQueue();
    state = _merged(ref.read(requestsProvider));
  }

  /// Fires one escrow transition from an operator panel.
  ///
  /// When the booking is also the user's own, this **delegates** to
  /// [RequestsNotifier.fire] rather than duplicating it — that path carries
  /// the customer-side consequences of a release (the maintenance record, the
  /// review unlock, the notifications), and a second implementation here would
  /// be a second place for those to be forgotten.
  ///
  /// For everybody else's bookings only the transition itself applies: the
  /// person holding this phone is not the customer, so nothing is written to
  /// their car's history and nothing is announced to them.
  Future<ServiceRequest?> fire(
    String id,
    EscrowEvent event, {
    required EscrowActor actor,
    ProofOfWork? proof,
    String? disputeNote,
    String? slot,
  }) async {
    final mine = ref.read(requestsProvider);
    if (mine.any((r) => r.id == id)) {
      return ref.read(requestsProvider.notifier).fire(
            id,
            event,
            actor: actor,
            proof: proof,
            disputeNote: disputeNote,
            slot: slot,
          );
    }

    final current = _marketplace.firstWhereOrNull((r) => r.id == id);
    if (current == null) return null;
    // The same pre-checks the customer path makes, for the same reason: a
    // stale screen firing a stale button is an ordinary race, not a crash.
    final allowed = current.escrow.transitions
        .any((t) => t.event == event && t.actor == actor);
    if (!allowed) return null;
    if (event == EscrowEvent.submitProof &&
        !current.proofSatisfiesRules(proof)) {
      return null;
    }

    final updated = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .applyEscrowEvent(
          id,
          event,
          actor: actor,
          proof: proof,
          disputeNote: disputeNote,
          slot: slot,
        );
    _replace(updated);

    // The machine's automatic hand-offs. Same three as the customer path, and
    // for the same reason: a booking must not sit visibly parked in a state
    // that exists only so the app can move it along.
    return switch (updated.escrow) {
      EscrowState.quoteAccepted => fire(id, EscrowEvent.proceedToPayment,
          actor: EscrowActor.system),
      EscrowState.fundsHeld when updated.type == BookingType.customQuote =>
        fire(id, EscrowEvent.autoAcceptQuotedJob, actor: EscrowActor.system),
      EscrowState.proofSubmitted => fire(id, EscrowEvent.handOffForApproval,
          actor: EscrowActor.system),
      _ => updated,
    };
  }

  /// The workshop's itemised answer to a part request, for a booking that is
  /// not the operator's own.
  Future<ServiceRequest?> submitQuote(String id, Quote quote) async {
    final mine = ref.read(requestsProvider);
    if (mine.any((r) => r.id == id)) {
      return ref.read(requestsProvider.notifier).submitQuote(id, quote);
    }
    final updated = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .submitQuote(id, quote);
    _replace(updated);
    return updated;
  }

  void _replace(ServiceRequest updated) {
    _marketplace = [
      for (final r in _marketplace)
        if (r.id == updated.id) updated else r,
    ];
    state = _merged(ref.read(requestsProvider));
  }

  /// Drops the marketplace-wide half of the queue on sign-out.
  ///
  /// [build] watches `requestsProvider`, so clearing *that* does make this
  /// notifier re-run — but [_marketplace] is a plain field on this instance,
  /// not derived state, and a rebuild does not reset it. Without this, an
  /// operator's queue kept showing every other account's bookings (fetched by
  /// [refresh], most recently at this session's own sign-in) until the next
  /// signed-in [refresh] happened to overwrite it — visible to whoever the
  /// operator panels' route guard let through in between.
  void clear() {
    _marketplace = const [];
    state = _merged(ref.read(requestsProvider));
  }
}

final operatorQueueProvider =
    NotifierProvider<OperatorQueueNotifier, List<ServiceRequest>>(
  OperatorQueueNotifier.new,
);
