import '../models/challenge.dart';
import '../models/powertrain.dart';
import '../services/challenge_service.dart';
import 'warm_cache.dart';

/// The weekly challenge and the loyalty totals it feeds.
///
/// There is one board per [ChallengeTrack] — cars that plug in get charging and
/// range tasks, everything else gets the combustion set. Both are warmed at
/// bootstrap so switching the default car does not leave the screen empty for
/// a frame.
abstract interface class ChallengeRepository {
  /// Loads the boards so [board] / [boardFor] can be read synchronously on the
  /// first frame.
  Future<void> warmUp();

  /// The combustion board — the default when nothing is known about the car.
  ChallengeBoard get board;

  /// The board for a car with this powertrain.
  ChallengeBoard boardFor(Powertrain? powertrain);

  Future<ChallengeBoard> fetchBoard({Powertrain? powertrain});

  Future<ChallengeBoard> toggleStep(String stepId);

  /// Awards points and a badge, extends the streak, archives the challenge.
  Future<ChallengeBoard> completeChallenge({Powertrain? powertrain});
}

class ChallengeRepositoryImpl implements ChallengeRepository {
  ChallengeRepositoryImpl(this._service);

  final ChallengeService _service;

  final Map<ChallengeTrack, WarmCache<ChallengeBoard>> _boards = {
    for (final track in ChallengeTrack.values)
      track: WarmCache<ChallengeBoard>(fallback: ChallengeBoard.empty),
  };

  /// A powertrain that reaches each track, used to warm and to write.
  static const _sample = {
    ChallengeTrack.combustion: Powertrain.petrol,
    ChallengeTrack.electric: Powertrain.electric,
  };

  @override
  // `async` so this really is a `Future<void>` — see `CarsRepositoryImpl.warmUp`
  // for why a `=> Future.wait(...)` body is a `catchError` trap. This is the
  // one that surfaced it: `_warmAuthenticatedData` swallows a failed warm-up,
  // and the swallow itself threw.
  Future<void> warmUp() async {
    await Future.wait([
      for (final track in ChallengeTrack.values)
        _boards[track]!
            .load(() => _service.fetchBoard(powertrain: _sample[track])),
    ]);
  }

  @override
  ChallengeBoard get board => boardFor(null);

  @override
  ChallengeBoard boardFor(Powertrain? powertrain) =>
      _boards[ChallengeTrackX.of(powertrain)]!.value;

  @override
  Future<ChallengeBoard> fetchBoard({Powertrain? powertrain}) =>
      _boards[ChallengeTrackX.of(powertrain)]!
          .load(() => _service.fetchBoard(powertrain: powertrain));

  @override
  Future<ChallengeBoard> toggleStep(String stepId) async {
    final updated = await _service.toggleStep(stepId);
    _putWhereTheStepLives(stepId, updated);
    return updated;
  }

  @override
  Future<ChallengeBoard> completeChallenge({Powertrain? powertrain}) async {
    final updated = await _service.completeChallenge(powertrain: powertrain);
    _boards[ChallengeTrackX.of(powertrain)]!.put(updated);
    return updated;
  }

  /// A step id belongs to exactly one board, and [ChallengeService.toggleStep]
  /// does not say which — so the cache is updated where the id was found.
  void _putWhereTheStepLives(String stepId, ChallengeBoard updated) {
    for (final cache in _boards.values) {
      final steps = cache.value.current?.steps ?? const [];
      if (steps.any((step) => step.id == stepId)) {
        cache.put(updated);
        return;
      }
    }
  }
}
