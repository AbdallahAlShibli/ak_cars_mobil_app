import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../state/settings_state.dart';

/// Root widget: theme, locale and routing.
class AkCarsApp extends ConsumerWidget {
  const AkCarsApp({super.key});

  /// Above this width the app is framed like a phone instead of stretching.
  static const _phoneFrameBreakpoint = 550.0;
  static const _phoneFrameMaxWidth = 430.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      builder: (context, child) => _phoneFrame(context, child),
    );
  }

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
