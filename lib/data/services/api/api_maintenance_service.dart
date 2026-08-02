import '../../../core/network/api_client.dart';
import '../../models/maintenance.dart';
import '../maintenance_service.dart';

/// Per-car maintenance books over REST (§12).
///
/// Every path here is the one already named in [MaintenanceService]'s own doc
/// comments — the interface was written against these routes from the start,
/// so this implementation is a transcription rather than a design.
///
/// Each call answers with the *whole book* rather than with the patch it
/// applied. That is the interface's contract and it is worth keeping: a client
/// that reconstructs a book from a series of patches is a client that can
/// disagree with the server about what a car's history is.
class ApiMaintenanceService implements MaintenanceService {
  const ApiMaintenanceService(this._client);

  final ApiClient _client;

  static String _book(String carId) => '/user/vehicles/$carId/maintenance';

  @override
  Future<Map<String, MaintenanceBook>> fetchBooks() async {
    final books = await _client.getList('/user/vehicles/maintenance');
    return {
      for (final json in books)
        json['carId'].toString(): MaintenanceBook.fromJson(json),
    };
  }

  @override
  Future<MaintenanceBook> createBook(String carId) async =>
      MaintenanceBook.fromJson(await _client.post(_book(carId)));

  @override
  Future<void> removeBook(String carId) => _client.delete(_book(carId));

  @override
  Future<MaintenanceBook> updateOdometer(String carId, int km) async =>
      MaintenanceBook.fromJson(
        await _client.put('${_book(carId)}/odometer', body: {'km': km}),
      );

  @override
  Future<MaintenanceBook> addRecord(String carId, ServiceRecord record) async =>
      MaintenanceBook.fromJson(
        await _client.post('${_book(carId)}/records', body: record.toJson()),
      );

  @override
  Future<MaintenanceBook> updateRecord(
    String carId,
    ServiceRecord record,
  ) async =>
      MaintenanceBook.fromJson(
        await _client.put(
          '${_book(carId)}/records/${record.id}',
          body: record.toJson(),
        ),
      );

  @override
  Future<MaintenanceBook> removeRecord(String carId, String recordId) async =>
      MaintenanceBook.fromJson(
        await _client.delete('${_book(carId)}/records/$recordId'),
      );

  @override
  Future<MaintenanceBook> setKmInterval(
    String carId,
    String itemKey,
    int? km,
  ) async =>
      MaintenanceBook.fromJson(
        await _client.put(
          '${_book(carId)}/intervals/$itemKey',
          // Sent explicitly as null rather than omitted: null *is* the value
          // here — it clears an override and puts the item back on its
          // default — and an omitted field would read as "leave it alone".
          body: {'km': km},
        ),
      );

  @override
  Future<MaintenanceBook> setMonthInterval(
    String carId,
    String itemKey,
    int? months,
  ) async =>
      MaintenanceBook.fromJson(
        await _client.put(
          '${_book(carId)}/intervals/$itemKey',
          body: {'months': months},
        ),
      );

  @override
  Future<MaintenanceBook> saveCustomItem(
    String carId,
    CustomMaintenanceItem item,
  ) async =>
      MaintenanceBook.fromJson(
        await _client.post('${_book(carId)}/items', body: item.toJson()),
      );

  @override
  Future<MaintenanceBook> removeCustomItem(String carId, String itemId) async =>
      MaintenanceBook.fromJson(
        await _client.delete('${_book(carId)}/items/$itemId'),
      );
}
