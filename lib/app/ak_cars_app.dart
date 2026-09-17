import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../di/providers.dart';
import '../state/app_state.dart';
import 'app_loading_bar.dart';

/// Root widget: theme, locale and routing — and where a tapped system
/// notification lands, since this is the one widget that outlives every route.
class AkCarsApp extends ConsumerStatefulWidget {
  const AkCarsApp({super.key});

  @override
  ConsumerState<AkCarsApp> createState() => _AkCarsAppState();
}

class _AkCarsAppState extends ConsumerState<AkCarsApp>
    with WidgetsBindingObserver {
  /// Above this width the app is framed like a phone instead of stretching.
  static const _phoneFrameBreakpoint = 550.0;
  static const _phoneFrameMaxWidth = 430.0;

  StreamSubscription<String?>? _openedNotifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final push = ref.read(pushServiceProvider);
    _openedNotifications = push.openedRoutes().listen(_openNotification);
    // A signed-in cold start opens the live notification channel; for a
    // guest `start()` does nothing.
    unawaited(push.start());
  }

  /// Back in the foreground: the OS may have cut the channel while the app
  /// was away, so reconnect — the reconnect itself fetches what was missed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(pushServiceProvider).start());
    }
  }

  /// A notification tapped in the system tray: the inbox catches up (the row
  /// it came from is already on the server) and the app opens what it names.
  void _openNotification(String? route) {
    if (!mounted) return;
    ref.read(notificationsProvider.notifier).adopt(null);
    if (route != null) ref.read(routerProvider).push(route);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openedNotifications?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'AK Cars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) =>
          _phoneFrame(context, _withLoadingBar(child)),
    );
  }

  /// Every route sits under the app-wide loading bar — see [AppLoadingBar].
  Widget _withLoadingBar(Widget? child) => Stack(
    fit: StackFit.expand,
    children: [child ?? const SizedBox.shrink(), const AppLoadingBar()],
  );

  /// On wide screens (web/desktop) present the app in a centered,
  /// phone-sized frame instead of stretching full width.
  Widget _phoneFrame(BuildContext context, Widget? child) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _phoneFrameBreakpoint || child == null) {
      return child ?? const SizedBox();
    }
    return ColoredBox(
      color: const Color(0xFF1D1B17),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: _phoneFrameMaxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
