import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/home_ranking_config.dart';
import '../data/models/car.dart';
import '../data/models/maintenance.dart';
import '../data/models/promotion.dart';
import '../data/models/recommendation.dart';
import '../data/models/service_provider.dart';
import '../data/repositories/service_marketplace_repository.dart';
import '../di/providers.dart';
import 'garage_state.dart';
import 'maintenance_state.dart';
import 'offers_state.dart';
import 'settings_state.dart';

/// One number, fixed for the lifetime of the app process.
///
/// The home page's recommendation rail is meant to vary between launches. It
/// must *not* vary between rebuilds: a list that reshuffled every time the user
/// scrolled, changed language or opened a sheet would look broken, and a test
/// could not assert anything about it. So the randomness is drawn once, here,
/// and every consumer derives from it — reading the clock inside a `build` is
/// what makes a widget unrepeatable.
///
/// Override it in a test to pin the order.
final sessionSeedProvider = Provider<int>(
  (ref) => DateTime.now().millisecondsSinceEpoch,
);

/// Platform announcements for the user's governorate and their car.
///
/// These carry no price — how escrow works, which workshops collect a car.
/// Discounts are [homeOffersProvider], and the two are kept apart on purpose:
/// the offers section must be able to hide itself when nothing is discounted
/// (spec §2), which it could not do if an announcement counted as an offer.
final homePromotionsProvider = Provider<List<Promotion>>((ref) {
  final region = ref.watch(regionProvider);
  return ref.watch(serviceMarketplaceRepositoryProvider).promotions(
        region: region.isEmpty ? null : region,
        powertrain: ref.watch(primaryPowertrainProvider),
      );
});

/// This week's real discounts — the home page's section 2.
///
/// Every entry has passed all six validation rules in the repository, so the
/// rail cannot show an ended campaign, an unapproved workshop, a service that
/// is not listed, or a "discount" that does not reduce anything. Empty is a
/// normal answer, and the section hides itself rather than showing a heading
/// over nothing.
final homeOffersProvider = Provider<List<LiveOffer>>((ref) {
  // A founder switching an offer on or off is reflected here on the next
  // frame — see `offersRevisionProvider`.
  ref.watch(offersRevisionProvider);
  final region = ref.watch(regionProvider);
  return ref.watch(serviceMarketplaceRepositoryProvider).liveOffers(
        region: region.isEmpty ? null : region,
        powertrain: ref.watch(primaryPowertrainProvider),
      );
});

/// Announcements minus anything a live offer already says better.
///
/// A workshop that is running a real discount on its major service should not
/// also occupy a card announcing that same service at full price — the user
/// would read two cards about one thing and wonder which price is true.
final homeAnnouncementsProvider = Provider<List<Promotion>>((ref) {
  final superseded = {
    for (final live in ref.watch(homeOffersProvider)) live.offering.id,
  };
  return [
    for (final promotion in ref.watch(homePromotionsProvider))
      if (!superseded.contains(promotion.offeringId)) promotion,
  ];
});

/// The single most urgent maintenance line across the whole garage, with the
/// car it belongs to — what the home page's hero card leads with.
///
/// Null with an empty garage, and null when no car has a record to count down
/// from: both are states the page renders as an invitation rather than as a
/// number it does not have.
typedef NextService = ({Car car, DueItem item});

final nextServiceDueProvider = Provider<NextService?>((ref) {
  NextService? soonest;
  for (final car in ref.watch(garageProvider)) {
    final due = ref.watch(maintenanceDueForCarProvider(car.id));
    for (final item in due.byUrgency) {
      // No record means no countdown; those are handled by the card's own
      // "add your last service" state, not ranked here.
      final progress = item.progress;
      if (progress == null) continue;
      if (soonest == null || progress > (soonest.item.progress ?? 0)) {
        soonest = (car: car, item: item);
      }
      break;
    }
  }
  return soonest;
});

