import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../data/models/challenge.dart';
import '../data/models/maintenance.dart';
import '../di/providers.dart';
import 'maintenance_state.dart';

/// The weekly challenge: one challenge per week with checkable steps.
///
/// Completing every step grants loyalty points plus a badge and extends the
/// weekly streak. Some challenges also feed the maintenance log — logging a
/// tyre-pressure reading becomes a maintenance record.
class ChallengeNotifier extends Notifier<ChallengeBoard> {
  @override
  ChallengeBoard build() =>
      // Warmed at bootstrap, so the first frame already has the real board.
      ref.watch(challengeRepositoryProvider).board;

  Future<void> toggleStep(String stepId) async {
    state = await ref.read(challengeRepositoryProvider).toggleStep(stepId);
  }

  /// All steps done ⇒ award points + badge, extend the streak, archive the
  /// challenge, and write the maintenance record it feeds.
  ///
  /// Returns false when steps remain.
  Future<bool> completeChallenge() async {
    final current = state.current;
    if (current == null || !current.allDone) return false;

    try {
      state = await ref.read(challengeRepositoryProvider).completeChallenge();
    } on BusinessRuleException {
      return false;
    }

    final feeds = current.feedsMaintenance;
    if (feeds != null) await _writeMaintenanceRecord(current, feeds);
    return true;
  }

  Future<void> _writeMaintenanceRecord(
    WeeklyChallenge challenge,
    MaintenanceType type,
  ) {
    final odometer = ref.read(maintenanceProvider).currentOdometerKm ?? 0;
    return ref.read(maintenanceProvider.notifier).addRecord(
          ServiceRecord(
            id: 'challenge-${challenge.id}'
                '-${DateTime.now().millisecondsSinceEpoch}',
            title: challengeRecordTitle,
            workshop: challengeRecordWorkshop,
            odometerKm: odometer,
            date: DateTime.now(),
            type: type,
          ),
        );
  }
}

final challengeProvider =
    NotifierProvider<ChallengeNotifier, ChallengeBoard>(ChallengeNotifier.new);
