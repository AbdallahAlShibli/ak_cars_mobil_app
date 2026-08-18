import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';

/// Why an [InventoryMovement] happened.
enum InventoryMovementReason { purchase, consumed, adjustment, returned }

extension InventoryMovementReasonX on InventoryMovementReason {
  String get key => name;

  String label(S s) => switch (this) {
    InventoryMovementReason.purchase => s.t('شراء', 'Purchase'),
    InventoryMovementReason.consumed => s.t(
      'استُهلك في عمل',
      'Consumed on a job',
    ),
    InventoryMovementReason.adjustment => s.t(
      'تعديل يدوي',
      'Manual adjustment',
    ),
    InventoryMovementReason.returned => s.t('مرتجع', 'Returned'),
  };

  static InventoryMovementReason fromKey(String? key) {
    for (final value in InventoryMovementReason.values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return InventoryMovementReason.adjustment;
  }
}

/// One append-only line in an [InventoryItem]'s stock ledger. The item's
/// `quantityOnHand` is a projection over these — never edited directly — so
/// this is the only place a stock count actually changes.
class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.delta,
    required this.reason,
    this.requestId,
    this.note,
    required this.at,
    required this.byUserId,
  });

  final String id;
  final String itemId;

  /// Positive = stock in, negative = stock out.
  final int delta;
  final InventoryMovementReason reason;

  /// Set when this movement is a job consuming a part — ties the deduction
  /// to the booking it belongs to.
  final String? requestId;
  final String? note;
  final DateTime at;
  final String byUserId;

  factory InventoryMovement.fromJson(JsonMap json) => InventoryMovement(
    id: json.requireString('id'),
    itemId: json.requireString('itemId'),
    delta: json.intOr('delta', 0),
    reason: InventoryMovementReasonX.fromKey(json.stringOrNull('reason')),
    requestId: json.stringOrNull('requestId'),
    note: json.stringOrNull('note'),
    at: json.dateTimeOr('at', DateTime.now()),
    byUserId: json.stringOr('byUserId', ''),
  );

  JsonMap toJson() => {
    'id': id,
    'itemId': itemId,
    'delta': delta,
    'reason': reason.key,
    'requestId': requestId,
    'note': note,
    'at': at.toIso8601String(),
    'byUserId': byUserId,
  };

  @override
  bool operator ==(Object other) =>
      other is InventoryMovement &&
      other.id == id &&
      other.itemId == itemId &&
      other.delta == delta &&
      other.reason == reason &&
      other.requestId == requestId &&
      other.note == note &&
      other.at == at &&
      other.byUserId == byUserId;

  @override
  int get hashCode =>
      Object.hash(id, itemId, delta, reason, requestId, note, at, byUserId);
}
