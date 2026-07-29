import '../../config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../datasources/mock/mock_garage_data.dart';
import '../models/challenge.dart';
import '../models/powertrain.dart';
import 'mock_service_base.dart';

/// Which set of weekly challenges a car is given.
///
/// Two tracks, not two features: the rewards, streak and history are the same
/// board, only the tasks differ. Anything else would mean an EV owner's streak
/// resetting when the app worked out what they drive.
enum ChallengeTrack { combustion, electric }

extension ChallengeTrackX on ChallengeTrack {
  String get key => name;

  /// Cars that plug in get the electric track — a plug-in hybrid owner has a
  /// cable and a charge port to look after just like a full EV.
  static ChallengeTrack of(Powertrain? powertrain) =>
      (powertrain?.plugsIn ?? false)
          ? ChallengeTrack.electric
          : ChallengeTrack.combustion;
}

/// The weekly challenge and the loyalty totals it feeds.
///
/// Phase 2: implement `RestChallengeService` against `/challenges`.
abstract interface class ChallengeService {
  Future<ChallengeBoard> fetchBoard({Powertrain? powertrain});

  /// Toggles a step wherever it lives — the step id identifies its board, so
  /// callers do not have to say which track they are on.
  Future<ChallengeBoard> toggleStep(String stepId);

  /// Awards points and a badge, extends the streak, and archives the
  /// challenge. Throws [BusinessRuleException] when steps remain.
  Future<ChallengeBoard> completeChallenge({Powertrain? powertrain});
}

class MockChallengeService with MockServiceBase implements ChallengeService {
  MockChallengeService({required this.config});

  @override
  final AppConfig config;

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
        code: 'CHALLENGE_INCOMPLETE',
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
