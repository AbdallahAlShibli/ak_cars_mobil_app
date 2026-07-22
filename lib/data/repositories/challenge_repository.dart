import '../models/challenge.dart';
import '../services/challenge_service.dart';
import 'warm_cache.dart';

/// The weekly challenge and the loyalty totals it feeds.
abstract interface class ChallengeRepository {
  /// Loads the board so [board] can be read synchronously on the first frame.
  Future<void> warmUp();

  /// The board as of the last load.
  ChallengeBoard get board;

  Future<ChallengeBoard> fetchBoard();

  Future<ChallengeBoard> toggleStep(String stepId);

  /// Awards points and a badge, extends the streak, archives the challenge.
  Future<ChallengeBoard> completeChallenge();
}

class ChallengeRepositoryImpl implements ChallengeRepository {
  ChallengeRepositoryImpl(this._service);

  final ChallengeService _service;

  final _board = WarmCache<ChallengeBoard>(fallback: ChallengeBoard.empty);

  @override
  Future<void> warmUp() => _board.load(_service.fetchBoard);

  @override
  ChallengeBoard get board => _board.value;

  @override
  Future<ChallengeBoard> fetchBoard() => _board.load(_service.fetchBoard);

  @override
  Future<ChallengeBoard> toggleStep(String stepId) =>
      _store(_service.toggleStep(stepId));

  @override
  Future<ChallengeBoard> completeChallenge() =>
      _store(_service.completeChallenge());

  /// Keeps the warm cache in step with every write.
  Future<ChallengeBoard> _store(Future<ChallengeBoard> write) async {
    final updated = await write;
    _board.put(updated);
    return updated;
  }
}
