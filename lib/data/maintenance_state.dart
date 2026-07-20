import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/strings.dart';

/// ---------------------------------------------------------------------------
/// Maintenance follow-up — replaces the old fake "health score".
///
/// Everything here is computed from data the USER enters (odometer readings,
/// manual records) plus service records created inside the app. The app never
/// reads anything from the car itself, and items with no record never show a
/// percentage.
///
/// Formula (per handoff): remaining = interval − (currentOdometer −
/// lastServiceOdometer). Month-based items use the record date instead.
/// ---------------------------------------------------------------------------

enum MaintenanceType { oil, tyres, coolant }

extension MaintenanceTypeX on MaintenanceType {
  L get title => switch (this) {
        MaintenanceType.oil => const L('زيت المحرك + الفلتر', 'Engine oil + filter'),
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
}

class MaintenanceState {
  const MaintenanceState({
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

  MaintenanceState copyWith({
    int? currentOdometerKm,
    DateTime? odometerUpdatedAt,
    List<ServiceRecord>? records,
    Map<MaintenanceType, int>? kmIntervals,
    Map<MaintenanceType, int>? monthIntervals,
  }) =>
      MaintenanceState(
        currentOdometerKm: currentOdometerKm ?? this.currentOdometerKm,
        odometerUpdatedAt: odometerUpdatedAt ?? this.odometerUpdatedAt,
        records: records ?? this.records,
        kmIntervals: kmIntervals ?? this.kmIntervals,
        monthIntervals: monthIntervals ?? this.monthIntervals,
      );

  ServiceRecord? lastRecordOf(MaintenanceType type) {
    ServiceRecord? last;
    for (final r in records) {
      if (r.type != type) continue;
      if (last == null || r.date.isAfter(last.date)) last = r;
    }
    return last;
  }
}

class MaintenanceNotifier extends Notifier<MaintenanceState> {
  @override
  MaintenanceState build() {
    // Staging seed — mirrors the design handoff demo data. Replace with the
    // user's persisted entries when the backend lands.
    final now = DateTime.now();
    return MaintenanceState(
      currentOdometerKm: 128450,
      odometerUpdatedAt: now.subtract(const Duration(days: 1)),
      records: [
        ServiceRecord(
          id: 'r-oil-1',
          title: const L('تغيير زيت + فلتر', 'Oil + filter change'),
          workshop: 'Gulf Auto Care',
          odometerKm: 123000,
          date: DateTime(2026, 3, 14),
          type: MaintenanceType.oil,
        ),
        ServiceRecord(
          id: 'r-tyre-1',
          title: const L('ترصيص وموازنة', 'Alignment & balancing'),
          workshop: 'Al Noor Workshop',
          odometerKm: 119400,
          date: DateTime(2026, 5, 20),
          type: MaintenanceType.tyres,
        ),
      ],
      kmIntervals: const {MaintenanceType.oil: 7000},
      monthIntervals: const {
        MaintenanceType.tyres: 6,
        MaintenanceType.coolant: 24,
      },
    );
  }

  void updateOdometer(int km) {
    if (km <= 0) return;
    state = state.copyWith(
      currentOdometerKm: km,
      odometerUpdatedAt: DateTime.now(),
    );
  }

  void addRecord(ServiceRecord record) =>
      state = state.copyWith(records: [record, ...state.records]);

  void setKmInterval(MaintenanceType type, int km) => state = state.copyWith(
        kmIntervals: {...state.kmIntervals, type: km},
      );

  void setMonthInterval(MaintenanceType type, int months) =>
      state = state.copyWith(
        monthIntervals: {...state.monthIntervals, type: months},
      );
}

final maintenanceProvider =
    NotifierProvider<MaintenanceNotifier, MaintenanceState>(
        MaintenanceNotifier.new);

/// Computed upcoming items — never shows a percentage without a record.
final maintenanceDueProvider = Provider<List<DueItem>>((ref) {
  final m = ref.watch(maintenanceProvider);
  final now = DateTime.now();

  DueItem compute(MaintenanceType type) {
    final last = m.lastRecordOf(type);
    if (last == null) {
      return DueItem(type: type, status: DueStatus.noRecord);
    }
    if (type.kmBased) {
      final interval = m.kmIntervals[type] ?? 5000;
      final current = m.currentOdometerKm;
      if (current == null) {
        return DueItem(
            type: type, status: DueStatus.noRecord, lastRecord: last);
      }
      final used = (current - last.odometerKm).clamp(0, interval);
      final remaining = interval - (current - last.odometerKm);
      final progress = used / interval;
      return DueItem(
        type: type,
        status: remaining <= 0
            ? DueStatus.due
            : progress >= 0.6
                ? DueStatus.near
                : DueStatus.good,
        progress: progress.clamp(0, 1).toDouble(),
        remainingKm: remaining,
        lastRecord: last,
      );
    }
    final interval = m.monthIntervals[type] ?? 6;
    final elapsedMonths =
        (now.difference(last.date).inDays / 30.4).floor();
    final remainingMonths = interval - elapsedMonths;
    final progress = (elapsedMonths / interval).clamp(0.0, 1.0);
    return DueItem(
      type: type,
      status: remainingMonths <= 0
          ? DueStatus.due
          : progress >= 0.6
              ? DueStatus.near
              : DueStatus.good,
      progress: progress,
      remainingMonths: remainingMonths,
      lastRecord: last,
    );
  }

  return [for (final t in MaintenanceType.values) compute(t)];
});
