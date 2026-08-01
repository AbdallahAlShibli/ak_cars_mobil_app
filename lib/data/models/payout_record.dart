import '../../core/json/json_utils.dart';

/// One transfer to one workshop, as the founder recorded it (spec §5, tab 3).
///
/// **This is a note, not a transaction.** In the pilot the money moves by hand
/// — a bank transfer the founder makes outside the app — and this record says
/// only "I did that, on this date, for this period". Nothing in the app moves
/// a rial, and every screen that renders one of these says so.
///
/// Kept separate from [Offer]-style platform state on purpose: it is written
/// once and never edited. Correcting a mistaken payout means writing another
/// record, which is why [markedAt] is the entry's own timestamp rather than
/// the transfer's.
class PayoutRecord {
  const PayoutRecord({
    required this.id,
    required this.providerId,
    required this.amount,
    required this.periodFrom,
    required this.periodTo,
    required this.markedAt,
    this.note,
  });

  final String id;
  final String providerId;

  /// What was transferred, in OMR — net of commission. The gross and the
  /// commission are recomputed from the bookings in the period rather than
  /// stored here, so a payout can never quietly disagree with the ledger it
  /// settles.
  final double amount;

  /// The window of released bookings this settles, inclusive of [periodFrom]
  /// and exclusive of [periodTo].
  final DateTime periodFrom;
  final DateTime periodTo;

  /// When the founder pressed the button — not when the bank moved the money,
  /// which the app has no way to know and therefore does not claim.
  final DateTime markedAt;

  /// Free text — a bank reference, or why the amount differs from the
  /// computed one.
  final String? note;

  /// True when [at] falls inside the settled window.
  bool covers(DateTime at) => !at.isBefore(periodFrom) && at.isBefore(periodTo);

  factory PayoutRecord.fromJson(JsonMap json) => PayoutRecord(
        id: json.requireString('id'),
        providerId: json.stringOr('providerId', ''),
        amount: json.doubleOr('amount', 0),
        periodFrom: json.dateTimeOr('periodFrom', DateTime.now()),
        periodTo: json.dateTimeOr('periodTo', DateTime.now()),
        markedAt: json.dateTimeOr('markedAt', DateTime.now()),
        note: json.stringOrNull('note'),
      );

  JsonMap toJson() => {
        'id': id,
        'providerId': providerId,
        'amount': amount,
        'periodFrom': periodFrom.toIso8601String(),
        'periodTo': periodTo.toIso8601String(),
        'markedAt': markedAt.toIso8601String(),
        'note': note,
      };

  PayoutRecord copyWith({
    String? id,
    String? providerId,
    double? amount,
    DateTime? periodFrom,
    DateTime? periodTo,
    DateTime? markedAt,
    String? note,
  }) =>
      PayoutRecord(
        id: id ?? this.id,
        providerId: providerId ?? this.providerId,
        amount: amount ?? this.amount,
        periodFrom: periodFrom ?? this.periodFrom,
        periodTo: periodTo ?? this.periodTo,
        markedAt: markedAt ?? this.markedAt,
        note: note ?? this.note,
      );

  @override
  bool operator ==(Object other) =>
      other is PayoutRecord &&
      other.id == id &&
      other.providerId == providerId &&
      other.amount == amount &&
      other.periodFrom == periodFrom &&
      other.periodTo == periodTo &&
      other.markedAt == markedAt &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
      id, providerId, amount, periodFrom, periodTo, markedAt, note);
}

extension PayoutRecordListX on Iterable<PayoutRecord> {
  /// Everything paid to one workshop.
  List<PayoutRecord> forProvider(String providerId) =>
      [for (final p in this) if (p.providerId == providerId) p];

  /// Total already settled — subtracted from a workshop's released earnings to
  /// get what is still owed.
  double get total => fold<double>(0, (sum, p) => sum + p.amount);

  List<PayoutRecord> get newestFirst {
    final sorted = [...this]..sort((a, b) => b.markedAt.compareTo(a.markedAt));
    return sorted;
  }
}
