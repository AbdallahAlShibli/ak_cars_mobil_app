import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'media_attachment.dart';

/// The job workspace (2026-09-15): what a workshop records about a booking
/// while the car is with it — check-in, inspection, extra work, job card and
/// invoice — plus the KPIs and founder views built on them.
///
/// Mirrors the API's `JobWorkspace` DTOs. Every field the API may omit has a
/// safe default, so this build talking to an API from before the feature
/// simply shows nothing rather than failing to parse a booking.

T? _enumOrNull<T extends Enum>(List<T> values, String? key) {
  for (final value in values) {
    if (value.name == key) return value;
  }
  return null;
}

// ------------------------------------------------------------------ enums

enum FuelLevel { empty, quarter, half, threeQuarters, full }

extension FuelLevelX on FuelLevel {
  L get label => switch (this) {
    FuelLevel.empty => const L('فارغ', 'Empty'),
    FuelLevel.quarter => const L('ربع', '¼'),
    FuelLevel.half => const L('نصف', '½'),
    FuelLevel.threeQuarters => const L('ثلاثة أرباع', '¾'),
    FuelLevel.full => const L('ممتلئ', 'Full'),
  };

  static FuelLevel? fromKey(String? key) => _enumOrNull(FuelLevel.values, key);
}

enum InspectionStatus { good, attention, urgent }

extension InspectionStatusX on InspectionStatus {
  L get label => switch (this) {
    InspectionStatus.good => const L('سليم', 'Good'),
    InspectionStatus.attention => const L('يحتاج متابعة', 'Needs attention'),
    InspectionStatus.urgent => const L('عاجل', 'Urgent'),
  };

  static InspectionStatus fromKey(String? key) =>
      _enumOrNull(InspectionStatus.values, key) ?? InspectionStatus.good;
}

enum ExtraWorkStatus { pending, approved, funded, declined, withdrawn }

extension ExtraWorkStatusX on ExtraWorkStatus {
  L get label => switch (this) {
    ExtraWorkStatus.pending => const L('بانتظار موافقة العميل', 'Awaiting the customer'),
    ExtraWorkStatus.approved => const L('وافق العميل — بانتظار حجز المبلغ', 'Approved — awaiting funds'),
    ExtraWorkStatus.funded => const L('المبلغ محجوز — يمكن البدء', 'Funded — ready to start'),
    ExtraWorkStatus.declined => const L('رفضه العميل', 'Declined'),
    ExtraWorkStatus.withdrawn => const L('سُحب', 'Withdrawn'),
  };

  static ExtraWorkStatus fromKey(String? key) =>
      _enumOrNull(ExtraWorkStatus.values, key) ?? ExtraWorkStatus.pending;
}

enum JobLineKind { labour, part }

extension JobLineKindX on JobLineKind {
  L get label => switch (this) {
    JobLineKind.labour => const L('عمالة', 'Labour'),
    JobLineKind.part => const L('قطعة', 'Part'),
  };

  static JobLineKind fromKey(String? key) =>
      _enumOrNull(JobLineKind.values, key) ?? JobLineKind.labour;
}

// ---------------------------------------------------------------- records

/// What the car was like when the workshop took it. One per booking.
class VehicleCheckIn {
  const VehicleCheckIn({
    required this.id,
    required this.requestId,
    required this.recordedAt,
    this.odometerKm,
    this.fuelLevel,
    this.exteriorNotes = '',
    this.belongings = '',
    this.photos = const [],
  });

  final String id;
  final String requestId;
  final int? odometerKm;
  final FuelLevel? fuelLevel;
  final String exteriorNotes;
  final String belongings;
  final List<MediaAttachment> photos;
  final DateTime recordedAt;

  factory VehicleCheckIn.fromJson(JsonMap json) => VehicleCheckIn(
    id: json.requireString('id'),
    requestId: json.stringOr('requestId', ''),
    odometerKm: json.intOrNull('odometerKm'),
    fuelLevel: FuelLevelX.fromKey(json.stringOrNull('fuelLevel')),
    exteriorNotes: json.stringOr('exteriorNotes', ''),
    belongings: json.stringOr('belongings', ''),
    photos: json.objectList('photos').map(MediaAttachment.fromJson).toList(),
    recordedAt: json.dateTimeOr('recordedAt', DateTime.now()),
  );

  JsonMap toJson() => {
    'id': id,
    'requestId': requestId,
    'odometerKm': odometerKm,
    'fuelLevel': fuelLevel?.name,
    'exteriorNotes': exteriorNotes,
    'belongings': belongings,
    'photos': [for (final p in photos) p.toJson()],
    'recordedAt': recordedAt.toIso8601String(),
  };
}

