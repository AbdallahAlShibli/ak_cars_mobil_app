import 'package:ak_cars_mobil_app/core/json/json_utils.dart';
import 'package:ak_cars_mobil_app/core/network/api_client.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/data/services/api/api_job_workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The job workspace (2026-09-15): the models read the API's DTOs, tolerate an
/// API that predates them, and the REST service sends the bodies the API binds.
void main() {
  group('models', () {
    test('extra work reads the API shape and derives its amount', () {
      final extra = ExtraWorkRequest.fromJson({
        'id': 'e1',
        'requestId': 'r1',
        'description': 'Front pads',
        'partsPrice': 8.5,
        'laborPrice': 3.5,
        'amount': 12,
        'status': 'approved',
        'photos': <Object>[],
        'createdAt': '2026-09-15T10:00:00Z',
      });

      expect(extra.amount, 12);
      expect(extra.status, ExtraWorkStatus.approved);
      expect(extra.countsTowardTotal, isTrue);
      expect(extra.isPending, isFalse);
    });

    test('an unknown status or fuel level falls back instead of throwing', () {
      final extra = ExtraWorkRequest.fromJson({'id': 'e1', 'status': 'mystery'});
      final checkIn = VehicleCheckIn.fromJson({
        'id': 'c1',
        'fuelLevel': 'overflowing',
        'odometerKm': 120500,
      });

      expect(extra.status, ExtraWorkStatus.pending);
      expect(checkIn.fuelLevel, isNull);
      expect(checkIn.odometerKm, 120500);
    });

    test('threeQuarters round-trips with the API spelling', () {
      final checkIn = VehicleCheckIn.fromJson({
        'id': 'c1',
        'fuelLevel': 'threeQuarters',
      });
      expect(checkIn.fuelLevel, FuelLevel.threeQuarters);
      expect(checkIn.toJson()['fuelLevel'], 'threeQuarters');
    });

    test('invoice keeps bilingual lines and the tax flag', () {
      final invoice = Invoice.fromJson({
        'id': 'i1',
        'requestId': 'r1',
        'number': 'INV-098105-2026-000001',
        'issuedAt': '2026-09-15T10:00:00Z',
        'sellerName': {'ar': 'ورشة', 'en': 'Workshop'},
        'sellerVatNumber': 'OM123',
        'buyerName': 'Sara',
        'plate': '1234 AB',
        'lines': [
          {'description': {'ar': 'تغيير زيت', 'en': 'Oil change'}, 'amount': 21},
        ],
        'subtotal': 20,
        'vatRate': 0.05,
        'vatAmount': 1,
        'total': 21,
        'isTaxInvoice': true,
      });

      expect(invoice.isTaxInvoice, isTrue);
      expect(invoice.lines.single.description.en, 'Oil change');
      expect(invoice.vatAmount, 1);
    });

    test('workshop metrics without business KPIs parse as before', () {
      final old = WorkshopMetrics.fromJson({'received': 3, 'accepted': 2});
      final current = WorkshopMetrics.fromJson({
        'received': 3,
        'business': {'carCount': 4, 'checkInCoverage': 0.5},
      });

      expect(old.business, isNull);
      expect(current.business!.carCount, 4);
      expect(current.business!.checkInCoverage, 0.5);
      expect(current.business!.averageRepairOrder, isNull);
    });
  });

  group('ApiJobWorkspaceService', () {
    test('check-in sends the API field names and omits nulls', () async {
      final client = _RecordingClient();
      await ApiJobWorkspaceService(client).saveCheckIn(
        'r1',
        fuelLevel: FuelLevel.half,
        exteriorNotes: 'Scratch on rear bumper',
      );

      final call = client.calls.single;
      expect(call.method, 'PUT');
      expect(call.path, '/service-marketplace/my-workshop/requests/r1/check-in');
      final body = call.body! as Map;
      expect(body['fuelLevel'], 'half');
      expect(body.containsKey('odometerKm'), isFalse);
      expect(body['photos'], isEmpty);
    });

    test('a photo with a non-GUID id is re-keyed before it is sent', () async {
      final client = _RecordingClient();
      await ApiJobWorkspaceService(client).createExtraWork(
        'r1',
        description: 'Pads',
        partsPrice: 8,
        laborPrice: 4,
        photos: const [
          MediaAttachment(
            id: 'legacy-1',
            base64Data: 'AAAA',
            mimeType: 'image/jpeg',
            fileName: 'a.jpg',
          ),
        ],
      );

      final body = client.calls.single.body! as Map;
      final photo = (body['photos'] as List).single as Map;
      expect(photo['id'], isNot('legacy-1'));
      expect(photo['id'], hasLength(36));
      expect(body.containsKey('inspectionItemId'), isFalse);
    });

    test('inspection replaces the list with PUT and keeps known ids', () async {
      final client = _RecordingClient();
      await ApiJobWorkspaceService(client).replaceInspection('r1', const [
        InspectionItem(
          id: '3f2a7c1e-8b4d-4e9a-a5f0-2c6d1b7e4a93',
          name: 'Brakes',
          status: InspectionStatus.urgent,
        ),
        InspectionItem(name: 'Tyres'),
      ]);

      final call = client.calls.single;
      expect(call.method, 'PUT-LIST');
      final items = (call.body! as Map)['items'] as List;
      expect((items[0] as Map)['id'], '3f2a7c1e-8b4d-4e9a-a5f0-2c6d1b7e4a93');
      expect((items[0] as Map)['status'], 'urgent');
      expect((items[1] as Map).containsKey('id'), isFalse);
    });

    test('the customer answer and the founder queue hit their routes', () async {
      final client = _RecordingClient();
      final service = ApiJobWorkspaceService(client);
      await service.respondToExtraWork('r1', 'e1', approve: false);
      await service.getExtraWorkQueue(status: ExtraWorkStatus.approved);

      expect(
        client.calls[0].path,
        '/service-marketplace/requests/r1/extra-work/e1/respond',
      );
      expect(client.calls[0].body, {'approve': false});
      expect(client.calls[1].path, '/service-marketplace/admin/extra-work');
      expect(client.calls[1].query, {'status': 'approved'});
    });
  });
}

