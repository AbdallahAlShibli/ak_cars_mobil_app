import 'package:ak_cars_mobil_app/app/bootstrap.dart';
import 'package:ak_cars_mobil_app/core/utils/guid.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fakes.dart';

/// Builds a container wired exactly like the app's, including the bootstrap
/// warm-up — but with every service bound to its double from `test/fakes/`.
///
/// The app itself has no offline data source any more: `di/providers.dart`
/// binds `Api*` unconditionally, so without these overrides a widget test
/// would try to reach `https://localhost:7291` and fail. The doubles are
/// injected here, at the one seam the composition root exposes, rather than
/// selected by a flag the shipped app could read.
///
/// Screens read reference data (spec vocabulary, makes, locations, the parts
/// catalogue) synchronously while building, on the assumption that bootstrap
/// has already loaded it. Tests must honour that same contract, so they go
/// through [AppBootstrap.warmUp] rather than constructing a bare
/// `ProviderScope`.
///
/// A caller-supplied override for the same provider in [overrides] still wins
/// (last override in the list applies), which is how a test swaps in an
/// unseeded marketplace or a variant [AppConfig].
Future<ProviderContainer> createTestContainer({
  List<Override> overrides = const [],
}) => _warmedContainer(overrides);

/// Warmed container for pure-Dart tests that never touch a widget tree.
///
/// Identical wiring; the separate name only documents intent at the call
/// site. SharedPreferences is overridden either way because the garage and the
/// maintenance books are genuinely device-local (see `LocalGarageStore`) —
/// each call starts from empty storage, which is what keeps these tests
/// independent of one another.
Future<ProviderContainer> createDataContainer({
  List<Override> overrides = const [],
}) => _warmedContainer(overrides);

Future<ProviderContainer> _warmedContainer(List<Override> overrides) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [...fakeServiceOverrides(prefs), ...overrides],
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
  id: derivedGuid('proof', requestId),
  requestId: requestId,
  notes: notes,
  submittedAt: DateTime.now(),
  media: [testAttachment(derivedGuid('proof-media', requestId))],
  includesPartBoxPhoto: partBox,
);

/// A real, decodable attachment — a 1×1 PNG.
///
/// Real bytes rather than a stub string so anything that renders it goes
/// through the same base64 decode the app does; a placeholder that failed to
/// decode would make a widget test pass against the "cannot preview" tile.
MediaAttachment testAttachment(String id) => MediaAttachment(
      id: id,
      base64Data: testPngBase64,
      mimeType: 'image/png',
      fileName: 'proof.png',
    );

/// 1×1 transparent PNG, base64.
const String testPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
