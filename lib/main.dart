import 'app/app_launcher.dart';

/// Loads preferences and warms the reference data every screen reads
/// synchronously, so the first frame is already complete — and paints a
/// failure screen rather than hanging on the OS splash if any of that throws.
/// See `AppLauncher`.
void main() => AppLauncher.launch();
