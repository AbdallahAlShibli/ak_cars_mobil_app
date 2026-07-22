import '../../../core/i18n/strings.dart';
import '../../models/challenge.dart';
import '../../models/maintenance.dart';

/// Demo seeds for the garage features — the maintenance book and the weekly
/// challenge. Read only by `MockMaintenanceService` / `MockChallengeService`.
abstract final class MockGarageData {
  /// Mirrors the design-handoff demo data. The dated records are relative to
  /// [now] so the computed "due in N months" lines stay sensible as time
  /// passes instead of drifting into the past.
  static MaintenanceLog maintenanceLog({DateTime? now}) {
    final today = now ?? DateTime.now();
    return MaintenanceLog(
      currentOdometerKm: 128450,
      odometerUpdatedAt: today.subtract(const Duration(days: 1)),
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

  static const challengeBoard = ChallengeBoard(
    current: WeeklyChallenge(
      id: 'tyre-pressure',
      title: L('افحص ضغط الإطارات الأربعة', 'Check all four tyre pressures'),
      description: L(
        'حرارة الصيف ترفع الضغط — فحص أسبوعي يطيل عمر الإطار ويقلل الاستهلاك.',
        'Summer heat raises pressure — a weekly check extends tyre life and cuts fuel use.',
      ),
      steps: [
        ChallengeStep(
          id: 's1',
          title: L('حدّث ممشى السيارة', 'Update your odometer'),
          done: true,
        ),
        ChallengeStep(
          id: 's2',
          title: L('سجّل قراءة الضغط (صورة أو رقم)',
              'Log the pressure reading (photo or number)'),
        ),
        ChallengeStep(
          id: 's3',
          title: L('قارنها بالموصى به لسيارتك (33 PSI)',
              'Compare with your car\'s recommended (33 PSI)'),
        ),
      ],
      rewardPoints: 150,
      badgeName: L('عين على الإطارات', 'Tyre watcher'),
      endsInDays: 3,
      feedsMaintenance: MaintenanceType.tyres,
    ),
    next: LockedChallenge(
      title: L('نظّف فلتر المكيف بنفسك', 'Clean your AC filter yourself'),
      points: 100,
    ),
    history: [
      PastChallenge(
        title: L('افحص سائل التبريد', 'Check your coolant'),
        points: 150,
      ),
      PastChallenge(
        title: L('حدّث الممشى 4 أسابيع متتالية',
            'Update mileage 4 weeks in a row'),
        points: 200,
      ),
    ],
    streakWeeks: 3,
    completedCount: 12,
    points: 2450,
    badgeCount: 8,
  );
}
