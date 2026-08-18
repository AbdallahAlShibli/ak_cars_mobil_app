import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';

/// Unit an [InventoryItem]'s quantity is counted in.
enum InventoryUnit { piece, litre, set }

extension InventoryUnitX on InventoryUnit {
  String get key => name;

  String label(S s) => switch (this) {
    InventoryUnit.piece => s.t('قطعة', 'piece'),
    InventoryUnit.litre => s.t('لتر', 'litre'),
    InventoryUnit.set => s.t('طقم', 'set'),
  };

  static InventoryUnit fromKey(String? key) {
    for (final value in InventoryUnit.values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return InventoryUnit.piece;
  }
}

/// One stock line in a workshop's own inventory. Quantity is never edited
/// directly here — it only ever moves through an [InventoryMovement], so two
/// concurrent "sold one" writes cannot silently lose a unit (see the backend's
/// `RecordInventoryMovementCommand`, which re-sums the movement ledger on
/// every write rather than trusting the stored count).
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    this.partNumber,
    this.brand,
    this.categoryId,
    required this.unitCost,
    required this.sellPrice,
    required this.quantityOnHand,
    required this.reorderLevel,
    this.unit = InventoryUnit.piece,
    this.location,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final L name;
  final String sku;
  final String? partNumber;
  final String? brand;
  final String? categoryId;
  final double unitCost;
  final double sellPrice;
  final int quantityOnHand;
  final int reorderLevel;
  final InventoryUnit unit;
  final String? location;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Mirrors the server's own `IsLowStock` — kept as a getter, not a stored
  /// field, so it can never drift from [quantityOnHand]/[reorderLevel].
  bool get isLowStock => quantityOnHand <= reorderLevel;

  bool get isOutOfStock => quantityOnHand == 0;

  double get stockValue => quantityOnHand * unitCost;

  factory InventoryItem.fromJson(JsonMap json) => InventoryItem(
    id: json.requireString('id'),
    name: L.fromJson(json['name']),
    sku: json.stringOr('sku', ''),
    partNumber: json.stringOrNull('partNumber'),
    brand: json.stringOrNull('brand'),
    categoryId: json.stringOrNull('categoryId'),
    unitCost: json.doubleOr('unitCost', 0),
    sellPrice: json.doubleOr('sellPrice', 0),
    quantityOnHand: json.intOr('quantityOnHand', 0),
    reorderLevel: json.intOr('reorderLevel', 0),
    unit: InventoryUnitX.fromKey(json.stringOrNull('unit')),
    location: json.stringOrNull('location'),
    isActive: json.boolOr('isActive', true),
    createdAt: json.dateTimeOr('createdAt', DateTime.now()),
    updatedAt: json.dateTimeOr('updatedAt', DateTime.now()),
  );

  JsonMap toJson() => {
    'id': id,
    'name': name.toJson(),
    'sku': sku,
    'partNumber': partNumber,
    'brand': brand,
    'categoryId': categoryId,
    'unitCost': unitCost,
    'sellPrice': sellPrice,
    'quantityOnHand': quantityOnHand,
    'reorderLevel': reorderLevel,
    'unit': unit.key,
    'location': location,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  InventoryItem copyWith({
    String? id,
    L? name,
    String? sku,
    String? partNumber,
    String? brand,
    String? categoryId,
    double? unitCost,
    double? sellPrice,
    int? quantityOnHand,
    int? reorderLevel,
    InventoryUnit? unit,
    String? location,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => InventoryItem(
    id: id ?? this.id,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    partNumber: partNumber ?? this.partNumber,
    brand: brand ?? this.brand,
    categoryId: categoryId ?? this.categoryId,
    unitCost: unitCost ?? this.unitCost,
    sellPrice: sellPrice ?? this.sellPrice,
    quantityOnHand: quantityOnHand ?? this.quantityOnHand,
    reorderLevel: reorderLevel ?? this.reorderLevel,
    unit: unit ?? this.unit,
    location: location ?? this.location,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is InventoryItem &&
      other.id == id &&
      other.name == name &&
      other.sku == sku &&
      other.partNumber == partNumber &&
      other.brand == brand &&
      other.categoryId == categoryId &&
      other.unitCost == unitCost &&
      other.sellPrice == sellPrice &&
      other.quantityOnHand == quantityOnHand &&
      other.reorderLevel == reorderLevel &&
      other.unit == unit &&
      other.location == location &&
      other.isActive == isActive &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sku,
    partNumber,
    brand,
    categoryId,
    unitCost,
    sellPrice,
    quantityOnHand,
    reorderLevel,
    unit,
    location,
    isActive,
    createdAt,
    updatedAt,
  );
}
