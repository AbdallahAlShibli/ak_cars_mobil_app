import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// "Request a part + installation" (spec §6) and the two rules that make it
/// more than a chat message: the price arrives itemised, and the completion
/// proof has to show the part itself.
const _car = Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019);

CreatePartRequestDraft _draft({String? providerId}) => CreatePartRequestDraft(
      providerId: providerId ?? MockServiceData.providers.first.id,
      carId: _car.id,
      plate: '1234 AB',
      fulfillment: Fulfillment.workshop.key,
      part: const PartRequest(
        description: 'Front brake pads set + fitting',
        preferredBrand: 'Genuine',
      ),
    );

Quote _quote(String requestId, {int? warrantyDays}) => Quote(
      id: 'q1',
      requestId: requestId,
      workshopId: MockServiceData.providers.first.id,
      partDescription: 'OEM front pad set',
      partPrice: 24,
      laborPrice: 8,
      warrantyDays: warrantyDays,
      createdAt: DateTime.now(),
    );

Future<ProviderContainer> _container() => createDataContainer(overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.forEnvironment(AppEnvironment.development)
            .copyWith(simulateProviderLifecycle: false),
      ),
    ]);

ServiceRequest _read(ProviderContainer container, String id) =>
    container.read(requestsProvider).firstWhere((r) => r.id == id);

