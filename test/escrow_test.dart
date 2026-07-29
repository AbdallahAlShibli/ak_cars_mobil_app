import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

const _car = Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019);

CreateServiceRequestDraft _draft() => CreateServiceRequestDraft(
      offering: MockServiceData.offerings.first,
      car: _car,
      plate: '1234 AB',
      fulfillment: Fulfillment.workshop,
      slot: 'Mon 3 Aug · 10:30',
      addOnIds: const {},
    );

/// The simulator would walk the booking forward under the test's feet, and
/// the 72-hour window is not something a unit test should wait out.
Future<ProviderContainer> _container({Duration? approvalWindow}) =>
    createDataContainer(overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.forEnvironment(AppEnvironment.development).copyWith(
          simulateProviderLifecycle: false,
          approvalWindow: approvalWindow,
        ),
      ),
    ]);

Future<ServiceRequest> _place(ProviderContainer container) =>
    container.read(requestsProvider.notifier).place(_draft());

ServiceRequest _read(ProviderContainer container, String id) =>
    container.read(requestsProvider).firstWhere((r) => r.id == id);

void main() {
  group('the transition table', () {
    test('every state except the terminal three can move somewhere', () {
      for (final state in EscrowState.values) {
        expect(state.transitions.isEmpty, state.isTerminal,
            reason: '${state.key} should ${state.isTerminal ? '' : 'not '}'
                'be a dead end');
      }
    });

    test('no state offers two transitions on the same event', () {
      for (final state in EscrowState.values) {
        final events = state.transitions.map((t) => t.event).toList();
        expect(events.toSet().length, events.length,
            reason: '${state.key} has an ambiguous event');
      }
    });

    test('the happy path reaches awaiting approval and stops', () {
      var state = EscrowState.createdPendingPayment;
      final visited = <EscrowState>[state];
      while (state.happyPathNext != null) {
        state = state.happyPathNext!;
        expect(visited.contains(state), isFalse, reason: 'cycle at $state');
        visited.add(state);
      }
      expect(state, EscrowState.awaitingApproval);
    });

    test('only the customer approves, and only the founder resolves', () {
      expect(
        EscrowState.awaitingApproval.transitionsFor(EscrowActor.workshop),
        isEmpty,
      );
      expect(
        EscrowState.disputed.transitionsFor(EscrowActor.customer),
        isEmpty,
      );
      expect(
        EscrowState.disputed
            .transitionsFor(EscrowActor.founder)
            .map((t) => t.to),
        containsAll([EscrowState.releasedToWorkshop, EscrowState.refunded]),
      );
    });

    test('funds are only ever held between confirmation and settlement', () {
      expect(EscrowState.createdPendingPayment.holdsFunds, isFalse);
      expect(EscrowState.fundsHeld.holdsFunds, isTrue);
      expect(EscrowState.awaitingApproval.holdsFunds, isTrue);
      for (final state in [
        EscrowState.releasedToWorkshop,
        EscrowState.refunded,
        EscrowState.cancelled,
      ]) {
        expect(state.holdsFunds, isFalse, reason: state.key);
      }
    });
  });

  group('firing transitions', () {
    test('a booking starts before the money is confirmed held', () async {
      final container = await _container();
      final request = await _place(container);

      expect(request.escrow, EscrowState.createdPendingPayment);
      expect(request.escrow.holdsFunds, isFalse);
      expect(request.history.single.state,
          EscrowState.createdPendingPayment);
    });

    test('the wrong actor cannot fire a transition', () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      // Confirming funds is the founder's move, not the workshop's.
      final rejected = await notifier.fire(
        request.id,
        EscrowEvent.confirmFundsHeld,
        actor: EscrowActor.workshop,
      );
      expect(rejected, isNull);
      expect(_read(container, request.id).escrow,
          EscrowState.createdPendingPayment);
    });

    test('an event the current state does not offer is a no-op', () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      // Approving before there is anything to approve.
      expect(
        await notifier.fire(request.id, EscrowEvent.approve,
            actor: EscrowActor.customer),
        isNull,
      );
      expect(_read(container, request.id).escrow,
          EscrowState.createdPendingPayment);
    });

    test('submitting proof hands off to awaiting approval automatically',
        () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      await notifier.fire(request.id, EscrowEvent.confirmFundsHeld,
          actor: EscrowActor.founder);
      await notifier.fire(request.id, EscrowEvent.acceptJob,
          actor: EscrowActor.workshop);
      await notifier.fire(request.id, EscrowEvent.startWork,
          actor: EscrowActor.workshop);
      await notifier.fire(
        request.id,
        EscrowEvent.submitProof,
        actor: EscrowActor.workshop,
        proof: ProofOfWork(
          id: 'p1',
          requestId: request.id,
          notes: 'Oil and filter replaced.',
          submittedAt: DateTime.now(),
        ),
      );

      final updated = _read(container, request.id);
      expect(updated.escrow, EscrowState.awaitingApproval);
      expect(updated.proof?.notes, 'Oil and filter replaced.');
      expect(updated.awaitingApprovalSince, isNotNull);
      // proofSubmitted is still recorded — the customer just never waits in it.
      expect(updated.history.map((h) => h.state),
          contains(EscrowState.proofSubmitted));
    });

    test('a rejected job refunds rather than cancelling', () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      await notifier.fire(request.id, EscrowEvent.confirmFundsHeld,
          actor: EscrowActor.founder);
      await notifier.fire(request.id, EscrowEvent.rejectJob,
          actor: EscrowActor.workshop);

      expect(_read(container, request.id).escrow, EscrowState.refunded);
    });

    test("a dispute keeps the customer's own words", () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      for (final (event, actor) in const [
        (EscrowEvent.confirmFundsHeld, EscrowActor.founder),
        (EscrowEvent.acceptJob, EscrowActor.workshop),
        (EscrowEvent.startWork, EscrowActor.workshop),
        (EscrowEvent.submitProof, EscrowActor.workshop),
      ]) {
        await notifier.fire(request.id, event, actor: actor);
      }
      await notifier.fire(
        request.id,
        EscrowEvent.raiseIssue,
        actor: EscrowActor.customer,
        disputeNote: 'The noise is still there.',
      );

      final disputed = _read(container, request.id);
      expect(disputed.escrow, EscrowState.disputed);
      expect(disputed.disputeNote, 'The noise is still there.');
      // Money stays put until the founder rules.
      expect(disputed.escrow.holdsFunds, isTrue);
    });
  });

  group('the 72-hour approval window', () {
    test('defaults to three days and is measured from the hand-off', () async {
      final container = await _container();
      expect(container.read(appConfigProvider).approvalWindow,
          const Duration(hours: 72));
    });

    test('a lapsed window releases on the next sweep', () async {
      // A one-second window, so the test exercises the real deadline
      // arithmetic without waiting three days for it.
      final container = await _container(approvalWindow: const Duration(seconds: 1));
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      for (final (event, actor) in const [
        (EscrowEvent.confirmFundsHeld, EscrowActor.founder),
        (EscrowEvent.acceptJob, EscrowActor.workshop),
        (EscrowEvent.startWork, EscrowActor.workshop),
        (EscrowEvent.submitProof, EscrowActor.workshop),
      ]) {
        await notifier.fire(request.id, event, actor: actor);
      }
      expect(_read(container, request.id).escrow,
          EscrowState.awaitingApproval);

      await notifier.sweepExpiredApprovals(
        now: DateTime.now().add(const Duration(minutes: 1)),
      );
      expect(_read(container, request.id).escrow,
          EscrowState.releasedToWorkshop);
    });

    test('an open window is left alone by the sweep', () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      for (final (event, actor) in const [
        (EscrowEvent.confirmFundsHeld, EscrowActor.founder),
        (EscrowEvent.acceptJob, EscrowActor.workshop),
        (EscrowEvent.startWork, EscrowActor.workshop),
        (EscrowEvent.submitProof, EscrowActor.workshop),
      ]) {
        await notifier.fire(request.id, event, actor: actor);
      }

      await notifier.sweepExpiredApprovals();
      expect(_read(container, request.id).escrow,
          EscrowState.awaitingApproval);
    });
  });

  group('how far a booking actually got', () {
    test('a cancelled booking ticks nothing past the step it reached',
        () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      await notifier.fire(
        request.id,
        EscrowEvent.cancelBooking,
        actor: EscrowActor.customer,
      );
      final cancelled = _read(container, request.id);

      // It sits on the tracking screen's last row...
      expect(cancelled.escrow.customerStepIndex, 5);
      // ...but never reached "funds held", so nothing above step 0 may show
      // as done. The money was never confirmed.
      expect(cancelled.reachedStepIndex, 0);
    });

    test('a rejected job reached the funds-held step and no further', () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      await notifier.fire(request.id, EscrowEvent.confirmFundsHeld,
          actor: EscrowActor.founder);
      await notifier.fire(request.id, EscrowEvent.rejectJob,
          actor: EscrowActor.workshop);
      final refunded = _read(container, request.id);

      expect(refunded.escrow, EscrowState.refunded);
      // The workshop never accepted it, so "Workshop accepted" (step 2) is
      // not something the timeline may claim happened.
      expect(refunded.reachedStepIndex, 1);
    });

    test('a completed booking reached every step', () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      for (final (event, actor) in const [
        (EscrowEvent.confirmFundsHeld, EscrowActor.founder),
        (EscrowEvent.acceptJob, EscrowActor.workshop),
        (EscrowEvent.startWork, EscrowActor.workshop),
        (EscrowEvent.submitProof, EscrowActor.workshop),
        (EscrowEvent.approve, EscrowActor.customer),
      ]) {
        await notifier.fire(request.id, event, actor: actor);
      }
      final released = _read(container, request.id);

      expect(released.escrow, EscrowState.releasedToWorkshop);
      expect(released.reachedStepIndex, 5);
    });

    test('a dispute keeps the steps the work actually passed through',
        () async {
      final container = await _container();
      final request = await _place(container);
      final notifier = container.read(requestsProvider.notifier);

      for (final (event, actor) in const [
        (EscrowEvent.confirmFundsHeld, EscrowActor.founder),
        (EscrowEvent.acceptJob, EscrowActor.workshop),
        (EscrowEvent.startWork, EscrowActor.workshop),
        (EscrowEvent.submitProof, EscrowActor.workshop),
      ]) {
        await notifier.fire(request.id, event, actor: actor);
      }
      await notifier.fire(request.id, EscrowEvent.raiseIssue,
          actor: EscrowActor.customer, disputeNote: 'The noise is still there');
      final disputed = _read(container, request.id);

      expect(disputed.escrow, EscrowState.disputed);
      // The work really was done and submitted — only the ending is off-path.
      expect(disputed.reachedStepIndex, 4);
    });
  });
}