/// "Recommended for your car" — see [buildRecommendations] for the rule.
///
/// Empty with an empty garage, and deliberately so: there is no car to
/// recommend anything for, and the page shows the "add your car" card instead
/// of generic advice.
final homeRecommendationsProvider = Provider<List<Recommendation>>((ref) {
  final cars = ref.watch(garageProvider);
  if (cars.isEmpty) return const [];

  final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
  final region = ref.watch(regionProvider);
  final scope = region.isEmpty ? null : region;

  return buildRecommendations(
    cars: cars,
    dueFor: (car) => ref.watch(maintenanceDueForCarProvider(car.id)),
    categoriesFor: (car) => marketplace.categoriesFor(car.powertrain),
    market: (categoryId) {
      final cheapest =
          marketplace.cheapestOfferingFor(categoryId, region: scope);
      return (
        fromPrice: marketplace.fromPriceFor(categoryId, region: scope),
        workshops: marketplace.providerCountFor(categoryId, region: scope),
        offeringId: cheapest?.id,
      );
    },
    demand: marketplace.categoryDemand,
    seed: ref.watch(sessionSeedProvider),
  );
});

/// The marketplace's most-booked categories, minus any the user's car cannot
/// book. The counts themselves stay marketplace-wide — that is what they
/// measure.
final mostBookedServicesProvider = Provider<List<RankedCategory>>((ref) {
  return ref.watch(serviceMarketplaceRepositoryProvider).mostBookedCategories(
        powertrain: ref.watch(primaryPowertrainProvider),
      );
});

/// A rating leaderboard, and whether it had to widen to see one.
///
/// [nationwide] is true when the selected governorate had too few rated
/// workshops to rank and the board fell back to the whole country. The screen
/// says which of the two it is showing — "top rated in Muscat" and "top rated
/// in Oman" are different claims, and a silent widening makes the app look like
/// it is ignoring the region filter.
typedef RatingBoard = ({List<RankedWorkshop> items, bool nationwide});

/// Top-rated workshops in the user's governorate, widening only when it cannot
/// fill a board.
final topRatedWorkshopsProvider = Provider<RatingBoard>((ref) {
  final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
  final region = ref.watch(regionProvider);
  const size = HomeRankingConfig.workshopBoardSize;

  if (region.isNotEmpty) {
    final local = marketplace.topRatedWorkshops(region: region, limit: size);
    if (local.length >= 2) return (items: local, nationwide: false);
  }
  return (
    items: marketplace.topRatedWorkshops(limit: size),
    nationwide: true,
  );
});

/// A demand leaderboard, and whether it had to widen to fill one. Same shape
/// and same widening rule as [RatingBoard], for the same reason: "most
/// requested in Muscat" and "most requested in Oman" are different claims.
typedef DemandBoard = ({List<RequestedWorkshop> items, bool nationwide});

/// Workshops ranked by the bookings they actually completed (spec §4).
final mostRequestedWorkshopsProvider = Provider<DemandBoard>((ref) {
  final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
  final region = ref.watch(regionProvider);
  const size = HomeRankingConfig.workshopBoardSize;

  if (region.isNotEmpty) {
    final local =
        marketplace.mostRequestedWorkshops(region: region, limit: size);
    if (local.length >= 2) return (items: local, nationwide: false);
  }
  return (
    items: marketplace.mostRequestedWorkshops(limit: size),
    nationwide: true,
  );
});

/// Approved workshops, nearest first — what the trusted-workshops section
/// falls back to before the marketplace has enough ratings to rank anything
/// (spec §5).
///
/// Shown under its own heading ("ورش معتمدة قريبة منك"), never under "الأعلى
/// تقييماً": a section title that claims data the app does not have is the one
/// thing the spec is most explicit about forbidding.
final approvedWorkshopsProvider = Provider<List<ServiceProvider>>((ref) {
  final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
  final region = ref.watch(regionProvider);
  const size = HomeRankingConfig.workshopBoardSize;

  if (region.isNotEmpty) {
    final local = marketplace.approvedWorkshops(region: region, limit: size);
    if (local.isNotEmpty) return local;
  }
  return marketplace.approvedWorkshops(limit: size);
});
