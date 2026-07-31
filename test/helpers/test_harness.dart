import 'package:ak_cars_mobil_app/app/bootstrap.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a container wired exactly like the app's, including the bootstrap
/// warm-up.
///
/// Screens read reference data (spec vocabulary, makes, locations, the parts
/// catalogue) synchronously while building, on the assumption that bootstrap
/// has already loaded it. Tests must honour that same contract, so they go
/// through [AppBootstrap.warmUp] rather than constructing a bare
/// `ProviderScope`.
Future<ProviderContainer> createTestContainer({
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs), ...overrides],
  );
  addTearDown(container.dispose);

  await AppBootstrap.warmUp(container);
  return container;
}

/// Warmed container for pure-Dart tests that never touch a widget tree.
///
/// Still overrides SharedPreferences: the mock services stand in for the
/// server's storage as well as its API, so the garage and the maintenance
/// books read and write it. Each call starts from empty storage, which is what
/// keeps these tests independent of one another.
Future<ProviderContainer> createDataContainer({
  List<Override> overrides = const [],
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs), ...overrides],
  );
  addTearDown(container.dispose);

  await AppBootstrap.warmUp(container);
  return container;
}

/// A completion proof that satisfies `ServiceRequest.proofSatisfiesRules`
/// (spec §3): at least one photo, and — for a part-and-fitting job — the
/// workshop's declaration that one of them shows the part's own box.
///
/// Shared because the rule is shared: a test that drives a booking to
/// `awaitingApproval` has to submit real evidence for the same reason a
/// workshop does, and hard-coding a bare `ProofOfWork` at each call site is
/// how a fixture drifts out of step with the rule it is meant to satisfy.
///
/// [partBox] is deliberately explicit rather than defaulted per booking type:
/// a test that checks the part rule *rejects* an undeclared proof passes
/// `false` and needs that to mean what it says.
ProofOfWork testProof(
  String requestId, {
  bool partBox = true,
  String notes = '',
}) => ProofOfWork(
  id: 'proof-$requestId',
  requestId: requestId,
  notes: notes,
  submittedAt: DateTime.now(),
  media: const [ProofMedia(id: 'm1', uri: 'https://example.test/proof-1.jpg')],
  includesPartBoxPhoto: partBox,
);