/// One line of the inspection. [id] is null on a line not yet saved.
class InspectionItem {
  const InspectionItem({
    this.id,
    required this.name,
    this.status = InspectionStatus.good,
    this.note = '',
    this.photos = const [],
    this.sortOrder = 0,
    this.inspectedAt,
  });

  final String? id;
  final String name;
  final InspectionStatus status;
  final String note;
  final List<MediaAttachment> photos;
  final int sortOrder;
  final DateTime? inspectedAt;

  factory InspectionItem.fromJson(JsonMap json) => InspectionItem(
    id: json.stringOrNull('id'),
    name: json.stringOr('name', ''),
    status: InspectionStatusX.fromKey(json.stringOrNull('status')),
    note: json.stringOr('note', ''),
    photos: json.objectList('photos').map(MediaAttachment.fromJson).toList(),
    sortOrder: json.intOr('sortOrder', 0),
    inspectedAt: json.dateTimeOrNull('inspectedAt'),
  );

  /// The shape `PUT .../inspection` takes for one item.
  JsonMap toJson() => {
    'id': id,
    'name': name,
    'status': status.name,
    'note': note,
    'photos': [for (final p in photos) p.toJson()],
  };

  InspectionItem copyWith({
    String? name,
    InspectionStatus? status,
    String? note,
    List<MediaAttachment>? photos,
  }) => InspectionItem(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    note: note ?? this.note,
    photos: photos ?? this.photos,
    sortOrder: sortOrder,
    inspectedAt: inspectedAt,
  );
}

/// Work found mid-job that the customer did not book.
class ExtraWorkRequest {
  const ExtraWorkRequest({
    required this.id,
    required this.requestId,
    required this.description,
    required this.partsPrice,
    required this.laborPrice,
    required this.status,
    required this.createdAt,
    this.inspectionItemId,
    this.photos = const [],
    this.respondedAt,
    this.customerNote,
    this.fundedAt,
  });

  final String id;
  final String requestId;
  final String description;
  final double partsPrice;
  final double laborPrice;
  final String? inspectionItemId;
  final ExtraWorkStatus status;
  final List<MediaAttachment> photos;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? customerNote;
  final DateTime? fundedAt;

  double get amount => partsPrice + laborPrice;

  bool get isPending => status == ExtraWorkStatus.pending;

  /// Approved or funded — already part of the booking's total.
  bool get countsTowardTotal =>
      status == ExtraWorkStatus.approved || status == ExtraWorkStatus.funded;

  factory ExtraWorkRequest.fromJson(JsonMap json) => ExtraWorkRequest(
    id: json.requireString('id'),
    requestId: json.stringOr('requestId', ''),
    description: json.stringOr('description', ''),
    partsPrice: json.doubleOr('partsPrice', 0),
    laborPrice: json.doubleOr('laborPrice', 0),
    inspectionItemId: json.stringOrNull('inspectionItemId'),
    status: ExtraWorkStatusX.fromKey(json.stringOrNull('status')),
    photos: json.objectList('photos').map(MediaAttachment.fromJson).toList(),
    createdAt: json.dateTimeOr('createdAt', DateTime.now()),
    respondedAt: json.dateTimeOrNull('respondedAt'),
    customerNote: json.stringOrNull('customerNote'),
    fundedAt: json.dateTimeOrNull('fundedAt'),
  );

  JsonMap toJson() => {
    'id': id,
    'requestId': requestId,
    'description': description,
    'partsPrice': partsPrice,
    'laborPrice': laborPrice,
    'amount': amount,
    'inspectionItemId': inspectionItemId,
    'status': status.name,
    'photos': [for (final p in photos) p.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
    'customerNote': customerNote,
    'fundedAt': fundedAt?.toIso8601String(),
  };
}

class JobCardLine {
  const JobCardLine({
    required this.id,
    required this.kind,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.createdAt,
    this.inventoryItemId,
    this.staffId,
  });

  final String id;
  final JobLineKind kind;
  final String description;

  /// Hours for labour, units for a part.
  final double quantity;
  final double unitPrice;
  final double unitCost;
  final String? inventoryItemId;
  final String? staffId;
  final DateTime createdAt;

  double get revenue => quantity * unitPrice;
  double get cost => quantity * unitCost;

  factory JobCardLine.fromJson(JsonMap json) => JobCardLine(
    id: json.requireString('id'),
    kind: JobLineKindX.fromKey(json.stringOrNull('kind')),
    description: json.stringOr('description', ''),
    quantity: json.doubleOr('quantity', 0),
    unitPrice: json.doubleOr('unitPrice', 0),
    unitCost: json.doubleOr('unitCost', 0),
    inventoryItemId: json.stringOrNull('inventoryItemId'),
    staffId: json.stringOrNull('staffId'),
    createdAt: json.dateTimeOr('createdAt', DateTime.now()),
  );

