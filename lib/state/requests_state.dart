import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_flags.dart';
import '../core/error/app_exception.dart';
import '../data/models/car.dart';
import '../data/models/escrow.dart';
import '../data/models/proof_of_work.dart';
import '../data/models/quote.dart';
import '../data/models/service_request.dart';
import '../di/providers.dart';
import 'maintenance_state.dart';
import 'notifications_state.dart';
import 'role_state.dart';

/// Booked services, newest first — and the only thing allowed to move one
/// through the escrow state machine.
///
/// Every mutation goes through [fire], which names the event and the acting
/// party; the transition table in `escrow.dart` decides whether it happens.
/// Screens never set a state directly, so no screen can invent a transition
/// the pilot's rules do not allow.
class RequestsNotifier extends Notifier<List<ServiceRequest>> {
  final List<Timer> _timers = [];

  /// Whether this notifier has been torn down. [load] is awaited across a
  /// network call and assigns `state` afterwards, so without this a container
  /// disposed mid-load — a sign-out, a hot restart — makes it write to a dead
  /// notifier. Same guard, same reason, as [ReviewsNotifier]'s.
  bool _disposed = false;

  @override
  List<ServiceRequest> build() {
    ref.onDispose(() {
      _disposed = true;
      for (final t in _timers) {
        t.cancel();
      }
    });
    return const [];
  }

  /// Loads the signed-in customer's own bookings from the server.
  ///
  /// Starts empty and is filled by [SessionRefresh] — at sign-in, and at boot
  /// for a session that was already stored. Deliberately *not* started from
  /// [build]: this list is mutated optimistically by [place] and [fire] while
  /// the user works, and a fetch begun on some earlier frame landing on top of
  /// that would silently undo a transition they just watched happen.
  ///
  /// `GET /service-marketplace/requests` is `[Authorize]`d, so for a guest it
  /// can only answer `401`. Guarded rather than asked, exactly as
  /// [NotificationsNotifier.load] and [ReviewsNotifier.load] are.
  Future<void> load() async {
    if (_disposed) return;
    if (!await ref.read(tokenStoreProvider).mayHaveSession()) return;
    if (_disposed) return;
    try {
      final mine =
          await ref.read(serviceMarketplaceRepositoryProvider).fetchRequests();
      if (_disposed) return;
      state = mine;
    } on UnauthorizedException {
      // Still reachable above the guard on an expired token. A guest keeps the
      // empty list; signing in calls this again.
    }
  }

  /// Drops this account's bookings on sign-out — there is nobody left to
  /// [load] a replacement for.
  ///
  /// A direct `state =` write, not `ref.invalidate(requestsProvider)`: this
  /// notifier is read via `.notifier` from `SessionRefresh`, outside any
  /// widget's `watch`, and invalidating it there left it disposed rather than
  /// rebuilt by the time the very next `SessionRefresh` call went looking for
  /// it — a real, reproduced bug on sign-out immediately followed by a
  /// sign-in, not a hypothetical one. Setting `state` directly has no such
  /// timing to get wrong.
  void clear() => state = const [];

  Duration get _approvalWindow => ref.read(appConfigProvider).approvalWindow;

  /// Places a booking. It starts at `createdPendingPayment` — the money is
  /// not held until the founder confirms it (spec §3, note 2).
  Future<ServiceRequest> place(CreateServiceRequestDraft draft) async {
    final repository = ref.read(serviceMarketplaceRepositoryProvider);
    final request = await repository.createRequest(draft);
    state = [request, ...state];

    ref
        .read(notificationsProvider.notifier)
        .adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyRequestPlaced(request),
        );

