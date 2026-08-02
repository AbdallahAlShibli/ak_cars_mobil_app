import 'dart:math';

import 'car.dart';
import 'maintenance.dart';
import 'powertrain.dart';
import 'service_category.dart';
import 'service_stats.dart';

/// Why a service was recommended. Every value is a fact the app can point at,
/// which is the whole constraint on this file: a recommendation the app cannot
/// justify on screen is a guess dressed as advice.
///
/// Order is significance order — [dueNow] outranks [popular] — and
/// [buildRecommendations] ranks by it.
enum RecommendationReason {
  /// The car's own schedule says this item is due, from the owner's mileage.
  dueNow,

  /// Same source, not yet due.
  dueSoon,

  /// A service that exists only for a car that plugs in, and this one does.
  ///
  /// Ranked above [noRecord] deliberately. "This car plugs in" is a fact about
  /// the vehicle; "we have no record of this item" is a fact about our own
  /// ignorance, and it is true of *every* item on a car registered five minutes
  /// ago — so ranking it higher would fill the rail of a fresh garage with
  /// identical "no record yet" cards and bury the work that is actually
  /// specific to the car.
  electric,

  /// A schedule line this car has never had a record for.
  noRecord,

  /// The marketplace's own booking counter — see [CategoryDemand].
  popular,
}

/// What one recommendation card renders.
///
/// It carries the numbers rather than the widget deriving them, so the reason
/// text, the price and the tap target cannot disagree with each other.
class Recommendation {
  const Recommendation({
    required this.car,
    required this.category,
    required this.reason,
    this.due,
    this.bookings,
    this.windowDays,
    this.fromPrice,
    this.workshops = 0,
    this.offeringId,
  });

  /// The registered car this is for — printed on the card, because advice for
  /// the Patrol shown under the Camry is advice about the wrong car.
  final Car car;

  final ServiceCategory category;
  final RecommendationReason reason;

  /// The schedule line behind a [RecommendationReason.dueNow] /
  /// [RecommendationReason.dueSoon] / [RecommendationReason.noRecord] card.
  final DueItem? due;

  /// Bookings behind a [RecommendationReason.popular] card, over
  /// [windowDays].
  final int? bookings;
  final int? windowDays;

  /// Cheapest real price in the user's scope, or null when everything in scope
  /// is quote-only. Never a guessed "from" figure.
  final double? fromPrice;

  /// How many workshops in scope sell it.
  final int workshops;

  /// The cheapest offering, so a tap opens a real service page instead of a
  /// search the user has to sift.
  final String? offeringId;

  /// True when the card is telling the owner something about their own car
  /// rather than about the marketplace.
  bool get fromOwnCar => due != null;

  @override
  bool operator ==(Object other) =>
      other is Recommendation &&
      other.car == car &&
      other.category == category &&
      other.reason == reason &&
      other.due?.key == due?.key &&
      other.bookings == bookings &&
      other.windowDays == windowDays &&
      other.fromPrice == fromPrice &&
      other.workshops == workshops &&
      other.offeringId == offeringId;

  @override
  int get hashCode => Object.hash(car, category, reason, due?.key, bookings,
      windowDays, fromPrice, workshops, offeringId);
}

/// What the marketplace can tell us about one category in the user's scope.
typedef CategoryMarket = ({double? fromPrice, int workshops, String? offeringId});

