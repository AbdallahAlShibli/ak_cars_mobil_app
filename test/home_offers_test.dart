import 'package:ak_cars_mobil_app/config/home_ranking_config.dart';
import 'fakes/data/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';
import 'fakes/data/mock_ids.dart';
import 'fakes/fakes.dart';

/// The home page's offer governance and its two workshop boards
/// (AK_Cars_تعليمات_الصفحة_الرئيسية §§2–5).
///
/// What is pinned here is that the front page cannot lie about money or about
/// standing: an offer only appears when all six conditions hold, the discount
/// it advertises is the price every other screen charges, a workshop the
/// platform has not approved is never promoted, and a board with no evidence
/// behind it is renamed rather than filled.

const _camry = Car(
  id: 'c1',
  make: 'Toyota',
  model: 'Camry',
  year: 2021,
  odometerKm: 128450,
  governorate: 'Muscat',
  powertrain: Powertrain.petrol,
);

/// Restores the shared mock offer list, which the founder-toggle tests mutate
/// in place the way a real back office would.
void restoreOffers() {
  final snapshot = [for (final offer in MockServiceData.offers) offer];
  addTearDown(() {
    MockServiceData.offers
      ..clear()
      ..addAll(snapshot);
  });
}

/// The real mock service with the two aggregates emptied — a marketplace on
/// its first week, which is the state §5 is about.
class _NoEvidenceService extends MockServiceMarketplaceService {

  @override
  Future<List<WorkshopRating>> fetchWorkshopRatings() async => const [];

  @override
  Future<List<WorkshopDemand>> fetchWorkshopDemand() async => const [];

  @override
  Future<List<Offer>> fetchOffers() async => const [];
}