typedef _Call = ({String method, String path, Object? body, Map<String, dynamic>? query});

/// Records every call and answers with a minimal valid record.
class _RecordingClient implements ApiClient {
  final calls = <_Call>[];

  static final JsonMap _record = {'id': 'x1', 'requestId': 'r1'};

  JsonMap _answer(String method, String path, Object? body, Map<String, dynamic>? query) {
    calls.add((method: method, path: path, body: body, query: query));
    return _record;
  }

  @override
  Future<JsonMap> get(String path, {Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async =>
      _answer('GET', path, null, queryParameters);

  @override
  Future<JsonMap> post(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async =>
      _answer('POST', path, body, queryParameters);

  @override
  Future<JsonMap> put(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async =>
      _answer('PUT', path, body, queryParameters);

  @override
  Future<JsonMap> patch(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async =>
      _answer('PATCH', path, body, queryParameters);

  @override
  Future<JsonMap> delete(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async =>
      _answer('DELETE', path, body, queryParameters);

  @override
  Future<List<JsonMap>> getList(String path, {Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async {
    _answer('GET-LIST', path, null, queryParameters);
    return const [];
  }

  @override
  Future<List<JsonMap>> postList(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async {
    _answer('POST-LIST', path, body, queryParameters);
    return const [];
  }

  @override
  Future<List<JsonMap>> putList(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async {
    _answer('PUT-LIST', path, body, queryParameters);
    return const [];
  }

  @override
  Future<List<JsonMap>> deleteList(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async {
    _answer('DELETE-LIST', path, body, queryParameters);
    return const [];
  }
}
