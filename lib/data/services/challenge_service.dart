import '../../config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../datasources/mock/mock_garage_data.dart';
import '../models/challenge.dart';
import 'mock_service_base.dart';

/// The weekly challenge and the loyalty totals it feeds.
///
/// Phase 2: implement `RestChallengeService` against `/challenges`.
abstract interface class ChallengeService {
  Future<ChallengeBoard> fetchBoard();

  Future<ChallengeBoard> toggleStep(String stepId);

  /// Awards points and a badge, extends the streak, and archives the
  /// challenge. Throws [BusinessRuleException] when steps remain.
  Future<ChallengeBoard> completeChallenge();
}

class MockChallengeService with MockServiceBase implements ChallengeService {
  MockChallengeService({required this.config});

  @override
  final AppConfig config;

  ChallengeBoard _board = MockGarageData.challengeBoard;

  @override
  Future<ChallengeBoard> fetchBoard() => respond(_board);

  @override
  Future<ChallengeBoard> toggleStep(String stepId) {
    final current = _board.current;
    if (current == null) return respond(_board);

    _board = _board.copyWith(
      current: () => current.copyWith(steps: [
        for (final step in current.steps)
          if (step.id == stepId) step.copyWith(done: !step.done) else step,
      ]),
    );
    return respond(_board);
  }

  @override
  Future<ChallengeBoard> completeChallenge() {
    final current = _board.current;
    if (current == null || !current.allDone) {
      throw const BusinessRuleException(
        'Every step must be done before the challenge can be completed',
        code: 'CHALLENGE_INCOMPLETE',
      );
    }

    _board = _board.copyWith(
      current: () => null,
      history: [
        PastChallenge(title: current.title, points: current.rewardPoints),
        ..._board.history,
      ],
      streakWeeks: _board.streakWeeks + 1,
      completedCount: _board.completedCount + 1,
      points: _board.points + current.rewardPoints,
      badgeCount: _board.badgeCount + 1,
    );
    return respond(_board);
  }
}
