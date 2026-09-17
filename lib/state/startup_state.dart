import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app's first load is still under way.
///
/// Since 2026-09-15 start-up no longer holds the launch screen until every
/// repository is warm: `AppBootstrap` gives the load a short budget, paints
/// the first frame, and lets the rest finish in the background. Until it has,
/// a list that is empty may simply not have arrived — so screens that would
/// otherwise say "nothing here" show their loading placeholders while this is
/// true, and the app-wide loading bar stays up.
///
/// False everywhere start-up did not set it, which is what widget tests that
/// build a container by hand want: their data is already there.
final startupLoadingProvider = NotifierProvider<StartupLoadingNotifier, bool>(
  StartupLoadingNotifier.new,
);

class StartupLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Called by `AppBootstrap` as the first load begins.
  void start() => state = true;

  /// Called by `AppBootstrap` once it has settled, successfully or not.
  void finish() => state = false;
}
