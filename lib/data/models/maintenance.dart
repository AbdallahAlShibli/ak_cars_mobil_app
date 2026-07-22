import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';

/// Maintenance items the app tracks a countdown for.
///
/// Everything here is computed from data the *user* enters (odometer
/// readings, manual records) plus service records created inside the app. The
/// app never reads anything from the car itself, and items with no record
/// never show a percentage.
enum MaintenanceType {
  oil,
  tyres,
  coolant;

  String get key => name;
}

extension MaintenanceTypeX on MaintenanceType {
  L get title => switch (this) {
        MaintenanceType.oil =>
          const L('زيت المحرك + الفلتر', 'Engine oil + filter'),
        MaintenanceType.tyres =>
          const L('فحص وترصيص الإطارات', 'Tyre check & alignment'),
        MaintenanceType.coolant => const L('سائل التبريد', 'Coolant'),
      };

  L get shortTitle => switch (this) {
        MaintenanceType.oil => const L('زيت المحرك', 'Engine oil'),
        MaintenanceType.tyres => const L('فحص الإطارات', 'Tyre check'),
        MaintenanceType.coolant => const L('سائل التبريد', 'Coolant'),
      };

  /// km-based items count kilometres; the rest count months.
  bool get kmBased => this == MaintenanceType.oil;
}

/// A completed service, either logged by the user or created by a booking.
class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.title,
    required this.workshop,
    required this.odometerKm,
    required this.date,
    this.type,
  });

  final String id;
  final L title;
  final String workshop;
  final int odometerKm;
  final DateTime date;

  /// When set, this record resets the countdown of that maintenance item.
  final MaintenanceType? type;

  factory ServiceRecord.fromJson(JsonMap json) => ServiceRecord(
        id: json.requireString('id'),
        title: L.fromJson(json['title']),
        workshop: json.stringOr('workshop', ''),
        odometerKm: json.intOr('odometerKm', 0),
        date: json.dateTimeOr('date', DateTime.now()),
        type: json['type'] == null
            ? null
            : json.enumOr('type', MaintenanceType.values, MaintenanceType.oil),
      );

  JsonMap toJson() => {
        'id': id,
        'title': title.toJson(),
        'workshop': workshop,
        'odometerKm': odometerKm,
        'date': date.toIso8601String(),
        'type': type?.key,
      };

  ServiceRecord copyWith({
    String? id,
    L? title,
    String? workshop,
    int? odometerKm,
    DateTime? date,
    MaintenanceType? type,
  }) =>
      ServiceRecord(
        id: id ?? this.id,
        title: title ?? this.title,
        workshop: workshop ?? this.workshop,
        odometerKm: odometerKm ?? this.odometerKm,
        date: date ?? this.date,
        type: type ?? this.type,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceRecord &&
      other.id == id &&
      other.title == title &&
      other.workshop == workshop &&
      other.odometerKm == odometerKm &&
      other.date == date &&
      other.type == type;

  @override
  int get hashCode => Object.hash(id, title, workshop, odometerKm, date, type);
}

enum DueStatus { due, near, good, noRecord }

/// A computed upcoming-maintenance line. [progress] is how much of the
/// interval is consumed (0..1) — null when there is no record.
class DueItem {
  const DueItem({
    required this.type,
    required this.status,
    this.progress,
    this.remainingKm,
    this.remainingMonths,
    this.lastRecord,
  });

  final MaintenanceType type;
  final DueStatus status;
  final double? progress;
  final int? remainingKm;
  final int? remainingMonths;
  final ServiceRecord? lastRecord;

  DueItem copyWith({
    MaintenanceType? type,
    DueStatus? status,
    double? progress,
    int? remainingKm,
    int? remainingMonths,
    ServiceRecord? lastRecord,
  }) =>
      DueItem(
        type: type ?? this.type,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        remainingKm: remainingKm ?? this.remainingKm,
        remainingMonths: remainingMonths ?? this.remainingMonths,
        lastRecord: lastRecord ?? this.lastRecord,
      );

