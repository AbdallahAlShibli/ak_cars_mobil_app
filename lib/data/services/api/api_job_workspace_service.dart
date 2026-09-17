import '../../../core/constants/api_endpoints.dart';
import '../../../core/json/json_utils.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/guid.dart';
import '../../models/models.dart';
import '../job_workspace_service.dart';

/// The job workspace over REST. Same conventions as [ApiWorkshopService]: one
/// call per method, `?key: ?value` to leave a null out of the body rather than
/// sending it.
class ApiJobWorkspaceService implements JobWorkspaceService {
  const ApiJobWorkspaceService(this._client);

  final ApiClient _client;

  /// The server binds each photo's id as a GUID and assigns its own on save,
  /// so anything that is not one is replaced rather than sent to fail binding.
  static List<JsonMap> _media(List<MediaAttachment> photos) => [
    for (final p in photos) {...p.toJson(), 'id': coerceGuid(p.id)},
  ];

  // ------------------------------------------------------------ workshop

  @override
  Future<VehicleCheckIn> saveCheckIn(
    String requestId, {
    int? odometerKm,
    FuelLevel? fuelLevel,
    String exteriorNotes = '',
    String belongings = '',
    List<MediaAttachment> photos = const [],
  }) async => VehicleCheckIn.fromJson(
    await _client.put(
      ApiEndpoints.jobCheckIn(requestId),
      body: {
        'odometerKm': ?odometerKm,
        'fuelLevel': ?fuelLevel?.name,
        'exteriorNotes': exteriorNotes,
        'belongings': belongings,
        'photos': _media(photos),
      },
    ),
  );

  @override
  Future<List<InspectionItem>> replaceInspection(
    String requestId,
    List<InspectionItem> items,
  ) async => (await _client.putList(
    ApiEndpoints.jobInspection(requestId),
    body: {
      'items': [
        for (final item in items)
          {
            'id': ?(item.id != null && isGuid(item.id!) ? item.id : null),
            'name': item.name,
            'status': item.status.name,
            'note': item.note,
            'photos': _media(item.photos),
          },
      ],
    },
  )).map(InspectionItem.fromJson).toList();

  @override
  Future<ExtraWorkRequest> createExtraWork(
    String requestId, {
    required String description,
    required double partsPrice,
    required double laborPrice,
    String? inspectionItemId,
    List<MediaAttachment> photos = const [],
  }) async => ExtraWorkRequest.fromJson(
    await _client.post(
      ApiEndpoints.jobExtraWork(requestId),
      body: {
        'description': description,
        'partsPrice': partsPrice,
        'laborPrice': laborPrice,
        'inspectionItemId': ?inspectionItemId,
        'photos': _media(photos),
      },
    ),
  );

  @override
  Future<ExtraWorkRequest> withdrawExtraWork(
    String requestId,
    String extraId,
  ) async => ExtraWorkRequest.fromJson(
    await _client.post(ApiEndpoints.jobExtraWorkWithdraw(requestId, extraId)),
  );

  @override
  Future<JobCard> getJobCard(String requestId) async =>
      JobCard.fromJson(await _client.get(ApiEndpoints.jobCard(requestId)));

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
  }) async => JobCard.fromJson(
    await _client.post(
      ApiEndpoints.jobCardLines(requestId),
      body: {
        'kind': kind.name,
        'description': ?description,
        'quantity': quantity,
        'unitPrice': ?unitPrice,
        'unitCost': ?unitCost,
        'inventoryItemId': ?inventoryItemId,
        'staffId': ?staffId,
      },
    ),
  );

  @override
  Future<JobCard> deleteJobCardLine(String requestId, String lineId) async =>
      JobCard.fromJson(
        await _client.delete(ApiEndpoints.jobCardLine(requestId, lineId)),
      );

  @override
  Future<Invoice> issueInvoice(String requestId) async => Invoice.fromJson(
    await _client.post(ApiEndpoints.jobInvoiceIssue(requestId)),
  );

  // ------------------------------------------------------------ customer

  @override
  Future<ExtraWorkRequest> respondToExtraWork(
    String requestId,
    String extraId, {
    required bool approve,
    String? note,
  }) async => ExtraWorkRequest.fromJson(
    await _client.post(
      ApiEndpoints.extraWorkRespond(requestId, extraId),
      body: {'approve': approve, 'note': ?note},
    ),
  );

  @override
  Future<Invoice> getInvoice(String requestId) async => Invoice.fromJson(
    await _client.get(ApiEndpoints.requestInvoice(requestId)),
  );

  // ------------------------------------------------------------- founder

  @override
  Future<List<WorkshopPerformanceRow>> getWorkshopPerformance({
    int windowDays = 30,
  }) async => (await _client.getList(
    ApiEndpoints.adminWorkshopPerformance,
    queryParameters: {'windowDays': windowDays},
  )).map(WorkshopPerformanceRow.fromJson).toList();

  @override
  Future<List<ExtraWorkQueueItem>> getExtraWorkQueue({
    ExtraWorkStatus? status,
  }) async => (await _client.getList(
    ApiEndpoints.adminExtraWork,
    queryParameters: {'status': ?status?.name},
  )).map(ExtraWorkQueueItem.fromJson).toList();

  @override
  Future<ExtraWorkRequest> confirmExtraWorkFunds(String extraId) async =>
      ExtraWorkRequest.fromJson(
        await _client.post(ApiEndpoints.adminExtraWorkConfirmFunds(extraId)),
      );

  @override
  Future<JobCard> getJobCardAsFounder(String requestId) async =>
      JobCard.fromJson(await _client.get(ApiEndpoints.adminJobCard(requestId)));
}
