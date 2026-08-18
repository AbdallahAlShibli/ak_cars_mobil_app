import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../models/challenge.dart';
import '../../models/powertrain.dart';
import '../challenge_service.dart';

/// The weekly challenge and loyalty totals over REST (§12).
///
/// Every call answers with the whole board, never a patch — the same
/// contract [MockChallengeService] already keeps: a client that reconstructs
/// a board from patches can disagree with the server about someone's streak.
class ApiChallengeService implements ChallengeService {
  const ApiChallengeService(this._client);

  final ApiClient _client;

  @override
  Future<ChallengeBoard> fetchBoard({Powertrain? powertrain}) async =>
      ChallengeBoard.fromJson(
        await _client.get(
          ApiEndpoints.challengeBoard,
          queryParameters: {'powertrain': ?powertrain?.key},
        ),
      );

  @override
  Future<ChallengeBoard> toggleStep(String stepId) async =>
      ChallengeBoard.fromJson(
        await _client.post(ApiEndpoints.toggleChallengeStep(stepId)),
      );

  @override
  Future<ChallengeBoard> completeChallenge({Powertrain? powertrain}) async =>
      ChallengeBoard.fromJson(
        await _client.post(
          ApiEndpoints.completeCurrentChallenge,
          body: {'powertrain': ?powertrain?.key},
        ),
      );
}
