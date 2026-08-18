import '../../core/json/json_utils.dart';
import 'service_provider.dart';

class WorkshopSummaryJobs {
  const WorkshopSummaryJobs({
    required this.needsYou,
    required this.inProgress,
    required this.awaitingApproval,
    required this.overdue,
    required this.todays,
  });

  final int needsYou;
  final int inProgress;
  final int awaitingApproval;
  final int overdue;
  final int todays;

  factory WorkshopSummaryJobs.fromJson(JsonMap json) => WorkshopSummaryJobs(
    needsYou: json.intOr('needsYou', 0),
    inProgress: json.intOr('inProgress', 0),
    awaitingApproval: json.intOr('awaitingApproval', 0),
    overdue: json.intOr('overdue', 0),
    todays: json.intOr('todays', 0),
  );
}

class WorkshopSummaryMoney {
  const WorkshopSummaryMoney({
    required this.heldInEscrow,
    required this.releasedGross,
    required this.totalCommission,
    required this.payoutDue,
  });

  final double heldInEscrow;
  final double releasedGross;
  final double totalCommission;
  final double payoutDue;

  factory WorkshopSummaryMoney.fromJson(JsonMap json) => WorkshopSummaryMoney(
    heldInEscrow: json.doubleOr('heldInEscrow', 0),
    releasedGross: json.doubleOr('releasedGross', 0),
    totalCommission: json.doubleOr('totalCommission', 0),
    payoutDue: json.doubleOr('payoutDue', 0),
  );
}

class WorkshopSummaryStock {
  const WorkshopSummaryStock({
    required this.items,
    required this.lowStock,
    required this.outOfStock,
    required this.stockValue,
  });

  final int items;
  final int lowStock;
  final int outOfStock;
  final double stockValue;

  factory WorkshopSummaryStock.fromJson(JsonMap json) => WorkshopSummaryStock(
    items: json.intOr('items', 0),
    lowStock: json.intOr('lowStock', 0),
    outOfStock: json.intOr('outOfStock', 0),
    stockValue: json.doubleOr('stockValue', 0),
  );
}

class WorkshopSummaryPeople {
  const WorkshopSummaryPeople({
    required this.activeStaff,
    required this.customers,
    required this.repeatRate,
  });

  final int activeStaff;
  final int customers;
  final double repeatRate;

  factory WorkshopSummaryPeople.fromJson(JsonMap json) => WorkshopSummaryPeople(
    activeStaff: json.intOr('activeStaff', 0),
    customers: json.intOr('customers', 0),
    repeatRate: json.doubleOr('repeatRate', 0),
  );
}

class WorkshopSummaryRating {
  const WorkshopSummaryRating({
    this.avg,
    required this.reviewCount,
    this.acceptanceRate,
    this.avgResponseMinutes,
  });

  final double? avg;
  final int reviewCount;
  final double? acceptanceRate;
  final double? avgResponseMinutes;

  factory WorkshopSummaryRating.fromJson(JsonMap json) => WorkshopSummaryRating(
    avg: json.doubleOrNull('avg'),
    reviewCount: json.intOr('reviewCount', 0),
    acceptanceRate: json.doubleOrNull('acceptanceRate'),
    avgResponseMinutes: json.doubleOrNull('avgResponseMinutes'),
  );
}

/// One alert the dashboard's alerts strip renders, deep-linking into the
/// offending list. `code` is a stable key (`low_stock`, `overdue_jobs`, …),
/// not display text.
class WorkshopAlert {
  const WorkshopAlert({required this.code, required this.count});

  final String code;
  final int count;

  factory WorkshopAlert.fromJson(JsonMap json) => WorkshopAlert(
    code: json.stringOr('code', ''),
    count: json.intOr('count', 0),
  );
}

/// One payload the dashboard home renders without a second round trip —
/// see `GET /my-workshop/summary` in docs/api_contract.md.
class WorkshopSummary {
  const WorkshopSummary({
    required this.provider,
    required this.jobs,
    required this.money,
    required this.stock,
    required this.people,
    required this.rating,
    this.alerts = const [],
  });

  final ServiceProvider provider;
  final WorkshopSummaryJobs jobs;
  final WorkshopSummaryMoney money;
  final WorkshopSummaryStock stock;
  final WorkshopSummaryPeople people;
  final WorkshopSummaryRating rating;
  final List<WorkshopAlert> alerts;

  factory WorkshopSummary.fromJson(JsonMap json) => WorkshopSummary(
    provider: ServiceProvider.fromJson(json.requireObject('provider')),
    jobs: WorkshopSummaryJobs.fromJson(json.requireObject('jobs')),
    money: WorkshopSummaryMoney.fromJson(json.requireObject('money')),
    stock: WorkshopSummaryStock.fromJson(json.requireObject('stock')),
    people: WorkshopSummaryPeople.fromJson(json.requireObject('people')),
    rating: WorkshopSummaryRating.fromJson(json.requireObject('rating')),
    alerts: json.objectList('alerts').map(WorkshopAlert.fromJson).toList(),
  );
}
