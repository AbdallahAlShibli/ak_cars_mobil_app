import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/settings_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const AkCarsApp(),
    ),
  );
}

class AkCarsApp extends ConsumerWidget {
  const AkCarsApp({super.key});

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
      // On wide screens (web/desktop) present the app in a centered,
      // phone-sized frame instead of stretching full width.
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        if (width <= 550 || child == null) return child ?? const SizedBox();
        return ColoredBox(
          color: const Color(0xFF1D1B17),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
