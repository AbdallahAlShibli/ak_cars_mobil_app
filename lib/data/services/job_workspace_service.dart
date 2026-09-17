import '../models/models.dart';

/// Transport-agnostic contract for the job workspace (2026-09-15): check-in,
/// inspection, extra work, job card and invoice, for the three people who
/// touch a booking while the car is in the workshop.
///
/// Its own interface rather than more members on [WorkshopService] or
/// [ServiceMarketplaceService]: it spans all three audiences, and folding it
/// into either would force every existing implementation and test double of
/// those to change for a feature they have nothing to do with.
///
/// The server decides who may call what from the caller's relationship to the
/// booking; the grouping below is only who the app shows each call to.
abstract interface class JobWorkspaceService {
  // ------------------------------------------------------------ workshop
  Future<VehicleCheckIn> saveCheckIn(
    String requestId, {
    int? odometerKm,
    FuelLevel? fuelLevel,
    String exteriorNotes = '',
    String belongings = '',
    List<MediaAttachment> photos = const [],
  });

  /// Replaces the whole inspection. Items that carry an id keep it.
  Future<List<InspectionItem>> replaceInspection(
    String requestId,
    List<InspectionItem> items,
  );

  Future<ExtraWorkRequest> createExtraWork(
    String requestId, {
    required String description,
    required double partsPrice,
    required double laborPrice,
    String? inspectionItemId,
    List<MediaAttachment> photos = const [],
  });

  Future<ExtraWorkRequest> withdrawExtraWork(String requestId, String extraId);

  Future<JobCard> getJobCard(String requestId);

  /// [unitPrice]/[unitCost] may be left null for a part picked from stock —
  /// the server fills them from the inventory item.
  Future<JobCard> addJobCardLine(
    String requestId, {
    required JobLineKind kind,
    String? description,
    required double quantity,
    double? unitPrice,
    double? unitCost,
    String? inventoryItemId,
    String? staffId,
  });

  Future<JobCard> deleteJobCardLine(String requestId, String lineId);

  /// Idempotent: a second call returns the invoice the first one issued.
  Future<Invoice> issueInvoice(String requestId);

  // ------------------------------------------------------------ customer
  Future<ExtraWorkRequest> respondToExtraWork(
    String requestId,
    String extraId, {
    required bool approve,
    String? note,
  });

  /// The customer, the booking's workshop and the founder may all read it.
  Future<Invoice> getInvoice(String requestId);

  // ------------------------------------------------------------- founder
  Future<List<WorkshopPerformanceRow>> getWorkshopPerformance({
    int windowDays = 30,
  });

  /// Defaults server-side to `approved` — the ones waiting on the founder.
  Future<List<ExtraWorkQueueItem>> getExtraWorkQueue({ExtraWorkStatus? status});

  Future<ExtraWorkRequest> confirmExtraWorkFunds(String extraId);

  Future<JobCard> getJobCardAsFounder(String requestId);
}
