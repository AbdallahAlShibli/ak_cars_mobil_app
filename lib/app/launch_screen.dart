import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_mark.dart';

/// The first thing `AppLauncher` paints — before the bootstrap has read a
/// single preference.
///
/// Android keeps its own launch screen (the app icon on the system
/// background) up until Flutter draws a frame, and it offers nothing while it
/// waits: no progress, no error, no way out. Anything start-up waited on before
/// the real app's first frame happened behind it, so a slow or stuck start-up
/// looked exactly like a frozen app. Painting this at once hands the screen to
/// the app, where the wait is visible and bounded: the launcher replaces it
/// with the real app or with the failure screen.
///
/// Drawn like that launch screen — the mark alone on the system background —
/// so the swap is invisible when start-up is quick. A spinner appears only if
/// it is not.
///
/// Its own `MaterialApp` with no `ProviderScope`, for the same reason as
/// `BootFailureApp`: there is no container yet.
class LaunchScreenApp extends StatelessWidget {
  const LaunchScreenApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AK Cars',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: const _LaunchScreen(),
  );
}

class _LaunchScreen extends StatefulWidget {
  const _LaunchScreen();

  @override
  State<_LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<_LaunchScreen> {
  /// How long start-up may take before the screen shows it is working. A
  /// normal start replaces this screen well inside it.
  static const _spinnerDelay = Duration(milliseconds: 1500);

  Timer? _spinnerTimer;
  bool _showSpinner = false;

  @override
  void initState() {
    super.initState();
    _spinnerTimer = Timer(_spinnerDelay, () {
      if (mounted) setState(() => _showSpinner = true);
    });
  }

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      // The system launch screen's background, not the app's sand/ink.
      backgroundColor: dark ? Colors.black : Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          const AppMark(size: 160, tile: false),
          PositionedDirectional(
            bottom: 96,
            child: AnimatedOpacity(
              opacity: _showSpinner ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: dark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
