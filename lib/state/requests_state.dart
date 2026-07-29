import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_flags.dart';
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

  @override
  List<ServiceRequest> build() {
    ref.onDispose(() {
      for (final t in _timers) {
        t.cancel();
      }
    });
    return const [];
  }

  Duration get _approvalWindow => ref.read(appConfigProvider).approvalWindow;

  /// Places a booking. It starts at `createdPendingPayment` — the money is
  /// not held until the founder confirms it (spec §3, note 2).
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
      _simulateLifecycle(request.id);
    }
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

    ref.read(notificationsProvider.notifier).adopt(
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

    ref.read(notificationsProvider.notifier).adopt(
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
    final allowed = current.escrow.transitions
        .any((t) => t.event == event && t.actor == actor);
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

    ref.read(notificationsProvider.notifier).adopt(
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
      await ref
          .read(maintenanceProvider.notifier)
          .logCompletedBooking(updated);
      // Reviews are an *event*, not a state (spec §8): the release does not
      // wait for one, nothing is held back pending one, and no new escrow
      // state exists for one. All that happens is that both sides are now
      // allowed to write one, and the customer is told so.
      if (AppFlags.verifiedReviews) {
        ref.read(notificationsProvider.notifier).adopt(
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
        return fire(id, EscrowEvent.proceedToPayment,
            actor: EscrowActor.system);
      // A workshop that quoted the job already committed to doing it, so it is
      // not asked to accept it a second time once the funds land.
      case EscrowState.fundsHeld when updated.type == BookingType.customQuote:
        return fire(id, EscrowEvent.autoAcceptQuotedJob,
            actor: EscrowActor.system);
      // The customer should never see a booking sitting at "proof submitted"
      // waiting for something invisible to happen.
      case EscrowState.proofSubmitted:
        return fire(id, EscrowEvent.handOffForApproval,
            actor: EscrowActor.system);
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
    final transition = current.escrow.transitions
        .firstWhereOrNull((t) => t.to == next);
    if (transition == null) return;
    // A part-and-fit job's completion proof has to declare that it shows the
    // part's own box (spec §6). That is a claim about evidence, and a demo
    // timer is not entitled to make it on a workshop's behalf — so the
    // simulator stops here and the workshop panel finishes the job by hand.
    if (transition.event == EscrowEvent.submitProof &&
        current.type == BookingType.customQuote) {
      return;
    }
    await fire(
      id,
      transition.event,
      actor: transition.actor,
      proof: transition.event == EscrowEvent.submitProof
          ? _placeholderlessProof(current)
          : null,
    );
  }

  /// The simulator submits a proof with no media and no invented notes. A
  /// staging build must not manufacture a workshop's words — an empty proof
  /// renders as "notes only", which is exactly what it is.
  ProofOfWork _placeholderlessProof(ServiceRequest request) => ProofOfWork(
        id: 'proof-${request.id}',
        requestId: request.id,
        notes: '',
        submittedAt: DateTime.now(),
      );

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

    final untilReminder =
        deadline.subtract(config.approvalReminderLead).difference(DateTime.now());
    if (!untilReminder.isNegative) {
      _timers.add(Timer(untilReminder, () async {
        final current = state.firstWhereOrNull((r) => r.id == request.id);
        if (current?.escrow != EscrowState.awaitingApproval) return;
        ref.read(notificationsProvider.notifier).adopt(
              await ref
                  .read(notificationRepositoryProvider)
                  .notifyApprovalWindowClosing(current!, deadline),
            );
      }));
    }

    final untilRelease = deadline.difference(DateTime.now());
    _timers.add(Timer(
      untilRelease.isNegative ? Duration.zero : untilRelease,
      () => fire(request.id, EscrowEvent.autoRelease, actor: EscrowActor.system),
    ));
  }

  void _replace(ServiceRequest updated) => state = [
        for (final r in state)
          if (r.id == updated.id) updated else r,
      ];

  /// Staging stand-in for the workshop portal and the founder's manual
  /// confirmations: walks the happy path so a demo booking reaches "awaiting
  /// your approval" without three people having to be on three phones.
  /// Gated behind [AppConfig.simulateProviderLifecycle].
  void _simulateLifecycle(String requestId) {
    for (final seconds in const [4, 10, 20, 34]) {
      _timers.add(
        Timer(Duration(seconds: seconds), () => advance(requestId)),
      );
    }
  }
}

final requestsProvider =
    NotifierProvider<RequestsNotifier, List<ServiceRequest>>(
        RequestsNotifier.new);

/// The request the tracking card follows: the first that has not finished.
final activeRequestProvider = Provider<ServiceRequest?>((ref) {
  for (final r in ref.watch(requestsProvider)) {
    if (!r.escrow.isTerminal) return r;
  }
  return null;
});

/// Bookings the customer has to act on — the approval queue.
final awaitingApprovalProvider = Provider<List<ServiceRequest>>((ref) => [
      for (final r in ref.watch(requestsProvider))
        if (r.escrow == EscrowState.awaitingApproval) r,
    ]);

/// Bookings the current role can move right now. Drives both operator panels:
/// each shows exactly the jobs where its own buttons would do something.
final actionableRequestsProvider = Provider<List<ServiceRequest>>((ref) {
  final actor = ref.watch(activeRoleProvider).actor;
  return [
    for (final r in ref.watch(requestsProvider))
      if (r.escrow.transitionsFor(actor).isNotEmpty) r,
  ];
});
