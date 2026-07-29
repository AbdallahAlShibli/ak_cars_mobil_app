import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// Verified reviews (spec §8). The claim being tested is narrow and total:
/// **a review cannot exist without a booking that completed and paid out.**
/// Everything else — no spam, no bots, no fake social proof — follows from it.
const _car = Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019);

CreateServiceRequestDraft _draft() => CreateServiceRequestDraft(
      offering: MockServiceData.offerings.first,
      car: _car,
      plate: '1234 AB',
      fulfillment: Fulfillment.workshop,
      slot: 'Mon 3 Aug · 10:30',
      addOnIds: const {},
    );

Future<ProviderContainer> _container() => createTestContainer(overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.forEnvironment(AppEnvironment.development)
            .copyWith(simulateProviderLifecycle: false),
      ),
    ]);

/// Walks a booking all the way to a released payment.
Future<ServiceRequest> _completed(ProviderContainer container) async {
  final notifier = container.read(requestsProvider.notifier);
  final request = await notifier.place(_draft());
  for (final (event, actor) in const [
    (EscrowEvent.confirmFundsHeld, EscrowActor.founder),
    (EscrowEvent.acceptJob, EscrowActor.workshop),
    (EscrowEvent.startWork, EscrowActor.workshop),
    (EscrowEvent.submitProof, EscrowActor.workshop),
    (EscrowEvent.approve, EscrowActor.customer),
  ]) {
    await notifier.fire(request.id, event, actor: actor);
  }
  return container.read(requestsProvider).firstWhere((r) => r.id == request.id);
}

void main() {
  group('what makes a review verified', () {
    test('the app ships with no reviews at all', () async {
      final container = await _container();
      // Nothing is seeded. Invented reviews would be exactly the fabricated
      // social proof this design exists to make impossible.
      expect(container.read(reviewsProvider), isEmpty);
    });

    test('a booking still in progress cannot be reviewed', () async {
      final container = await _container();
      final request =
          await container.read(requestsProvider.notifier).place(_draft());

      expect(container.read(reviewRepositoryProvider).reviewable(request),
          isFalse);
      final review = await container.read(reviewsProvider.notifier).submit(
            request,
            direction: ReviewDirection.customerToWorkshop,
            rating: 5,
          );
      expect(review, isNull);
      expect(container.read(reviewsProvider), isEmpty);
    });

    test('a released booking can be, and is prompted for', () async {
      final container = await _container();
      final request = await _completed(container);

      expect(request.escrow, EscrowState.releasedToWorkshop);
      expect(container.read(pendingCustomerReviewsProvider).map((r) => r.id),
          [request.id]);

      final review = await container.read(reviewsProvider.notifier).submit(
            request,
            direction: ReviewDirection.customerToWorkshop,
            rating: 5,
            comment: 'Quick and clean.',
          );
      expect(review, isNotNull);
      // The prompt disappears once it is answered.
      expect(container.read(pendingCustomerReviewsProvider), isEmpty);
    });

    test('one review per booking per direction', () async {
      final container = await _container();
      final request = await _completed(container);
      final reviews = container.read(reviewsProvider.notifier);

      await reviews.submit(request,
          direction: ReviewDirection.customerToWorkshop, rating: 5);
      final second = await reviews.submit(request,
          direction: ReviewDirection.customerToWorkshop, rating: 1);

      expect(second, isNull);
      expect(container.read(reviewsProvider).length, 1);
    });

    test('both directions unlock on the same release', () async {
      final container = await _container();
      final request = await _completed(container);
      final reviews = container.read(reviewsProvider.notifier);

      expect(container.read(pendingWorkshopReviewsProvider).map((r) => r.id),
          [request.id]);

      await reviews.submit(request,
          direction: ReviewDirection.customerToWorkshop, rating: 4);
      await reviews.submit(request,
          direction: ReviewDirection.workshopToCustomer, rating: 5);

      expect(container.read(reviewsProvider).length, 2);
      expect(container.read(pendingWorkshopReviewsProvider), isEmpty);
    });

    test('an automatic release is reviewable too', () async {
      final container = await createTestContainer(overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.forEnvironment(AppEnvironment.development).copyWith(
            simulateProviderLifecycle: false,
            approvalWindow: Duration.zero,
          ),
        ),
      ]);
      final notifier = container.read(requestsProvider.notifier);
      final request = await notifier.place(_draft());
      for (final (event, actor) in const [
        (EscrowEvent.confirmFundsHeld, EscrowActor.founder),
        (EscrowEvent.acceptJob, EscrowActor.workshop),
        (EscrowEvent.startWork, EscrowActor.workshop),
        (EscrowEvent.submitProof, EscrowActor.workshop),
      ]) {
        await notifier.fire(request.id, event, actor: actor);
      }
      await notifier.sweepExpiredApprovals();

      final released =
          container.read(requestsProvider).firstWhere((r) => r.id == request.id);
      expect(released.escrow, EscrowState.releasedToWorkshop);
      expect(container.read(reviewRepositoryProvider).reviewable(released),
          isTrue);
    });

    test('a cancelled booking is never reviewable', () async {
      final container = await _container();
      final notifier = container.read(requestsProvider.notifier);
      final request = await notifier.place(_draft());
      await notifier.fire(request.id, EscrowEvent.cancelBooking,
          actor: EscrowActor.customer);

      final cancelled =
          container.read(requestsProvider).firstWhere((r) => r.id == request.id);
      expect(container.read(reviewRepositoryProvider).reviewable(cancelled),
          isFalse);
    });
  });

  group('the rating is derived', () {
    test('a workshop nobody has rated has no rating, not a zero', () async {
      final container = await _container();
      // p10 is absent from the marketplace's own aggregates.
      expect(container.read(providerRatingProvider('p10')), isNull);
    });

    test('a written review moves the workshop rating', () async {
      final container = await _container();
      final request = await _completed(container);
      final providerId = request.offering.provider.id;
      final before = container.read(providerRatingProvider(providerId));

      await container.read(reviewsProvider.notifier).submit(
            request,
            direction: ReviewDirection.customerToWorkshop,
            rating: 1,
          );
      final after = container.read(providerRatingProvider(providerId))!;

      expect(after.reviews, (before?.reviews ?? 0) + 1);
      if (before != null) expect(after.rating, lessThan(before.rating));
    });

    test('a review of the customer does not touch the workshop rating',
        () async {
      final container = await _container();
      final request = await _completed(container);
      final providerId = request.offering.provider.id;
      final before = container.read(providerRatingProvider(providerId));

      await container.read(reviewsProvider.notifier).submit(
            request,
            direction: ReviewDirection.workshopToCustomer,
            rating: 1,
          );
      expect(container.read(providerRatingProvider(providerId)), before);
    });
  });

  group('editing', () {
    test('a review can be corrected but never deleted', () async {
      final container = await _container();
      final request = await _completed(container);
      final reviews = container.read(reviewsProvider.notifier);

      final original = await reviews.submit(request,
          direction: ReviewDirection.customerToWorkshop, rating: 2);
      final edited = await reviews.edit(original!.id, rating: 4);

      expect(edited!.rating, 4);
      expect(edited.edited, isTrue);
      expect(container.read(reviewsProvider).length, 1);
    });
  });
}
