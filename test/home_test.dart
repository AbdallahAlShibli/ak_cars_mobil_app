import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:flutter/material.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// The home page's four data-driven sections.
///
/// What is pinned here is the honesty of each one, because every claim on that
/// page is the sort a marketplace is tempted to invent: an offer that has ended,
/// a "from" price no workshop charges, a suggestion for a service the car cannot
/// use, a leaderboard built from nothing, a 4.9 rating from four people.

const _camry = Car(
  id: 'c1',
  make: 'Toyota',
  model: 'Camry',
  year: 2021,
  plate: '12345 AB',
  odometerKm: 128450,
  governorate: 'Muscat',
  powertrain: Powertrain.petrol,
);

const _patrol = Car(
  id: 'c2',
  make: 'Nissan',
  model: 'Patrol',
  year: 2019,
  governorate: 'Muscat',
  powertrain: Powertrain.diesel,
);

Future<ProviderContainer> containerWith(
  List<Car> garage, {
  int seed = 7,
}) async {
  final container = await createTestContainer(
    overrides: [sessionSeedProvider.overrideWithValue(seed)],
  );
  for (final car in garage) {
    await container.read(garageProvider.notifier).add(car);
  }
  return container;
}

void main() {
  // ------------------------------------------------------------------ offers
  group('offers rail', () {
    test('every card points at something that exists', () async {
      final container = await containerWith(const []);
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final offers = container.read(homePromotionsProvider);

      expect(offers, isNotEmpty);
      for (final offer in offers) {
        if (offer.offeringId != null) {
          expect(marketplace.offeringById(offer.offeringId!), isNotNull,
              reason: '${offer.id} advertises an offering that is not sold');
        }
        if (offer.providerId != null) {
          expect(marketplace.providers.map((p) => p.id),
              contains(offer.providerId));
        }
        // A card with neither a target nor a search would open nothing at all.
        expect(
          offer.offeringId != null || offer.query != null,
          isTrue,
          reason: '${offer.id} has nowhere to go',
        );
      }
    });

    test('an ended campaign is not shown', () async {
      final container = await containerWith(const []);
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final now = DateTime.now();

      for (final offer in marketplace.promotions()) {
        expect(offer.isLive(now), isTrue);
      }
      // The model, not just the dataset: an expiry in the past is dead however
      // it got there.
      const expired = Promotion(
        id: 'x',
        title: L('', ''),
        body: L('', ''),
        icon: Icons.abc,
      );
      expect(
        expired
            .copyWith(endsAt: now.subtract(const Duration(minutes: 1)))
            .isLive(now),
        isFalse,
      );
      expect(expired.isLive(now), isTrue, reason: 'no expiry means open-ended');
    });

    test('a campaign is only shown where it runs', () async {
      final container = await containerWith(const []);
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      final dhofar = marketplace.promotions(region: 'Dhofar');
      final muscat = marketplace.promotions(region: 'Muscat');

      expect(dhofar.map((p) => p.id), contains('promo-p6-ac'));
      expect(muscat.map((p) => p.id), isNot(contains('promo-p6-ac')));
      // The nationwide platform cards are in both, so no governorate is left
      // with an empty rail.
      expect(dhofar.map((p) => p.id), contains('promo-escrow'));
      expect(muscat.map((p) => p.id), contains('promo-escrow'));
    });

    test('an oil-change campaign is not advertised to an electric car',
        () async {
      final container = await containerWith(const []);
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      final petrol = marketplace.promotions(
          region: 'Muscat', powertrain: Powertrain.petrol);
      final electric = marketplace.promotions(
          region: 'Muscat', powertrain: Powertrain.electric);

      expect(petrol.map((p) => p.id), contains('promo-p1-major'));
      expect(electric.map((p) => p.id), isNot(contains('promo-p1-major')));
      // Tyres fit any car; the announcements are not about one car at all.
      expect(electric.map((p) => p.id), contains('promo-p4-tyres'));
      expect(electric.map((p) => p.id), contains('promo-escrow'));
    });
  });

  // --------------------------------------------------------- recommendations
  group('recommendations', () {
    test('there is nothing to recommend with an empty garage', () async {
      final container = await containerWith(const []);
      expect(container.read(homeRecommendationsProvider), isEmpty);
    });

    test('every card has a real price and a real workshop behind it', () async {
      final container = await containerWith(const [_camry]);
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final items = container.read(homeRecommendationsProvider);

      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.workshops, greaterThan(0));
        final offeringId = item.offeringId;
        expect(offeringId, isNotNull);
        // The "from" price is the price of the offering the card opens — not a
        // separate number that could drift from it. `pricedOffering` is what
        // the service page and the booking screen read, so comparing against
        // it is comparing against what the user will actually be charged,
        // discount included.
        final offering = marketplace.pricedOffering(offeringId!);
        expect(offering, isNotNull);
        expect(item.fromPrice, offering!.price);
      }
    });

    test('a due item outranks a popular one', () async {
      final container = await containerWith(const [_camry]);
      // Give the Camry a real oil history that is almost used up.
      await container.read(maintenanceProvider.notifier).addRecord(
            _camry.id,
            ServiceRecord(
              id: 'r1',
              title: const L('زيت', 'Oil'),
              workshop: 'Al Noor',
              odometerKm: 119000,
              date: DateTime.now().subtract(const Duration(days: 200)),
              itemKey: MaintenanceType.oil.key,
            ),
          );

      final items = container.read(homeRecommendationsProvider);
      expect(items, isNotEmpty);
      expect(
        items.first.reason,
        anyOf(RecommendationReason.dueNow, RecommendationReason.dueSoon),
      );
      expect(items.first.due, isNotNull);
      // A card that came from the owner's own numbers says so.
      expect(items.first.fromOwnCar, isTrue);
    });

    test('one card per schedule line, and it is the cheapest of them',
        () async {
      final container = await containerWith(const [_camry]);
      final items = container.read(homeRecommendationsProvider);

      // Major, Full and Express all reset engine oil. Only one may appear.
      final oilCards = items.where((i) =>
          MaintenanceTypeX.forCategory(i.category.id) == MaintenanceType.oil);
      expect(oilCards.length, lessThanOrEqualTo(1));
      if (oilCards.isNotEmpty) {
        final marketplace = container.read(serviceMarketplaceRepositoryProvider);
        final cheapest = [
          for (final id in ['major', 'full', 'express'])
            marketplace.fromPriceFor(id, region: 'Muscat'),
        ].whereType<double>().reduce((a, b) => a < b ? a : b);
        expect(oilCards.first.fromPrice, cheapest);
      }
    });

    test('roadside is never a suggestion', () async {
      final container = await containerWith(const [_camry, _patrol]);
      for (final item in container.read(homeRecommendationsProvider)) {
        expect(item.category.emergency, isFalse);
      }
    });

    test('a two-car garage gets advice for both cars', () async {
      final container = await containerWith(const [_camry, _patrol]);
      final items = container.read(homeRecommendationsProvider);

      expect(items.map((i) => i.car.id).toSet(), {_camry.id, _patrol.id});
      // The first two cards are one per car — neither car is buried.
      expect(items.take(2).map((i) => i.car.id).toSet().length, 2);
    });

    test('the seed reshuffles the rail without demoting what matters',
        () async {
      final orders = <List<String>>[];
      for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final container = await containerWith(const [_camry], seed: seed);
        final items = container.read(homeRecommendationsProvider);
        orders.add([for (final i in items) i.category.id]);
        // Whatever the seed, the bands stay in order.
        final reasons = [for (final i in items) i.reason.index];
        expect(reasons, orderedEquals(<int>[...reasons]..sort()));
      }
      // …and the seed does change something, or "changes each launch" is a lie.
      expect(orders.toSet().length, greaterThan(1));
    });

    test('the same seed always builds the same rail', () async {
      final first = await containerWith(const [_camry], seed: 42);
      final second = await containerWith(const [_camry], seed: 42);
      expect(
        first.read(homeRecommendationsProvider),
        second.read(homeRecommendationsProvider),
      );
    });
  });

  // ------------------------------------------------------------ most booked
  group('most booked', () {
    test('ranked by the marketplace count, with its window', () async {
      final container = await containerWith(const [_camry]);
      final ranked = container.read(mostBookedServicesProvider);

      expect(ranked, isNotEmpty);
      final counts = [for (final r in ranked) r.demand.bookings];
      expect(counts, orderedEquals(<int>[...counts]..sort((a, b) => b - a)));
      for (final entry in ranked) {
        // A count with no period behind it means nothing.
        expect(entry.demand.windowDays, greaterThan(0));
        expect(entry.demand.bookings, greaterThan(0));
      }
    });

    test('only categories that exist in the catalogue are ranked', () async {
      final container = await containerWith(const [_camry]);
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final ids = marketplace.categories.map((c) => c.id).toSet();

      for (final entry in container.read(mostBookedServicesProvider)) {
        expect(ids, contains(entry.category.id));
      }
    });
  });

  // -------------------------------------------------------------- top rated
  group('top-rated workshops', () {
    test('a workshop with too few reviews is not ranked', () async {
      final container = await containerWith(const []);
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      // Sohar Speed Garage carries the highest score in the dataset (4.9) on
      // four reviews. It must not top the board.
      final sohar = marketplace.ratingFor('p3');
      expect(sohar!.rating, 4.9);
      expect(sohar.reviews, lessThan(25));

      final board = marketplace.topRatedWorkshops();
      expect(board.map((e) => e.provider.id), isNot(contains('p3')));
      expect(board.first.rating.rating, lessThan(4.9));
    });

    test('an unrated workshop is absent, not zero-rated', () async {
      final container = await containerWith(const []);
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      expect(marketplace.ratingFor('p10'), isNull);
      expect(marketplace.topRatedWorkshops().map((e) => e.provider.id),
          isNot(contains('p10')));
    });

    test('ranked high to low, and every score carries its review count',
        () async {
      final container = await containerWith(const []);
      final board = container.read(serviceMarketplaceRepositoryProvider)
          .topRatedWorkshops(limit: 5);

      final scores = [for (final e in board) e.rating.rating];
      expect(scores, orderedEquals(<double>[...scores]..sort((a, b) => b.compareTo(a))));
      for (final entry in board) {
        expect(entry.rating.reviews, greaterThanOrEqualTo(25));
      }
    });

    test('the board says when it had to widen beyond the governorate',
        () async {
      final container = await containerWith(const []);
      container.read(regionProvider.notifier).state = 'Muscat';
      final muscat = container.read(topRatedWorkshopsProvider);
      expect(muscat.nationwide, isFalse);
      for (final entry in muscat.items) {
        expect(entry.provider.region, 'Muscat');
      }

      // North Al Batinah has one rankable workshop (`p3` is below the review
      // threshold), so a board of one would be a leaderboard of nobody.
      container.read(regionProvider.notifier).state = 'North Al Batinah';
      final batinah = container.read(topRatedWorkshopsProvider);
      expect(batinah.nationwide, isTrue);
      expect(batinah.items, isNotEmpty);
    });
  });
}
