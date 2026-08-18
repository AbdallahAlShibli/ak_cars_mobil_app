import '../../core/json/json_utils.dart';
import 'service_request.dart';

/// One settled or pending line in a workshop's earnings table (spec §3).
///
/// Carries the booking it came from rather than a copy of its fields, so the
/// row can never drift from the job — the amount on screen is
/// `booking.total`, read live, not a number transcribed at some earlier point.
class EarningsLine {
  const EarningsLine({
    required this.request,
    required this.at,
    required this.gross,
    required this.commission,
    this.pendingOverride,
  });

  final ServiceRequest request;

  /// When the money became this workshop's — the release timestamp for a
  /// settled job, or when the booking entered its current state for one still
  /// held.
  final DateTime at;

  final double gross;
  final double commission;
  final bool? pendingOverride;

  double get net => gross - commission;

  /// True while the customer's money is still held rather than released.
  /// The server sends this explicitly (`pending`); when a line is built
  /// locally instead, it falls back to reading it off the booking's escrow
  /// state.
  bool get pending => pendingOverride ?? !request.escrow.isTerminal;

  factory EarningsLine.fromJson(JsonMap json) => EarningsLine(
    request: ServiceRequest.fromJson(json.requireObject('request')),
    at: json.dateTimeOr('at', DateTime.now()),
    gross: json.doubleOr('gross', 0),
    commission: json.doubleOr('commission', 0),
    pendingOverride: json.boolOrNull('pending'),
  );

  JsonMap toJson() => {
    'request': request.toJson(),
    'at': at.toIso8601String(),
    'gross': gross,
    'commission': commission,
    'pending': pending,
  };
}

/// What a workshop has earned, is owed, and has been charged (spec §3).
///
/// **Computed in `ServiceMarketplaceRepository.earningsFor`, never in a
/// widget** (§14). Every figure is derived from the bookings' own escrow
/// history, so the panel cannot show a total the ledger disagrees with.
///
/// The commission is shown, not buried. A workshop that discovers the platform
/// takes a cut by subtracting two numbers on a statement trusts the platform
/// less than one that was told the rate up front — which is why
/// [totalCommission] is a headline figure here and not a footnote.
class WorkshopEarnings {
  const WorkshopEarnings({
    required this.heldInEscrow,
    required this.releasedGross,
    required this.releasedCommission,
    required this.totalCommission,
    required this.lines,
    required this.window,
  });

  static const empty = WorkshopEarnings(
    heldInEscrow: 0,
    releasedGross: 0,
    releasedCommission: 0,
    totalCommission: 0,
    lines: [],
    window: Duration(days: 30),
  );

  /// The customer's money on this workshop's open jobs — real, and not yet
  /// theirs. Kept separate from everything below because confusing "held" with
  /// "earned" is the single most expensive mistake a workshop can make reading
  /// this screen.
  final double heldInEscrow;

  /// Released to this workshop inside [window], before commission.
  final double releasedGross;

  /// Commission charged on that same window.
  final double releasedCommission;

  /// Commission charged over all time — the transparency figure.
  final double totalCommission;

  /// The most recent transactions, newest first.
  final List<EarningsLine> lines;

  /// How far back [releasedGross] and [releasedCommission] look.
  final Duration window;

  /// What actually reached the workshop in [window].
  double get releasedNet => releasedGross - releasedCommission;

  bool get isEmpty => lines.isEmpty && heldInEscrow == 0;

  factory WorkshopEarnings.fromJson(JsonMap json) => WorkshopEarnings(
    heldInEscrow: json.doubleOr('heldInEscrow', 0),
    releasedGross: json.doubleOr('releasedGross', 0),
    releasedCommission: json.doubleOr('releasedCommission', 0),
    totalCommission: json.doubleOr('totalCommission', 0),
    lines: json.objectList('lines').map(EarningsLine.fromJson).toList(),
    window: Duration(days: json.intOr('windowDays', 30)),
  );

  JsonMap toJson() => {
    'heldInEscrow': heldInEscrow,
    'releasedGross': releasedGross,
    'releasedCommission': releasedCommission,
    'totalCommission': totalCommission,
    'lines': [for (final l in lines) l.toJson()],
    'windowDays': window.inDays,
  };
}
