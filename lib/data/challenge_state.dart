import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/strings.dart';
import 'maintenance_state.dart';

/// ---------------------------------------------------------------------------
/// Weekly challenge — one challenge per week with checkable steps.
/// Completing every step grants loyalty points + a badge and extends the
/// weekly streak. Some challenges feed the maintenance log (e.g. logging a
/// tyre-pressure reading becomes a maintenance record).
/// ---------------------------------------------------------------------------

class ChallengeStep {
  const ChallengeStep({required this.id, required this.title, this.done = false});

  final String id;
  final L title;
  final bool done;

  ChallengeStep copyWith({bool? done}) =>
      ChallengeStep(id: id, title: title, done: done ?? this.done);
}

class WeeklyChallenge {
  const WeeklyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
    required this.rewardPoints,
    required this.badgeName,
    required this.endsInDays,
    this.feedsMaintenance,
  });

  final String id;
  final L title;
  final L description;
  final List<ChallengeStep> steps;
  final int rewardPoints;
  final L badgeName;
  final int endsInDays;

  /// When set, completing the challenge writes a maintenance record of
  /// this type (the handoff's "challenge feeds the maintenance log").
  final MaintenanceType? feedsMaintenance;

  int get doneCount => steps.where((s) => s.done).length;
  bool get allDone => doneCount == steps.length;

  WeeklyChallenge copyWith({List<ChallengeStep>? steps}) => WeeklyChallenge(
        id: id,
        title: title,
        description: description,
        steps: steps ?? this.steps,
        rewardPoints: rewardPoints,
        badgeName: badgeName,
        endsInDays: endsInDays,
        feedsMaintenance: feedsMaintenance,
      );
}

class PastChallenge {
  const PastChallenge({required this.title, required this.points});

  final L title;
  final int points;
}

class LockedChallenge {
  const LockedChallenge({required this.title, required this.points});

  final L title;
  final int points;
}

class ChallengeState {
  const ChallengeState({
    required this.current,
    required this.next,
    required this.history,
    required this.streakWeeks,
    required this.completedCount,
    required this.points,
    required this.badgeCount,
  });

  final WeeklyChallenge? current;
  final LockedChallenge? next;
  final List<PastChallenge> history;
  final int streakWeeks;
  final int completedCount;

  /// Loyalty points balance.
  final int points;
  final int badgeCount;

  ChallengeState copyWith({
    WeeklyChallenge? Function()? current,
    LockedChallenge? Function()? next,
    List<PastChallenge>? history,
    int? streakWeeks,
    int? completedCount,
    int? points,
    int? badgeCount,
  }) =>
      ChallengeState(
        current: current != null ? current() : this.current,
        next: next != null ? next() : this.next,
        history: history ?? this.history,
        streakWeeks: streakWeeks ?? this.streakWeeks,
        completedCount: completedCount ?? this.completedCount,
        points: points ?? this.points,
        badgeCount: badgeCount ?? this.badgeCount,
      );
}

class ChallengeNotifier extends Notifier<ChallengeState> {
  @override
  ChallengeState build() {
    // Staging seed matching the design handoff (#4d).
    return const ChallengeState(
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

  void toggleStep(String stepId) {
    final c = state.current;
    if (c == null) return;
    state = state.copyWith(
      current: () => c.copyWith(steps: [
        for (final s in c.steps)
          if (s.id == stepId) s.copyWith(done: !s.done) else s,
      ]),
    );
  }

  /// All steps done ⇒ award points + badge, extend the streak, archive the
  /// challenge, and optionally write a maintenance record.
  bool completeChallenge() {
    final c = state.current;
    if (c == null || !c.allDone) return false;

    if (c.feedsMaintenance != null) {
      final m = ref.read(maintenanceProvider);
      ref.read(maintenanceProvider.notifier).addRecord(
            ServiceRecord(
              id: 'challenge-${c.id}-${DateTime.now().millisecondsSinceEpoch}',
              title: const L('فحص ضغط الإطارات (تحدي)',
                  'Tyre pressure check (challenge)'),
              workshop: 'AK Challenge',
              odometerKm: m.currentOdometerKm ?? 0,
              date: DateTime.now(),
              type: c.feedsMaintenance,
            ),
          );
    }

    state = state.copyWith(
      current: () => null,
      history: [
        PastChallenge(title: c.title, points: c.rewardPoints),
        ...state.history,
      ],
      streakWeeks: state.streakWeeks + 1,
      completedCount: state.completedCount + 1,
      points: state.points + c.rewardPoints,
      badgeCount: state.badgeCount + 1,
    );
    return true;
  }
}

final challengeProvider =
    NotifierProvider<ChallengeNotifier, ChallengeState>(ChallengeNotifier.new);
