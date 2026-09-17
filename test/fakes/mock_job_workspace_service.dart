import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/utils/guid.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/data/services/job_workspace_service.dart';

import 'fake_service_base.dart';

/// An in-memory job workspace. Starts empty, so a screen that reads it renders
/// its empty state; a test that wants rows writes them through the same calls
/// the app makes.
class MockJobWorkspaceService with MockServiceBase implements JobWorkspaceService {
  final Map<String, VehicleCheckIn> _checkIns = {};
  final Map<String, List<InspectionItem>> _inspections = {};
  final Map<String, List<ExtraWorkRequest>> _extraWork = {};
  final Map<String, List<JobCardLine>> _lines = {};
  final Map<String, Invoice> _invoices = {};

  @override
  Future<VehicleCheckIn> saveCheckIn(
    String requestId, {
    int? odometerKm,
    FuelLevel? fuelLevel,
    String exteriorNotes = '',
    String belongings = '',
    List<MediaAttachment> photos = const [],
  }) => respond(
    _checkIns[requestId] = VehicleCheckIn(
      id: _checkIns[requestId]?.id ?? newGuid(),
      requestId: requestId,
      odometerKm: odometerKm,
      fuelLevel: fuelLevel,
      exteriorNotes: exteriorNotes,
      belongings: belongings,
      photos: photos,
      recordedAt: DateTime.now(),
    ),
  );

  @override
  Future<List<InspectionItem>> replaceInspection(
    String requestId,
    List<InspectionItem> items,
  ) => respond(
    _inspections[requestId] = [
      for (final (i, item) in items.indexed)
        InspectionItem(
          id: item.id ?? newGuid(),
          name: item.name,
          status: item.status,
          note: item.note,
          photos: item.photos,
          sortOrder: i,
          inspectedAt: DateTime.now(),
        ),
    ],
  );

  @override
  Future<ExtraWorkRequest> createExtraWork(
    String requestId, {
    required String description,
    required double partsPrice,
    required double laborPrice,
    String? inspectionItemId,
    List<MediaAttachment> photos = const [],
  }) {
    final created = ExtraWorkRequest(
      id: newGuid(),
      requestId: requestId,
      description: description,
      partsPrice: partsPrice,
      laborPrice: laborPrice,
      inspectionItemId: inspectionItemId,
      status: ExtraWorkStatus.pending,
      photos: photos,
      createdAt: DateTime.now(),
    );
    _extraWork[requestId] = [created, ...?_extraWork[requestId]];
    return respond(created);
  }

  ExtraWorkRequest _move(
    String requestId,
    String extraId,
    ExtraWorkStatus from,
    ExtraWorkStatus to,
  ) {
    final list = _extraWork[requestId] ?? const <ExtraWorkRequest>[];
    final current = list.where((e) => e.id == extraId).firstOrNull;
    if (current == null) throw const NotFoundException('extra work not found');
    if (current.status != from) {
      throw const BusinessRuleException('extra_work_not_pending');
    }
    final moved = ExtraWorkRequest(
      id: current.id,
      requestId: current.requestId,
      description: current.description,
      partsPrice: current.partsPrice,
      laborPrice: current.laborPrice,
      inspectionItemId: current.inspectionItemId,
      status: to,
      photos: current.photos,
      createdAt: current.createdAt,
      respondedAt: DateTime.now(),
      fundedAt: to == ExtraWorkStatus.funded ? DateTime.now() : null,
    );
    _extraWork[requestId] = [
      for (final e in list) e.id == extraId ? moved : e,
    ];
    return moved;
  }

  @override
  Future<ExtraWorkRequest> withdrawExtraWork(String requestId, String extraId) =>
      respond(
        _move(requestId, extraId, ExtraWorkStatus.pending, ExtraWorkStatus.withdrawn),
      );

  JobCard _card(String requestId) {
    final lines = _lines[requestId] ?? const <JobCardLine>[];
    double sum(Iterable<double> v) => v.fold(0, (a, b) => a + b);
    final labour = sum(lines.where((l) => l.kind == JobLineKind.labour).map((l) => l.revenue));
    final parts = sum(lines.where((l) => l.kind == JobLineKind.part).map((l) => l.revenue));
    final partsCost = sum(lines.where((l) => l.kind == JobLineKind.part).map((l) => l.cost));
    return JobCard(
      requestId: requestId,
      lines: lines,
      labourRevenue: labour,
      partsRevenue: parts,
      partsCost: partsCost,
      grossProfit: labour + parts - partsCost,
    );
  }

  @override
  Future<JobCard> getJobCard(String requestId) => respond(_card(requestId));

  @override
  Future<JobCard> addJobCardLine(
    String requestId, {
    required JobLineKind kind,
    String? description,
    required double quantity,
    double? unitPrice,
    double? unitCost,
    String? inventoryItemId,
    String? staffId,
  }) {
    _lines[requestId] = [
      ...?_lines[requestId],
      JobCardLine(
        id: newGuid(),
        kind: kind,
        description: description ?? '',
        quantity: quantity,
        unitPrice: unitPrice ?? 0,
        unitCost: unitCost ?? 0,
        inventoryItemId: inventoryItemId,
        staffId: staffId,
        createdAt: DateTime.now(),
      ),
    ];
    return respond(_card(requestId));
  }

  @override
  Future<JobCard> deleteJobCardLine(String requestId, String lineId) {
    _lines[requestId] = [
      for (final l in _lines[requestId] ?? const <JobCardLine>[])
        if (l.id != lineId) l,
    ];
    return respond(_card(requestId));
  }

  @override
  Future<Invoice> issueInvoice(String requestId) => respond(
    _invoices[requestId] ??= Invoice(
      id: newGuid(),
      requestId: requestId,
      number: 'INV-TEST00-2026-${(_invoices.length + 1).toString().padLeft(6, '0')}',
      issuedAt: DateTime.now(),
      sellerName: const L('ورشة', 'Workshop'),
      buyerName: 'Customer',
      plate: '',
      lines: const [],
      subtotal: 0,
      vatRate: 0,
      vatAmount: 0,
      total: 0,
      isTaxInvoice: false,
    ),
  );

  @override
  Future<ExtraWorkRequest> respondToExtraWork(
    String requestId,
    String extraId, {
    required bool approve,
    String? note,
  }) => respond(
    _move(
      requestId,
      extraId,
      ExtraWorkStatus.pending,
      approve ? ExtraWorkStatus.approved : ExtraWorkStatus.declined,
    ),
  );

  @override
  Future<Invoice> getInvoice(String requestId) =>
      respondRequired(_invoices[requestId], 'invoice');

  @override
  Future<List<WorkshopPerformanceRow>> getWorkshopPerformance({
    int windowDays = 30,
  }) => respond(const []);

  @override
  Future<List<ExtraWorkQueueItem>> getExtraWorkQueue({
    ExtraWorkStatus? status,
  }) => respond(const []);

  @override
  Future<ExtraWorkRequest> confirmExtraWorkFunds(String extraId) {
    for (final entry in _extraWork.entries) {
      if (entry.value.any((e) => e.id == extraId)) {
        return respond(
          _move(entry.key, extraId, ExtraWorkStatus.approved, ExtraWorkStatus.funded),
        );
      }
    }
    throw const NotFoundException('extra work not found');
  }

  @override
  Future<JobCard> getJobCardAsFounder(String requestId) =>
      respond(_card(requestId));
}
