import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: AkCarsApp()));
}

class AkCarsApp extends ConsumerWidget {
  const AkCarsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'AK Cars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      // On wide screens (web/desktop) present the app in a centered,
      // phone-sized frame instead of stretching full width.
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        if (width <= 550 || child == null) return child ?? const SizedBox();
        return ColoredBox(
          color: const Color(0xFF0B1220),
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
