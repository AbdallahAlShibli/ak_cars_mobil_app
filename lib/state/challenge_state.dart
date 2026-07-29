import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../data/models/challenge.dart';
import '../data/models/maintenance.dart';
import '../di/providers.dart';
import 'garage_state.dart';
import 'maintenance_state.dart';

/// The weekly challenge: one challenge per week with checkable steps.
///
/// Completing every step grants loyalty points plus a badge and extends the
/// weekly streak. Some challenges also feed the maintenance log — logging a
/// tyre-pressure reading becomes a maintenance record.
///
/// Which challenge is offered follows the default car's powertrain: a car that
/// plugs in gets charging and range tasks instead of engine ones. The points,
/// badges and streak are the same board either way.
class ChallengeNotifier extends Notifier<ChallengeBoard> {
  @override
  ChallengeBoard build() =>
      // Warmed at bootstrap, so the first frame already has the real board.
      ref
          .watch(challengeRepositoryProvider)
          .boardFor(ref.watch(primaryPowertrainProvider));

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
      state = await ref.read(challengeRepositoryProvider).completeChallenge(
            powertrain: ref.read(primaryPowertrainProvider),
          );
    } on BusinessRuleException {
      return false;
    }

    final feeds = current.feedsMaintenance;
    if (feeds != null) await _writeMaintenanceRecord(current, feeds);
    return true;
  }

  /// Files the record against the *default car's* book — the car whose
  /// powertrain chose this challenge in the first place. With an empty garage
  /// there is no car the work could have been done on, so nothing is written.
  Future<void> _writeMaintenanceRecord(
    WeeklyChallenge challenge,
    MaintenanceType type,
  ) async {
    final car = ref.read(primaryCarProvider);
    if (car == null) return;
    final book = ref.read(maintenanceBookProvider(car.id));
    await ref.read(maintenanceProvider.notifier).addRecord(
          car.id,
          ServiceRecord(
            id: 'challenge-${challenge.id}'
                '-${DateTime.now().millisecondsSinceEpoch}',
            // The record says what the challenge actually had the owner do.
            title: challenge.recordTitle ?? challengeRecordTitle,
            workshop: challengeRecordWorkshop,
            odometerKm: book.currentOdometerKm ?? car.odometerKm ?? 0,
            date: DateTime.now(),
            itemKey: type.key,
          ),
        );
  }
}

final challengeProvider =
    NotifierProvider<ChallengeNotifier, ChallengeBoard>(ChallengeNotifier.new);