  @override
  bool operator ==(Object other) =>
      other is DueItem &&
      other.type == type &&
      other.status == status &&
      other.progress == progress &&
      other.remainingKm == remainingKm &&
      other.remainingMonths == remainingMonths &&
      other.lastRecord == lastRecord;

  @override
  int get hashCode => Object.hash(
        type,
        status,
        progress,
        remainingKm,
        remainingMonths,
        lastRecord,
      );
}

/// The user's maintenance book: odometer, logged records, and the intervals
/// each item is measured against.
class MaintenanceLog {
  const MaintenanceLog({
    required this.currentOdometerKm,
    required this.odometerUpdatedAt,
    required this.records,
    required this.kmIntervals,
    required this.monthIntervals,
  });

  /// User-entered odometer. Null until the user enters it the first time.
  final int? currentOdometerKm;
  final DateTime? odometerUpdatedAt;
  final List<ServiceRecord> records;

  /// Editable intervals (defaults: oil 5,000 km / tyres 6 months …).
  final Map<MaintenanceType, int> kmIntervals;
  final Map<MaintenanceType, int> monthIntervals;

  /// Fallbacks used when an item has no explicit interval configured.
  static const defaultKmInterval = 5000;
  static const defaultMonthInterval = 6;

  static const empty = MaintenanceLog(
    currentOdometerKm: null,
    odometerUpdatedAt: null,
    records: [],
    kmIntervals: {},
    monthIntervals: {},
  );

  ServiceRecord? lastRecordOf(MaintenanceType type) {
    ServiceRecord? last;
    for (final r in records) {
      if (r.type != type) continue;
      if (last == null || r.date.isAfter(last.date)) last = r;
    }
    return last;
  }

  factory MaintenanceLog.fromJson(JsonMap json) => MaintenanceLog(
        currentOdometerKm: json.intOrNull('currentOdometerKm'),
        odometerUpdatedAt: json.dateTimeOrNull('odometerUpdatedAt'),
        records: json.objectList('records').map(ServiceRecord.fromJson).toList(),
        kmIntervals: _intervals(json.objectOrNull('kmIntervals')),
        monthIntervals: _intervals(json.objectOrNull('monthIntervals')),
      );

  static Map<MaintenanceType, int> _intervals(JsonMap? json) {
    if (json == null) return const {};
    final result = <MaintenanceType, int>{};
    for (final entry in json.entries) {
      for (final type in MaintenanceType.values) {
        if (type.key == entry.key) {
          final value = entry.value;
          result[type] = value is int
              ? value
              : int.tryParse(value.toString()) ?? 0;
        }
      }
    }
    return result;
  }

  JsonMap toJson() => {
        'currentOdometerKm': currentOdometerKm,
        'odometerUpdatedAt': odometerUpdatedAt?.toIso8601String(),
        'records': [for (final r in records) r.toJson()],
        'kmIntervals': {
          for (final e in kmIntervals.entries) e.key.key: e.value,
        },
        'monthIntervals': {
          for (final e in monthIntervals.entries) e.key.key: e.value,
        },
      };

  MaintenanceLog copyWith({
    int? currentOdometerKm,
    DateTime? odometerUpdatedAt,
    List<ServiceRecord>? records,
    Map<MaintenanceType, int>? kmIntervals,
    Map<MaintenanceType, int>? monthIntervals,
  }) =>
      MaintenanceLog(
        currentOdometerKm: currentOdometerKm ?? this.currentOdometerKm,
        odometerUpdatedAt: odometerUpdatedAt ?? this.odometerUpdatedAt,
        records: records ?? this.records,
        kmIntervals: kmIntervals ?? this.kmIntervals,
        monthIntervals: monthIntervals ?? this.monthIntervals,
      );
}