/// Builds the home page's "recommended for your car" rail.
///
/// A pure function of the data handed in — the same shape as
/// `calculateRequestTotal` — so the ordering rule is testable without a widget
/// tree, and so the state layer stays free of data logic.
///
/// **The rule.** Candidates are the categories each car can actually book
/// ([categoriesFor], already powertrain-filtered), and only those a workshop in
/// scope actually sells ([market] reporting `workshops > 0`). Each candidate is
/// tagged with the strongest reason that applies to it, and the list is ranked
/// by that reason.
///
/// **Where [seed] comes in.** The request was for a rail that changes every
/// time the app opens. It shuffles *within* a reason band, never across one, so
/// a genuinely overdue oil change cannot be pushed below "most booked this
/// month" by a dice roll. Pass a per-launch seed (see `sessionSeedProvider`);
/// passing a constant makes the output deterministic, which is what the tests
/// do.
///
/// [perCar] keeps a three-car garage from filling the whole rail with the first
/// car — each car gets its most significant items, then the next car's.
List<Recommendation> buildRecommendations({
  required List<Car> cars,
  required List<DueItem> Function(Car car) dueFor,
  required List<ServiceCategory> Function(Car car) categoriesFor,
  required CategoryMarket Function(String categoryId) market,
  required List<CategoryDemand> demand,
  required int seed,
  int limit = 6,
  int perCar = 2,
}) {
  if (cars.isEmpty) return const [];

  final demandById = {for (final d in demand) d.categoryId: d};
  final random = Random(seed);
  final perCarPicks = <String, List<Recommendation>>{};

  for (final car in cars) {
    final due = dueFor(car);
    // One card per schedule line: "Major service", "Full service" and "Express
    // service" all reset the same engine-oil line, and three cards saying "no
    // record for engine oil" is one recommendation printed three times. The
    // cheapest wins — the rail is a suggestion, not an upsell.
    final byItem = <String, Recommendation>{};
    final unmapped = <Recommendation>[];

    for (final category in categoriesFor(car)) {
      // A roadside callout is not a recommendation — it is what you tap when
      // you are already stranded, and putting it in a "you might need this"
      // rail reads as a prediction the app cannot make.
      if (category.emergency) continue;

      // An oil-change package on an electric car is the nudge an EV owner
      // should never get, even though the marketplace will still sell it to
      // them if they go looking.
      if (!categoryServes(category, car.powertrain)) continue;

      // The schedule line this category is *about*, if any.
      final type = MaintenanceTypeX.forCategory(category.slug);

      final scope = market(category.id);
      // Nothing in scope sells it: recommending it would send the user to an
      // empty list.
      if (scope.workshops == 0) continue;

      final item = type == null ? null : due.byKey(type.key);
      final reason = _reasonFor(category, item, demandById[category.id]);
      if (reason == null) continue;

      final popular = reason == RecommendationReason.popular
          ? demandById[category.id]
          : null;

      final candidate = Recommendation(
        car: car,
        category: category,
        reason: reason,
        due: item,
        bookings: popular?.bookings,
        windowDays: popular?.windowDays,
        fromPrice: scope.fromPrice,
        workshops: scope.workshops,
        offeringId: scope.offeringId,
      );

      if (type == null) {
        unmapped.add(candidate);
        continue;
      }
      final held = byItem[type.key];
      if (held == null || _cheaperThan(candidate, held)) {
        byItem[type.key] = candidate;
      }
    }

    final candidates = [...byItem.values, ...unmapped];
    // Shuffle first, then a stable sort by reason: ties keep the shuffled
    // order, which is exactly "vary the rail without reordering what matters".
    candidates.shuffle(random);
    _sortByReason(candidates);
    perCarPicks[car.id] = candidates.take(perCar).toList();
  }

  // Round-robin across the cars so the rail opens with every car's most
  // significant item before it shows anyone's second.
  final ordered = <Recommendation>[];
  for (var rank = 0; rank < perCar; rank++) {
    for (final car in cars) {
      final picks = perCarPicks[car.id] ?? const <Recommendation>[];
      if (rank < picks.length) ordered.add(picks[rank]);
    }
  }
  return ordered.take(limit).toList(growable: false);
}

/// Whether a category is work a car with this [powertrain] can use.
///
/// Two rules, and deliberately only two:
///
/// - the category's own restriction ([ServiceCategory.appliesTo]) — a
///   high-voltage battery diagnostic is not something a petrol car can book;
/// - an oil-change package is not for a car with no engine.
///
/// It does **not** consult [MaintenanceTypeX.appliesTo], which answers a
/// different question: whether an item is tracked as its *own schedule line*.
/// That one says "no" to the cabin filter and the 12V battery on a petrol car,
/// because there they are checked inside the oil service rather than counted
/// down separately. AC care and a battery swap are still work a petrol owner
/// books — using that predicate as a relevance filter would hide two of the
/// most booked services in Oman from most of the country.
bool categoryServes(ServiceCategory category, Powertrain? powertrain) {
  if (!category.appliesTo(powertrain)) return false;
  if (MaintenanceTypeX.forCategory(category.slug) != MaintenanceType.oil) {
    return true;
  }
  // Unrecorded powertrain behaves like a combustion car, as everywhere else.
  return powertrain?.hasEngine ?? true;
}

/// True when [a] is the better-priced of two candidates for the same schedule
/// line. A quote-only offering loses to any priced one, and wins only against
/// another quote-only one.
bool _cheaperThan(Recommendation a, Recommendation b) {
  final priceA = a.fromPrice;
  final priceB = b.fromPrice;
  if (priceA == null) return false;
  if (priceB == null) return true;
  return priceA < priceB;
}

RecommendationReason? _reasonFor(
  ServiceCategory category,
  DueItem? item,
  CategoryDemand? demand,
) {
  if (item != null) {
    switch (item.status) {
      case DueStatus.due:
        return RecommendationReason.dueNow;
      case DueStatus.near:
        return RecommendationReason.dueSoon;
      case DueStatus.noRecord:
        return RecommendationReason.noRecord;
      case DueStatus.good:
        // In good order on the owner's own numbers. Recommending it anyway
        // would be selling them something they do not need yet — it can still
        // appear below on its popularity, if it has any.
        break;
    }
  }
  if (category.evOnly) return RecommendationReason.electric;
  if (demand != null && demand.bookings > 0) {
    return RecommendationReason.popular;
  }
  return null;
}

void _sortByReason(List<Recommendation> list) {
  // A stable sort — `List.sort` is not guaranteed stable, so rank by the
  // enum index paired with the current position.
  final indexed = [
    for (final (i, r) in list.indexed) (i, r),
  ]..sort((a, b) {
      final byReason = a.$2.reason.index.compareTo(b.$2.reason.index);
      return byReason != 0 ? byReason : a.$1.compareTo(b.$1);
    });
  list.setRange(0, list.length, [for (final entry in indexed) entry.$2]);
}