  JsonMap toJson() => {
    'id': id,
    'kind': kind.name,
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'unitCost': unitCost,
    'inventoryItemId': inventoryItemId,
    'staffId': staffId,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Internal to the workshop — it carries costs, so the customer never sees it.
class JobCard {
  const JobCard({
    required this.requestId,
    this.lines = const [],
    this.labourRevenue = 0,
    this.partsRevenue = 0,
    this.partsCost = 0,
    this.grossProfit = 0,
  });

  final String requestId;
  final List<JobCardLine> lines;
  final double labourRevenue;
  final double partsRevenue;
  final double partsCost;

  /// Revenue minus the parts' cost. Labour cost (wages) is not recorded, so it
  /// is not subtracted — the screen says so.
  final double grossProfit;

  factory JobCard.fromJson(JsonMap json) => JobCard(
    requestId: json.stringOr('requestId', ''),
    lines: json.objectList('lines').map(JobCardLine.fromJson).toList(),
    labourRevenue: json.doubleOr('labourRevenue', 0),
    partsRevenue: json.doubleOr('partsRevenue', 0),
    partsCost: json.doubleOr('partsCost', 0),
    grossProfit: json.doubleOr('grossProfit', 0),
  );

  JsonMap toJson() => {
    'requestId': requestId,
    'lines': [for (final l in lines) l.toJson()],
    'labourRevenue': labourRevenue,
    'partsRevenue': partsRevenue,
    'partsCost': partsCost,
    'grossProfit': grossProfit,
  };
}

class InvoiceLine {
  const InvoiceLine({required this.description, required this.amount});

  final L description;
  final double amount;

  factory InvoiceLine.fromJson(JsonMap json) => InvoiceLine(
    description: L.fromJson(json['description']),
    amount: json.doubleOr('amount', 0),
  );

  JsonMap toJson() => {'description': description.toJson(), 'amount': amount};
}

/// A frozen snapshot, issued once per booking. Oman consumer prices are
/// VAT-inclusive, so [total] is what was paid and [vatAmount] is the 5/105
/// share inside it — or 0 on a simplified receipt from a workshop with no VAT
/// number.
class Invoice {
  const Invoice({
    required this.id,
    required this.requestId,
    required this.number,
    required this.issuedAt,
    required this.sellerName,
    required this.buyerName,
    required this.plate,
    required this.lines,
    required this.subtotal,
    required this.vatRate,
    required this.vatAmount,
    required this.total,
    required this.isTaxInvoice,
    this.sellerVatNumber,
    this.sellerCrNumber,
  });

  final String id;
  final String requestId;
  final String number;
  final DateTime issuedAt;
  final L sellerName;
  final String? sellerVatNumber;
  final String? sellerCrNumber;
  final String buyerName;
  final String plate;
  final List<InvoiceLine> lines;
  final double subtotal;
  final double vatRate;
  final double vatAmount;
  final double total;
  final bool isTaxInvoice;

  factory Invoice.fromJson(JsonMap json) => Invoice(
    id: json.requireString('id'),
    requestId: json.stringOr('requestId', ''),
    number: json.stringOr('number', ''),
    issuedAt: json.dateTimeOr('issuedAt', DateTime.now()),
    sellerName: L.fromJson(json['sellerName']),
    sellerVatNumber: json.stringOrNull('sellerVatNumber'),
    sellerCrNumber: json.stringOrNull('sellerCrNumber'),
    buyerName: json.stringOr('buyerName', ''),
    plate: json.stringOr('plate', ''),
    lines: json.objectList('lines').map(InvoiceLine.fromJson).toList(),
    subtotal: json.doubleOr('subtotal', 0),
    vatRate: json.doubleOr('vatRate', 0),
    vatAmount: json.doubleOr('vatAmount', 0),
    total: json.doubleOr('total', 0),
    isTaxInvoice: json.boolOr('isTaxInvoice', false),
  );

  JsonMap toJson() => {
    'id': id,
    'requestId': requestId,
    'number': number,
    'issuedAt': issuedAt.toIso8601String(),
    'sellerName': sellerName.toJson(),
    'sellerVatNumber': sellerVatNumber,
    'sellerCrNumber': sellerCrNumber,
    'buyerName': buyerName,
    'plate': plate,
    'lines': [for (final l in lines) l.toJson()],
    'subtotal': subtotal,
    'vatRate': vatRate,
    'vatAmount': vatAmount,
    'total': total,
    'isTaxInvoice': isTaxInvoice,
  };
}

// ------------------------------------------------------------------- KPIs

/// Shop-management KPIs. Rates are 0..1 and null when there is nothing to
/// divide by — shown as "—", never as a misleading 0%.
class WorkshopBusinessKpis {
  const WorkshopBusinessKpis({
    this.averageRepairOrder,
    this.carCount = 0,
    this.repeatCustomerRate,
    this.extraWorkApprovalRate,
    this.extraWorkRevenue = 0,
    this.labourRevenue = 0,
    this.partsRevenue = 0,
    this.partsCost = 0,
    this.grossProfit = 0,
    this.checkInCoverage,
    this.avgDaysInShop,
  });

  final double? averageRepairOrder;
  final int carCount;
  final double? repeatCustomerRate;
  final double? extraWorkApprovalRate;
  final double extraWorkRevenue;
  final double labourRevenue;
  final double partsRevenue;
  final double partsCost;
  final double grossProfit;
  final double? checkInCoverage;
  final double? avgDaysInShop;

  factory WorkshopBusinessKpis.fromJson(JsonMap json) => WorkshopBusinessKpis(
    averageRepairOrder: json.doubleOrNull('averageRepairOrder'),
    carCount: json.intOr('carCount', 0),
    repeatCustomerRate: json.doubleOrNull('repeatCustomerRate'),
    extraWorkApprovalRate: json.doubleOrNull('extraWorkApprovalRate'),
    extraWorkRevenue: json.doubleOr('extraWorkRevenue', 0),
    labourRevenue: json.doubleOr('labourRevenue', 0),
    partsRevenue: json.doubleOr('partsRevenue', 0),
    partsCost: json.doubleOr('partsCost', 0),
    grossProfit: json.doubleOr('grossProfit', 0),
    checkInCoverage: json.doubleOrNull('checkInCoverage'),
    avgDaysInShop: json.doubleOrNull('avgDaysInShop'),
  );

  JsonMap toJson() => {
    'averageRepairOrder': averageRepairOrder,
    'carCount': carCount,
    'repeatCustomerRate': repeatCustomerRate,
    'extraWorkApprovalRate': extraWorkApprovalRate,
    'extraWorkRevenue': extraWorkRevenue,
    'labourRevenue': labourRevenue,
    'partsRevenue': partsRevenue,
    'partsCost': partsCost,
    'grossProfit': grossProfit,
    'checkInCoverage': checkInCoverage,
    'avgDaysInShop': avgDaysInShop,
  };
}

/// One workshop's row in the founder's performance table.
class WorkshopPerformanceRow {
  const WorkshopPerformanceRow({
    required this.providerId,
    required this.name,
    this.region = '',
    this.completed = 0,
    this.releasedGross = 0,
    this.averageRepairOrder,
    this.carCount = 0,
    this.disputeRate,
    this.extraWorkApprovalRate,
    this.checkInCoverage,
    this.avgRating,
    this.reviewCount = 0,
  });

  final String providerId;
  final L name;
  final String region;
  final int completed;
  final double releasedGross;
  final double? averageRepairOrder;
  final int carCount;
  final double? disputeRate;
  final double? extraWorkApprovalRate;
  final double? checkInCoverage;
  final double? avgRating;
  final int reviewCount;

  factory WorkshopPerformanceRow.fromJson(JsonMap json) => WorkshopPerformanceRow(
    providerId: json.requireString('providerId'),
    name: L.fromJson(json['name']),
    region: json.stringOr('region', ''),
    completed: json.intOr('completed', 0),
    releasedGross: json.doubleOr('releasedGross', 0),
    averageRepairOrder: json.doubleOrNull('averageRepairOrder'),
    carCount: json.intOr('carCount', 0),
    disputeRate: json.doubleOrNull('disputeRate'),
    extraWorkApprovalRate: json.doubleOrNull('extraWorkApprovalRate'),
    checkInCoverage: json.doubleOrNull('checkInCoverage'),
    avgRating: json.doubleOrNull('avgRating'),
    reviewCount: json.intOr('reviewCount', 0),
  );
}

/// One row of the founder's extra-work funding queue.
class ExtraWorkQueueItem {
  const ExtraWorkQueueItem({
    required this.extraWork,
    required this.providerId,
    required this.providerName,
    required this.plate,
    required this.customerId,
    required this.customerName,
  });

  final ExtraWorkRequest extraWork;
  final String providerId;
  final L providerName;
  final String plate;
  final String customerId;
  final String customerName;

  factory ExtraWorkQueueItem.fromJson(JsonMap json) => ExtraWorkQueueItem(
    extraWork: ExtraWorkRequest.fromJson(json.requireObject('extraWork')),
    providerId: json.stringOr('providerId', ''),
    providerName: L.fromJson(json['providerName']),
    plate: json.stringOr('plate', ''),
    customerId: json.stringOr('customerId', ''),
    customerName: json.stringOr('customerName', ''),
  );
}
