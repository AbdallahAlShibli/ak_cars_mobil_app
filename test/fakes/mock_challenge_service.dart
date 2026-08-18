import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/data/models/challenge.dart';
import 'package:ak_cars_mobil_app/data/models/powertrain.dart';
import 'package:ak_cars_mobil_app/data/services/challenge_service.dart';

import 'data/mock_garage_data.dart';
import 'fake_service_base.dart';

class MockChallengeService with MockServiceBase implements ChallengeService {
  final Map<ChallengeTrack, ChallengeBoard> _boards = {
    ChallengeTrack.combustion: MockGarageData.challengeBoard,
    ChallengeTrack.electric: MockGarageData.evChallengeBoard,
  };

  @override
  Future<ChallengeBoard> fetchBoard({Powertrain? powertrain}) =>
      respond(_boards[ChallengeTrackX.of(powertrain)]!);

  @override
  Future<ChallengeBoard> toggleStep(String stepId) {
    final track = _trackOfStep(stepId);
    if (track == null) return respond(_boards[ChallengeTrack.combustion]!);

    final board = _boards[track]!;
    final current = board.current!;
    _boards[track] = board.copyWith(
      current: () => current.copyWith(steps: [
        for (final step in current.steps)
          if (step.id == stepId) step.copyWith(done: !step.done) else step,
      ]),
    );
    return respond(_boards[track]!);
  }

  @override
  Future<ChallengeBoard> completeChallenge({Powertrain? powertrain}) {
    final track = ChallengeTrackX.of(powertrain);
    final board = _boards[track]!;
    final current = board.current;
    if (current == null || !current.allDone) {
      throw const BusinessRuleException(
        'Every step must be done before the challenge can be completed',
        code: 'challenge_incomplete',
      );
    }

    _boards[track] = board.copyWith(
      current: () => null,
      history: [
        PastChallenge(title: current.title, points: current.rewardPoints),
        ...board.history,
      ],
      streakWeeks: board.streakWeeks + 1,
      completedCount: board.completedCount + 1,
      points: board.points + current.rewardPoints,
      badgeCount: board.badgeCount + 1,
    );
    return respond(_boards[track]!);
  }

  ChallengeTrack? _trackOfStep(String stepId) {
    for (final entry in _boards.entries) {
      final steps = entry.value.current?.steps ?? const [];
      if (steps.any((step) => step.id == stepId)) return entry.key;
    }
    return null;
  }
}