void main() {
  // ------------------------------------------------------ offer validation
  group('offer governance', () {
    test('every offer on the home page passes all six rules', () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final live = marketplace.liveOffers();

      expect(live, isNotEmpty);
      final now = DateTime.now();
      for (final entry in live) {
        final offer = entry.offer;
        final offering = marketplace.offeringById(offer.serviceOfferingId);

        // 2 — an approved workshop, and the one that actually sells it.
        expect(offering, isNotNull, reason: '${offer.id}: unlisted service');
        expect(offering!.provider.isApproved, isTrue);
        expect(offering.provider.id, offer.workshopId);
        // 1 — the reference price is the published price, not a typed one.
        expect(offer.referencePrice, offering.price);
        expect(offer.discountedPrice, lessThan(offer.referencePrice));
        // 4 and 5.
        expect(offer.activeByFounder, isTrue);
        expect(offer.isWithin(now), isTrue);
      }
    });

    test('each way an offer can fail is caught, and named', () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final byId = {
        for (final row in marketplace.auditOffers()) row.offer.id: row.rejection,
      };

      expect(byId[mockIdOfP3ExpressUnapproved],
          OfferRejection.workshopNotApproved);
      expect(byId[mockIdOfP2FullInflated], OfferRejection.referencePriceMismatch);
      expect(byId[mockIdOfP5ContractsExpired], OfferRejection.outsideItsDates);
      expect(byId[mockIdOfP1ExpressDraft], OfferRejection.notApprovedByFounder);
      // …and the valid ones carry no reason at all.
      expect(byId[mockIdOfP1Major], isNull);
    });

    test('an inflated reference price cannot manufacture a discount',
        () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      // Gulf Auto Care publishes 32 for a full service; the offer claims 45
      // was struck through, which would read as a 36% saving.
      expect(marketplace.offeringById(mockOfferingId(mockIdP2, mockIdFull))!.price, 32);
      expect(marketplace.offerFor(mockOfferingId(mockIdP2, mockIdFull)), isNull);
      expect(marketplace.liveOffers().map((e) => e.offer.id),
          isNot(contains(mockIdOfP2FullInflated)));
      // The service is still sold, at its published price. Only the false
      // discount disappeared.
      expect(marketplace.pricedOffering(mockOfferingId(mockIdP2, mockIdFull))!.price, 32);
    });

    test('an unapproved workshop cannot run an offer', () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      final sohar =
          marketplace.providers.firstWhere((p) => p.id == mockIdP3);
      expect(sohar.isApproved, isFalse);
      expect(marketplace.offerFor(mockOfferingId(mockIdP3, mockIdExpress)), isNull);
      expect(marketplace.pricedOffering(mockOfferingId(mockIdP3, mockIdExpress))!.price,
          marketplace.offeringById(mockOfferingId(mockIdP3, mockIdExpress))!.price);
    });

    test('offers are ordered by the saving, and by nothing else', () async {
      final container = await createDataContainer();
      final live =
          container.read(serviceMarketplaceRepositoryProvider).liveOffers();

      final percentages = [for (final e in live) e.offer.discountPercent];
      expect(
        percentages,
        orderedEquals(<double>[...percentages]..sort((a, b) => b.compareTo(a))),
      );
    });

    test('an offer is only shown where its workshop is', () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      final muscat = marketplace.liveOffers(region: 'Muscat');
      expect(muscat.map((e) => e.offer.id), contains(mockIdOfP1Major));
      expect(muscat.map((e) => e.offer.id), isNot(contains(mockIdOfP6Ac)));

      final dhofar = marketplace.liveOffers(region: 'Dhofar');
      expect(dhofar.map((e) => e.offer.id), contains(mockIdOfP6Ac));
    });

    test('an engine-oil discount is not advertised to an electric car',
        () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      final petrol = marketplace.liveOffers(
          region: 'Muscat', powertrain: Powertrain.petrol);
      final electric = marketplace.liveOffers(
          region: 'Muscat', powertrain: Powertrain.electric);

      expect(petrol.map((e) => e.offer.id), contains(mockIdOfP1Major));
      expect(electric.map((e) => e.offer.id), isNot(contains(mockIdOfP1Major)));
      // Tyres fit any car.
      expect(electric.map((e) => e.offer.id), contains(mockIdOfP4Tyres));
    });

    test('the offers section is empty, not padded, when nothing is discounted',
        () async {
      final container = await createDataContainer(overrides: [
        serviceMarketplaceServiceProvider.overrideWith(
          (ref) => _NoEvidenceService(),
        ),
      ]);
      expect(container.read(homeOffersProvider), isEmpty);
      // The announcements are a different list and survive — which is exactly
      // why they are not allowed to fill the offers section.
      expect(container.read(homeAnnouncementsProvider), isNotEmpty);
    });
  });

  // --------------------------------------------------- price consistency
  group('one price everywhere', () {
    test('a discount reaches every surface that quotes that service',
        () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final offer = marketplace.offerFor(mockOfferingId(mockIdP4, mockIdTyres))!;

      // The published price is untouched — it is what the offer is validated
      // against and what the card strikes through.
      expect(marketplace.offeringById(mockOfferingId(mockIdP4, mockIdTyres))!.price, 6);
      expect(offer.referencePrice, 6);
      expect(offer.discountedPrice, 4.5);

      // …and every screen that quotes a payable price quotes the discount.
      expect(marketplace.pricedOffering(mockOfferingId(mockIdP4, mockIdTyres))!.price, 4.5);
      expect(
        marketplace.pricedOfferings
            .firstWhere((o) => o.id == mockOfferingId(mockIdP4, mockIdTyres))
            .price,
        4.5,
      );
      expect(
        marketplace
            .offeringsFor(mockIdTyres, region: 'Muscat')
            .firstWhere((o) => o.id == mockOfferingId(mockIdP4, mockIdTyres))
            .price,
        4.5,
      );
      expect(marketplace.fromPriceFor(mockIdTyres, region: 'Muscat'), 4.5);
      expect(marketplace.cheapestOfferingFor(mockIdTyres, region: 'Muscat')!.id,
          mockOfferingId(mockIdP4, mockIdTyres));
    });

    test('the cheapest offering is the one the customer would actually pay '
        'least at', () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      // Gulf Auto Care publishes 7 for tyres, Qurum publishes 6 and discounts
      // to 4.5 — so the "best price" row must be Qurum's, at 4.5.
      final cheapest =
          marketplace.cheapestOfferingFor(mockIdTyres, region: 'Muscat')!;
      for (final o in marketplace.offeringsFor(mockIdTyres, region: 'Muscat')) {
        if (o.price == null) continue;
        expect(cheapest.price!, lessThanOrEqualTo(o.price!));
      }
    });

    test('a recommendation card quotes the discounted price too', () async {
      final container = await createDataContainer();
      await container.read(garageProvider.notifier).add(_camry);
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      for (final item in container.read(homeRecommendationsProvider)) {
        final offeringId = item.offeringId;
        if (offeringId == null) continue;
        expect(item.fromPrice, marketplace.pricedOffering(offeringId)!.price);
      }
    });
  });

  // ------------------------------------------------------- founder control
  group('founder control', () {
    test('enabling an offer publishes it; stopping one withdraws it',
        () async {
      restoreOffers();
      final container = await createDataContainer();
      final admin = container.read(offersAdminProvider);

      // A submitted-but-not-enabled offer is invisible.
      expect(container.read(homeOffersProvider).map((e) => e.offer.id),
          isNot(contains(mockIdOfP1ExpressDraft)));

      await admin.setActive(mockIdOfP1ExpressDraft, active: true);
      expect(container.read(homeOffersProvider).map((e) => e.offer.id),
          contains(mockIdOfP1ExpressDraft));
      // And the discount is live everywhere at once.
      expect(
        container
            .read(serviceMarketplaceRepositoryProvider)
            .pricedOffering(mockOfferingId(mockIdP1, mockIdExpress))!
            .price,
        9,
      );

      await admin.setActive(mockIdOfP1Major, active: false);
      expect(container.read(homeOffersProvider).map((e) => e.offer.id),
          isNot(contains(mockIdOfP1Major)));
      expect(
        container
            .read(serviceMarketplaceRepositoryProvider)
            .pricedOffering(mockOfferingId(mockIdP1, mockIdMajor))!
            .price,
        45,
      );
    });

    test('approving an offer that fails another rule still does not show it',
        () async {
      restoreOffers();
      final container = await createDataContainer();

      // It is already founder-approved; the problem is the inflated reference
      // price, and no amount of approving fixes that.
      await container
          .read(offersAdminProvider)
          .setActive(mockIdOfP2FullInflated, active: true);

      final audit = container.read(offersAuditProvider);
      final row =
          audit.firstWhere((r) => r.offer.id == mockIdOfP2FullInflated);
      expect(row.offer.activeByFounder, isTrue);
      expect(row.rejection, OfferRejection.referencePriceMismatch);
      expect(container.read(homeOffersProvider).map((e) => e.offer.id),
          isNot(contains(mockIdOfP2FullInflated)));
    });
  });

  // ----------------------------------------------------- workshop boards
  group('trusted workshops', () {
    test('an unapproved workshop is never ranked', () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);
      final unapproved = {
        for (final p in marketplace.providers)
          if (!p.isApproved) p.id,
      };
      expect(unapproved, isNotEmpty);

      for (final entry in marketplace.topRatedWorkshops()) {
        expect(unapproved, isNot(contains(entry.provider.id)));
      }
      for (final entry in marketplace.mostRequestedWorkshops()) {
        expect(unapproved, isNot(contains(entry.provider.id)));
      }
    });

    test('"most requested" ranks completed bookings, high to low', () async {
      final container = await createDataContainer();
      final board = container
          .read(serviceMarketplaceRepositoryProvider)
          .mostRequestedWorkshops(limit: 5);

      expect(board, isNotEmpty);
      final counts = [for (final e in board) e.demand.completedBookings];
      expect(counts, orderedEquals(<int>[...counts]..sort((a, b) => b - a)));
      for (final entry in board) {
        // A count with no window behind it means nothing, and a zero is not a
        // rank.
        expect(entry.demand.completedBookings, greaterThan(0));
        expect(entry.demand.windowDays, HomeRankingConfig.popularWindowDays);
      }
    });

    test('a workshop that has completed nothing is absent, not last',
        () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      // p10 is in the aggregate with zero; p11 is not in it at all.
      expect(
        marketplace.workshopDemand
            .firstWhere((d) => d.providerId == mockIdP10)
            .completedBookings,
        0,
      );
      expect(marketplace.workshopDemand.map((d) => d.providerId),
          isNot(contains(mockIdP11)));

      final ids = marketplace.mostRequestedWorkshops(limit: 20).map(
            (e) => e.provider.id,
          );
      expect(ids, isNot(contains(mockIdP10)));
      expect(ids, isNot(contains(mockIdP11)));
    });

    test('the demand board says when it widened past the governorate',
        () async {
      final container = await createDataContainer();

      container.read(regionProvider.notifier).state = 'Muscat';
      final muscat = container.read(mostRequestedWorkshopsProvider);
      expect(muscat.nationwide, isFalse);
      for (final entry in muscat.items) {
        expect(entry.provider.region, 'Muscat');
      }

      // Ad Dakhiliyah has two approved workshops but only one of them has
      // completed anything, so a local board would be a leaderboard of one —
      // which is a ranking of nobody.
      container.read(regionProvider.notifier).state = 'Ad Dakhiliyah';
      expect(container.read(mostRequestedWorkshopsProvider).nationwide, isTrue);
    });

    test('with no ratings and no bookings, the fallback is approved workshops '
        '— under its own claim', () async {
      final container = await createDataContainer(overrides: [
        serviceMarketplaceServiceProvider.overrideWith(
          (ref) => _NoEvidenceService(),
        ),
      ]);

      // Neither board can be built…
      expect(container.read(topRatedWorkshopsProvider).items, isEmpty);
      expect(container.read(mostRequestedWorkshopsProvider).items, isEmpty);
      // …and what is shown instead is a list of approved workshops, which is a
      // claim the app can actually support.
      final fallback = container.read(approvedWorkshopsProvider);
      expect(fallback, isNotEmpty);
      for (final provider in fallback) {
        expect(provider.isApproved, isTrue);
      }
      // Nearest first — the only ordering available, and not a ranking.
      final distances = [for (final p in fallback) p.distanceKm];
      expect(distances, orderedEquals(<double>[...distances]..sort()));
    });

    test('the rating board still refuses a high score from few reviews',
        () async {
      final container = await createDataContainer();
      final marketplace = container.read(serviceMarketplaceRepositoryProvider);

      for (final entry in marketplace.topRatedWorkshops(limit: 10)) {
        expect(entry.rating.reviews,
            greaterThanOrEqualTo(HomeRankingConfig.minReviewsForRanking));
      }
    });
  });
}
