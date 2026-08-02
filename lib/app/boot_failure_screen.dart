import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n/strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';

/// What the app shows when it could not start (see `AppLauncher`).
///
/// Deliberately its own `MaterialApp` with no `ProviderScope`: the whole point
/// is that it renders when the dependency container could not be built, so it
/// may not read a single provider. Language comes from the platform rather
/// than from the stored preference for the same reason.
class BootFailureApp extends StatelessWidget {
  const BootFailureApp({super.key, required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final isAr = locale.languageCode != 'en';
    return MaterialApp(
      title: 'AK Cars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: Locale(isAr ? 'ar' : 'en'),
      home: Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: _BootFailureScreen(s: S(isAr), error: error, onRetry: onRetry),
      ),
    );
  }
}

class _BootFailureScreen extends StatefulWidget {
  const _BootFailureScreen({
    required this.s,
    required this.error,
    required this.onRetry,
  });

  final S s;
  final Object error;
  final Future<void> Function() onRetry;

  @override
  State<_BootFailureScreen> createState() => _BootFailureScreenState();
}

class _BootFailureScreenState extends State<_BootFailureScreen> {
  bool _retrying = false;
  bool _detailsOpen = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    // A successful retry replaces this widget wholesale, so there is nothing
    // to reset afterwards; a failed one rebuilds this screen with the new
    // error and its own fresh state.
    await widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = widget.s;

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(LucideIcons.triangleAlert, size: 40, color: ak.danger),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  s.t('تعذّر تشغيل التطبيق', 'The app could not start'),
                  textAlign: TextAlign.center,
                  style: context.text.screenTitle,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  s.t(
                    'حدث خطأ أثناء تحضير البيانات. جرّب مرة أخرى — وإن تكرر '
                        'الخطأ فتأكد من اتصالك بالإنترنت.',
                    'Something failed while preparing the app’s data. Try '
                        'again — if it keeps failing, check your connection.',
                  ),
                  textAlign: TextAlign.center,
                  style: context.text.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: _retrying
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.rotateCw, size: 18),
                  label: Text(
                    _retrying
                        ? s.t('جارٍ المحاولة…', 'Trying…')
                        : s.t('حاول مرة أخرى', 'Try again'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // The message names what could not be reached (the API base
                // URL, the failing repository), which is the difference
                // between a bug report and "it doesn't work".
                TextButton(
                  onPressed: () =>
                      setState(() => _detailsOpen = !_detailsOpen),
                  child: Text(
                    _detailsOpen
                        ? s.t('إخفاء التفاصيل', 'Hide details')
                        : s.t('تفاصيل الخطأ', 'Error details'),
                  ),
                ),
                if (_detailsOpen)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: ak.surfaceDim,
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      border: Border.all(color: ak.border),
                    ),
                    child: Text(
                      '${widget.error}',
                      textDirection: TextDirection.ltr,
                      style: context.text.bodySecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
