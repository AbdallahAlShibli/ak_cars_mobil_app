import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../data/models/challenge.dart';
import '../di/providers.dart';
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

    // The server writes the maintenance record inside the same transaction as
    // the award, so nothing is written here — doing it client-side as well
    // would file a second, duplicate record against the car's book.
    return true;
  }
}

final challengeProvider =
    NotifierProvider<ChallengeNotifier, ChallengeBoard>(ChallengeNotifier.new);