void main() {
  group('opening a part request', () {
    test('starts with no price and nothing held', () async {
      final container = await _container();
      final request = await container
          .read(requestsProvider.notifier)
          .placePartRequest(_draft(), car: _car);

      expect(request.type, BookingType.customQuote);
      expect(request.escrow, EscrowState.requested);
      expect(request.escrow.holdsFunds, isFalse);
      expect(request.total, 0);
      expect(request.quote, isNull);
      expect(request.partRequest?.description, contains('brake pads'));
    });

    test('carries the chosen workshop as its provider', () async {
      final container = await _container();
      final chosen = MockServiceData.providers[1];
      final request = await container
          .read(requestsProvider.notifier)
          .placePartRequest(_draft(providerId: chosen.id), car: _car);

      expect(request.offering.provider.id, chosen.id);
      expect(request.offering.isPartInstall, isTrue);
      // No published price exists for a job nobody has priced.
      expect(request.offering.quoteOnly, isTrue);
    });
  });

  group('the quote', () {
    test('the total is the itemised parts, never a number of its own',
        () async {
      final container = await _container();
      final notifier = container.read(requestsProvider.notifier);
      final request = await notifier.placePartRequest(_draft(), car: _car);

      await notifier.submitQuote(request.id, _quote(request.id));
      expect(_read(container, request.id).escrow, EscrowState.quoted);
      // Quoted is still not priced *to the customer* — accepting is what
      // commits them to an amount.
      expect(_read(container, request.id).total, 0);

      await notifier.fire(request.id, EscrowEvent.acceptQuote,
          actor: EscrowActor.customer);
      final accepted = _read(container, request.id);
      expect(accepted.total, 32);
      expect(accepted.quote!.total, accepted.quote!.partPrice + accepted.quote!.laborPrice);
    });

    test('accepting hands straight over to the payment step', () async {
      final container = await _container();
      final notifier = container.read(requestsProvider.notifier);
      final request = await notifier.placePartRequest(_draft(), car: _car);
      await notifier.submitQuote(request.id, _quote(request.id));

      await notifier.fire(request.id, EscrowEvent.acceptQuote,
          actor: EscrowActor.customer);
      // quoteAccepted is transient: agreeing a price is agreeing to pay it.
      expect(_read(container, request.id).escrow,
          EscrowState.createdPendingPayment);
    });

    test('a quoting workshop is not asked to accept the job twice', () async {
      final container = await _container();
      final notifier = container.read(requestsProvider.notifier);
      final request = await notifier.placePartRequest(_draft(), car: _car);
      await notifier.submitQuote(request.id, _quote(request.id));
      await notifier.fire(request.id, EscrowEvent.acceptQuote,
          actor: EscrowActor.customer);

      await notifier.fire(request.id, EscrowEvent.confirmFundsHeld,
          actor: EscrowActor.founder);
      expect(_read(container, request.id).escrow,
          EscrowState.acceptedByWorkshop);
    });

    test('declining closes the booking without holding anything', () async {
      final container = await _container();
      final notifier = container.read(requestsProvider.notifier);
      final request = await notifier.placePartRequest(_draft(), car: _car);
      await notifier.submitQuote(request.id, _quote(request.id));

      await notifier.fire(request.id, EscrowEvent.declineQuote,
          actor: EscrowActor.customer);
      final declined = _read(container, request.id);
      expect(declined.escrow, EscrowState.cancelled);
      expect(declined.escrow.holdsFunds, isFalse);
    });

    test('the part warranty is recorded and is not the payment escrow',
        () async {
      final container = await _container();
      final notifier = container.read(requestsProvider.notifier);
      final request = await notifier.placePartRequest(_draft(), car: _car);
      await notifier.submitQuote(
          request.id, _quote(request.id, warrantyDays: 90));

      expect(_read(container, request.id).partWarrantyDays, 90);
      // The escrow still ends at release; the part warranty outlives it.
      expect(EscrowState.releasedToWorkshop.isTerminal, isTrue);
    });

    test('a booking that has not been quoted cannot be quoted twice',
        () async {
      final container = await _container();
      final notifier = container.read(requestsProvider.notifier);
      final request = await notifier.placePartRequest(_draft(), car: _car);
      await notifier.submitQuote(request.id, _quote(request.id));

      expect(await notifier.submitQuote(request.id, _quote(request.id)),
          isNull);
      expect(_read(container, request.id).escrow, EscrowState.quoted);
    });
  });

  group('proof of the part itself', () {
    Future<(ProviderContainer, ServiceRequest)> inProgressJob() async {
      final container = await _container();
      final notifier = container.read(requestsProvider.notifier);
      final request = await notifier.placePartRequest(_draft(), car: _car);
      await notifier.submitQuote(request.id, _quote(request.id));
      await notifier.fire(request.id, EscrowEvent.acceptQuote,
          actor: EscrowActor.customer);
      await notifier.fire(request.id, EscrowEvent.confirmFundsHeld,
          actor: EscrowActor.founder);
      await notifier.fire(request.id, EscrowEvent.startWork,
          actor: EscrowActor.workshop);
      return (container, _read(container, request.id));
    }

    ProofOfWork proof(String requestId, {required bool box}) => ProofOfWork(
          id: 'p1',
          requestId: requestId,
          notes: 'Pads replaced.',
          submittedAt: DateTime.now(),
          includesPartBoxPhoto: box,
        );

    test('a part job cannot complete without the box declared', () async {
      final (container, request) = await inProgressJob();
      expect(request.escrow, EscrowState.inProgress);

      await container.read(requestsProvider.notifier).fire(
            request.id,
            EscrowEvent.submitProof,
            actor: EscrowActor.workshop,
            proof: proof(request.id, box: false),
          );
      expect(_read(container, request.id).escrow, EscrowState.inProgress);
    });

    test('and completes once it is', () async {
      final (container, request) = await inProgressJob();

      await container.read(requestsProvider.notifier).fire(
            request.id,
            EscrowEvent.submitProof,
            actor: EscrowActor.workshop,
            proof: proof(request.id, box: true),
          );
      final submitted = _read(container, request.id);
      expect(submitted.escrow, EscrowState.awaitingApproval);
      expect(submitted.proof!.includesPartBoxPhoto, isTrue);
    });

    test('a catalogue service is not held to the part rule', () {
      final catalogue = ServiceRequest(
        id: '1',
        offering: MockServiceData.offerings.first,
        car: _car,
        plate: '1 A',
        fulfillment: Fulfillment.workshop,
        slot: '10:00',
        addOns: const [],
        total: 12,
        escrow: EscrowState.inProgress,
        createdAt: DateTime.now(),
      );

      // Including with nothing attached: a workshop that submitted no evidence
      // is the customer's judgement to make on the approval screen, not a
      // transition the machine blocks.
      expect(catalogue.proofSatisfiesRules(null), isTrue);
    });
  });
}
