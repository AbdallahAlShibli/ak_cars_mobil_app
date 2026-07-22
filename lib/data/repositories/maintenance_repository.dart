import '../models/maintenance.dart';
import '../services/maintenance_service.dart';
import 'warm_cache.dart';

/// The user's maintenance book, plus the countdown it implies.
///
/// [dueItems] is the domain rule the maintenance screen renders: remaining =
/// interval − (currentOdometer − lastServiceOdometer), with month-based items
/// measured from the record date instead. It lives here, not in a widget or a
/// Riverpod provider, so it is unit-testable without a widget tree and so a
/// server-computed version can replace it without touching the UI.
abstract interface class MaintenanceRepository {
  /// Loads the log so [log] can be read synchronously on the first frame.
  Future<void> warmUp();

  /// The log as of the last load. The maintenance and home screens read this
  /// while building and have no loading state to render.
  MaintenanceLog get log;

  Future<MaintenanceLog> fetchLog();

  Future<MaintenanceLog> updateOdometer(int km);

  Future<MaintenanceLog> addRecord(ServiceRecord record);

  Future<MaintenanceLog> setKmInterval(MaintenanceType type, int km);

  Future<MaintenanceLog> setMonthInterval(MaintenanceType type, int months);

  /// Upcoming items computed from [log]. Never reports a percentage for an
  /// item with no record — that is the whole point of the redesign that
  /// replaced the old fabricated "health score".
  List<DueItem> dueItems(MaintenanceLog log, {DateTime? now});
}

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl(this._service);

  final MaintenanceService _service;

  final _log = WarmCache<MaintenanceLog>(fallback: MaintenanceLog.empty);

  /// Threshold at which an item stops being "good" and starts being "near".
  static const _nearThreshold = 0.6;

  /// Average days per month, used to age month-based intervals.
  static const _daysPerMonth = 30.4;

  @override
  Future<void> warmUp() => _log.load(_service.fetchLog);

  @override
  MaintenanceLog get log => _log.value;

  @override
  Future<MaintenanceLog> fetchLog() => _log.load(_service.fetchLog);

  @override
  Future<MaintenanceLog> updateOdometer(int km) =>
      _store(_service.updateOdometer(km));

  @override
  Future<MaintenanceLog> addRecord(ServiceRecord record) =>
      _store(_service.addRecord(record));

  @override
  Future<MaintenanceLog> setKmInterval(MaintenanceType type, int km) =>
      _store(_service.setKmInterval(type, km));

  @override
  Future<MaintenanceLog> setMonthInterval(MaintenanceType type, int months) =>
      _store(_service.setMonthInterval(type, months));

  /// Keeps the warm cache in step with every write.
  Future<MaintenanceLog> _store(Future<MaintenanceLog> write) async {
    final updated = await write;
    _log.put(updated);
    return updated;
  }

  @override
  List<DueItem> dueItems(MaintenanceLog log, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return [
      for (final type in MaintenanceType.values) _computeDue(log, type, today),
    ];
  }

  DueItem _computeDue(MaintenanceLog log, MaintenanceType type, DateTime now) {
    final last = log.lastRecordOf(type);
    if (last == null) {
      return DueItem(type: type, status: DueStatus.noRecord);
    }

    if (type.kmBased) {
      final interval =
          log.kmIntervals[type] ?? MaintenanceLog.defaultKmInterval;
      final current = log.currentOdometerKm;
      if (current == null) {
        return DueItem(
          type: type,
          status: DueStatus.noRecord,
          lastRecord: last,
        );
      }
      final used = (current - last.odometerKm).clamp(0, interval);
      final remaining = interval - (current - last.odometerKm);
      final progress = used / interval;
      return DueItem(
        type: type,
        status: _statusFor(exhausted: remaining <= 0, progress: progress),
        progress: progress.clamp(0, 1).toDouble(),
        remainingKm: remaining,
        lastRecord: last,
      );
    }

    final interval =
        log.monthIntervals[type] ?? MaintenanceLog.defaultMonthInterval;
    final elapsedMonths = (now.difference(last.date).inDays / _daysPerMonth)
        .floor();
    final remainingMonths = interval - elapsedMonths;
    final progress = (elapsedMonths / interval).clamp(0.0, 1.0);
    return DueItem(
      type: type,
      status: _statusFor(exhausted: remainingMonths <= 0, progress: progress),
      progress: progress,
      remainingMonths: remainingMonths,
      lastRecord: last,
    );
  }

  DueStatus _statusFor({required bool exhausted, required double progress}) {
    if (exhausted) return DueStatus.due;
    return progress >= _nearThreshold ? DueStatus.near : DueStatus.good;
  }
}