    return request;
  }

  /// Opens a "part + installation" request (spec §6).
  ///
  /// It starts at `requested` with no amount: the workshop names the price,
  /// and until it does the app has nothing to hold and nothing to charge.
  Future<ServiceRequest> placePartRequest(
    CreatePartRequestDraft draft, {
    required Car car,
  }) async {
    final request = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .createPartRequest(draft, car: car);
    state = [request, ...state];

    ref
        .read(notificationsProvider.notifier)
        .adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyPartRequestSent(request),
        );
    return request;
  }

  /// The workshop's itemised quote. Moves the booking to `quoted` and tells
  /// the customer there is a price waiting for a decision.
  Future<ServiceRequest?> submitQuote(String id, Quote quote) async {
    final current = state.firstWhereOrNull((r) => r.id == id);
    if (current?.escrow != EscrowState.requested) return null;

    final updated = await ref
        .read(serviceMarketplaceRepositoryProvider)
        .submitQuote(id, quote);
    _replace(updated);

    ref
        .read(notificationsProvider.notifier)
        .adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyQuoteReceived(updated),
        );
    return updated;
  }

  /// Fires one escrow transition.
  ///
  /// Returns the updated booking, or null when the transition was not allowed
  /// for [actor] from the current state — a no-op rather than a crash, since
  /// a stale screen firing a stale button is an ordinary race, not a bug.
  Future<ServiceRequest?> fire(
    String id,
    EscrowEvent event, {
    required EscrowActor actor,
    ProofOfWork? proof,
    String? disputeNote,
    String? slot,
  }) async {
    final current = state.firstWhereOrNull((r) => r.id == id);
    if (current == null) return null;
    final allowed = current.escrow.transitions.any(
      (t) => t.event == event && t.actor == actor,
    );
    if (!allowed) return null;
    // Refused here as well as in the service so a mis-wired button is a no-op
    // rather than an exception surfacing from the data layer: a part-and-fit
    // job cannot claim completion without evidence of the part (spec §6).
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

    ref
        .read(notificationsProvider.notifier)
        .adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyEscrowState(updated, updated.escrow),
        );

    // The work is done and paid for — and only now does it count as a service
    // this car actually had. Every other ending (cancelled, rejected,
    // refunded, still disputed) proves the opposite, so none of them reaches
    // this line. `logCompletedBooking` is itself idempotent, because the
    // approval timer and `sweepExpiredApprovals` can both arrive here.
    if (updated.escrow == EscrowState.releasedToWorkshop) {
      await ref.read(maintenanceProvider.notifier).logCompletedBooking(updated);
      // Reviews are an *event*, not a state (spec §8): the release does not
      // wait for one, nothing is held back pending one, and no new escrow
      // state exists for one. All that happens is that both sides are now
      // allowed to write one, and the customer is told so.
      if (AppFlags.verifiedReviews) {
        ref
            .read(notificationsProvider.notifier)
            .adopt(
              await ref
                  .read(notificationRepositoryProvider)
                  .notifyReviewUnlocked(updated),
            );
      }
    }

    // The machine's automatic steps. Each one exists because the alternative
    // is a booking parked in a state the customer can neither see the point of
    // nor act on.
    switch (updated.escrow) {
      // Accepting a price is agreeing to pay it — there is no second decision
      // to collect here.
      case EscrowState.quoteAccepted:
        return fire(
          id,
          EscrowEvent.proceedToPayment,
          actor: EscrowActor.system,
        );
      // A workshop that quoted the job already committed to doing it, so it is
      // not asked to accept it a second time once the funds land.
      case EscrowState.fundsHeld when updated.type == BookingType.customQuote:
        return fire(
          id,
          EscrowEvent.autoAcceptQuotedJob,
          actor: EscrowActor.system,
        );
      // The customer should never see a booking sitting at "proof submitted"
      // waiting for something invisible to happen.
      case EscrowState.proofSubmitted:
        return fire(
          id,
          EscrowEvent.handOffForApproval,
          actor: EscrowActor.system,
        );
      case EscrowState.awaitingApproval:
        _scheduleAutoRelease(updated);
        break;
      default:
        break;
    }
    return updated;
  }

  /// Advances one step along the happy path. Used by the staging simulator
  /// and the "skip ahead" demo control — never by a real actor's button.
  Future<void> advance(String id) async {
    final current = state.firstWhereOrNull((r) => r.id == id);
    final next = current?.escrow.happyPathNext;
    if (current == null || next == null) return;
    final transition = current.escrow.transitions.firstWhereOrNull(
      (t) => t.to == next,
    );
    if (transition == null) return;
    // The simulator stops at the proof (spec §3). Completion proof is photos
    // of a real car taken by a real workshop, plus — on a part-and-fit job —
    // a declaration that one of them shows the part's own box. A demo timer
    // owns none of that and must not manufacture it: fabricated evidence is
    // exactly the thing the escrow exists to prevent. From here the workshop
    // panel finishes the job by hand, which is what a pilot does anyway.
    if (transition.event == EscrowEvent.submitProof) return;
    await fire(id, transition.event, actor: transition.actor);
  }

  /// Releases any booking whose approval window has already lapsed — called
  /// when the list is rebuilt, because a timer set in a previous process does
  /// not survive the app being closed.
  Future<void> sweepExpiredApprovals({DateTime? now}) async {
    for (final r in [...state]) {
      if (r.autoReleaseDue(_approvalWindow, now: now)) {
        await fire(r.id, EscrowEvent.autoRelease, actor: EscrowActor.system);
      }
    }
  }

  void _scheduleAutoRelease(ServiceRequest request) {
    final deadline = request.approvalDeadline(_approvalWindow);
    if (deadline == null) return;
    final config = ref.read(appConfigProvider);

    final untilReminder = deadline
        .subtract(config.approvalReminderLead)
        .difference(DateTime.now());
    if (!untilReminder.isNegative) {
      _timers.add(
        Timer(untilReminder, () async {
          final current = state.firstWhereOrNull((r) => r.id == request.id);
          if (current?.escrow != EscrowState.awaitingApproval) return;
          ref
              .read(notificationsProvider.notifier)
              .adopt(
                await ref
                    .read(notificationRepositoryProvider)
                    .notifyApprovalWindowClosing(current!, deadline),
              );
        }),
      );
    }

    final untilRelease = deadline.difference(DateTime.now());
    _timers.add(
      Timer(
        untilRelease.isNegative ? Duration.zero : untilRelease,
        () => fire(
          request.id,
          EscrowEvent.autoRelease,
          actor: EscrowActor.system,
        ),
      ),
    );
  }

  void _replace(ServiceRequest updated) => state = [
    for (final r in state)
      if (r.id == updated.id) updated else r,
  ];
}

final requestsProvider =
    NotifierProvider<RequestsNotifier, List<ServiceRequest>>(
      RequestsNotifier.new,
    );

/// The request the tracking card follows: the first that has not finished.
final activeRequestProvider = Provider<ServiceRequest?>((ref) {
  for (final r in ref.watch(requestsProvider)) {
    if (!r.escrow.isTerminal) return r;
  }
  return null;
});

/// Bookings the customer has to act on — the approval queue.
final awaitingApprovalProvider = Provider<List<ServiceRequest>>(
  (ref) => [
    for (final r in ref.watch(requestsProvider))
      if (r.escrow == EscrowState.awaitingApproval) r,
  ],
);

/// Bookings the current role can move right now. Drives both operator panels:
/// each shows exactly the jobs where its own buttons would do something.
final actionableRequestsProvider = Provider<List<ServiceRequest>>((ref) {
  final actor = ref.watch(activeRoleProvider).actor;
  return [
    for (final r in ref.watch(requestsProvider))
      if (r.escrow.transitionsFor(actor).isNotEmpty) r,
  ];
});
