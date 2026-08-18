import '../../core/error/app_exception.dart';
import '../models/challenge.dart';
import '../models/powertrain.dart';

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
