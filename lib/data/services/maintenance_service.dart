import '../../config/app_config.dart';
import '../datasources/mock/mock_garage_data.dart';
import '../models/maintenance.dart';
import 'mock_service_base.dart';

/// The user's maintenance book.
///
/// Everything here comes from data the *user* enters (odometer readings,
/// manual records) plus service records created inside the app — the app
/// never reads anything from the car itself.
///
/// Phase 2: implement `RestMaintenanceService` against `/maintenance`.
abstract interface class MaintenanceService {
  Future<MaintenanceLog> fetchLog();

  Future<MaintenanceLog> updateOdometer(int km);

  Future<MaintenanceLog> addRecord(ServiceRecord record);

  Future<MaintenanceLog> setKmInterval(MaintenanceType type, int km);

  Future<MaintenanceLog> setMonthInterval(MaintenanceType type, int months);
}

class MockMaintenanceService
    with MockServiceBase
    implements MaintenanceService {
  MockMaintenanceService({required this.config});

  @override
  final AppConfig config;

  late MaintenanceLog _log = MockGarageData.maintenanceLog();

  @override
  Future<MaintenanceLog> fetchLog() => respond(_log);

  @override
  Future<MaintenanceLog> updateOdometer(int km) {
    if (km > 0) {
      _log = _log.copyWith(
        currentOdometerKm: km,
        odometerUpdatedAt: DateTime.now(),
      );
    }
    return respond(_log);
  }

  @override
  Future<MaintenanceLog> addRecord(ServiceRecord record) {
    _log = _log.copyWith(records: [record, ..._log.records]);
    return respond(_log);
  }

  @override
  Future<MaintenanceLog> setKmInterval(MaintenanceType type, int km) {
    _log = _log.copyWith(kmIntervals: {..._log.kmIntervals, type: km});
    return respond(_log);
  }

  @override
  Future<MaintenanceLog> setMonthInterval(MaintenanceType type, int months) {
    _log = _log.copyWith(monthIntervals: {..._log.monthIntervals, type: months});
    return respond(_log);
  }
}
