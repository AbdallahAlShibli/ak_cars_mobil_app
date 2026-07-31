import '../../core/i18n/strings.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/models.dart';

/// How long a booking may sit waiting on one party before its queue card goes
/// red (§3, applied to the operator panels).
///
/// These are the pilot's service levels, not a guess dressed up as one: they
/// are measured against [ServiceRequest.inCurrentStateSince], which comes from
/// the escrow audit trail, so a card only turns red because a real transition
/// really has not happened yet.
///
/// Two windows rather than one. Money moves by hand in the pilot (spec §3,
/// note 2), so a booking waiting on the founder to confirm a transfer is
/// blocking the customer's whole job and is given hours; a booking waiting on
/// a workshop to accept or finish is given a working day.
abstract final class QueueSla {
  /// A booking waiting on the founder — funds confirmation, dispute
  /// resolution. Nothing can proceed until this happens.
  static const founder = Duration(hours: 4);

  /// A booking waiting on the workshop — accept, start, quote, submit proof.
  static const workshop = Duration(hours: 24);

  /// Two-thirds of the way to breaching is where a card starts warning.
  static double get _warnFraction => 2 / 3;

  /// Where [request] sits against its window.
  ///
  /// [waitingOnMe] is false for a row the operator only watches — those are
  /// always [UrgencyLevel.normal], because colouring a row red for a delay the
  /// reader cannot act on trains them to ignore red.
  static UrgencyLevel levelFor(
    ServiceRequest request, {
    required Duration window,
    required bool waitingOnMe,
    DateTime? now,
  }) {
    if (!waitingOnMe) return UrgencyLevel.normal;
    final waited = request.stalledFor(now: now);
    if (waited >= window) return UrgencyLevel.overdue;
    if (waited >= window * _warnFraction) return UrgencyLevel.upcoming;
    return UrgencyLevel.normal;
  }

  /// "3 hours waiting" / "منذ ٣ ساعات" — the number behind the colour, so an
  /// operator can see *why* a card is red rather than trusting that it is.
  static String waitedLabel(S s, ServiceRequest request, {DateTime? now}) {
    final waited = request.stalledFor(now: now);
    if (waited.inHours < 1) {
      final minutes = waited.inMinutes.clamp(0, 59);
      return s.t('منذ $minutes دقيقة', '${minutes}m waiting');
    }
    if (waited.inHours < 24) {
      return s.t('منذ ${waited.inHours} ساعة', '${waited.inHours}h waiting');
    }
    final days = waited.inDays;
    return s.t('منذ ${s.days(days)}', '${s.days(days)} waiting');
  }
}
