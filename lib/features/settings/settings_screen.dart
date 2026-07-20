import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../data/app_state.dart';
import '../../data/mock_data.dart';
import '../../data/settings_state.dart';

/// Settings (handoff #4a): language segmented pill (Arabic | English),
/// theme preview cards (cream default / dark) + follow-system toggle,
/// then notifications / region / about rows.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final region = ref.watch(regionProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            SandHeader(s.settings),
            const SizedBox(height: 15),
            _sectionLabel(ak, s.t('اللغة', 'Language')),
            const SizedBox(height: 10),
            // ------------------------------------------------ language pill
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: ak.surface,
                border: Border.all(color: ak.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  _langSegment(
                    context,
                    label: 'العربية',
                    selected: settings.isArabic,
                    onTap: () => notifier.setLanguage('ar'),
                  ),
                  _langSegment(
                    context,
                    label: 'English',
                    chakra: true,
                    selected: !settings.isArabic,
                    onTap: () => notifier.setLanguage('en'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.t('يتغير اتجاه التطبيق كاملاً (RTL ⇄ LTR) فوراً',
                  'The whole app flips direction (RTL ⇄ LTR) instantly'),
              style: TextStyle(fontSize: 10, color: ak.inkFaint),
            ),
            const SizedBox(height: 15),
            _sectionLabel(ak, s.t('المظهر', 'Appearance')),
            const SizedBox(height: 10),
            // ------------------------------------------------ theme previews
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ThemePreviewCard(
                    dark: false,
                    title: s.t('كريمي — الافتراضي', 'Cream — default'),
                    subtitle: s.t('مريح نهاراً', 'Easy on the eyes by day'),
                    selected: settings.themeMode == ThemeMode.light,
                    onTap: () => notifier.setThemeMode(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: _ThemePreviewCard(
                    dark: true,
                    title: s.t('داكن', 'Dark'),
                    subtitle: s.t('مريح ليلاً', 'Easy on the eyes at night'),
                    selected: settings.themeMode == ThemeMode.dark,
                    onTap: () => notifier.setThemeMode(ThemeMode.dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            // ------------------------------------------------ follow system
            SandCard(
              radius: 16,
              padding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
              child: Row(
                children: [
                  Icon(LucideIcons.sunMedium, size: 15, color: ak.ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.t('تلقائي حسب النظام', 'Follow system'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    value: settings.themeMode == ThemeMode.system,
                    onChanged: (v) => notifier.setThemeMode(
                        v ? ThemeMode.system : ThemeMode.light),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _sectionLabel(ak, s.t('عام', 'General')),
            const SizedBox(height: 10),
            // ------------------------------------------------ general rows
            SandCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _row(
                    context,
                    icon: LucideIcons.bell,
                    label: s.t('الإشعارات', 'Notifications'),
                    divider: true,
                    trailing: Switch(
                      value: settings.notifications,
                      onChanged: notifier.setNotifications,
                    ),
                  ),
                  _row(
                    context,
                    icon: LucideIcons.mapPin,
                    label: s.t('المنطقة', 'Region'),
                    divider: true,
                    trailing: Text(
                      '$region ›',
                      style: TextStyle(fontSize: 11, color: ak.inkSub),
                    ),
                    onTap: () => _showRegionSheet(context, ref, s),
                  ),
                  _row(
                    context,
                    icon: LucideIcons.info,
                    label: s.t('عن التطبيق', 'About the app'),
                    trailing: Text(
                      'v2.0',
                      style: GoogleFonts.chakraPetch(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: ak.inkSub),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(AkColors ak, String text) => Text(
        text,
        style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w700, color: ak.inkSub),
      );

  Widget _langSegment(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool chakra = false,
  }) {
    final ak = AkColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? ak.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: chakra
                  ? GoogleFonts.chakraPetch(
                      fontSize: 12.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? ak.onPrimary : ak.inkSub,
                    )
                  : TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? ak.onPrimary : ak.inkSub,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget trailing,
    bool divider = false,
    VoidCallback? onTap,
  }) {
    final ak = AkColors.of(context);
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: ak.divider))
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ak.ink),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }

  void _showRegionSheet(BuildContext context, WidgetRef ref, S s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final ak = AkColors.of(sheetContext);
        final current = ref.read(regionProvider);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              Text(
                s.t('اختر منطقتك', 'Choose your region'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final r in MockData.regions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r, style: const TextStyle(fontSize: 13.5)),
                  trailing: r == current
                      ? Icon(LucideIcons.check, size: 17, color: ak.ink)
                      : null,
                  onTap: () {
                    ref.read(regionProvider.notifier).state = r;
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Miniature app preview inside the theme picker cards.
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.dark,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final bool dark;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final previewBg = dark ? const Color(0xFF171613) : const Color(0xFFF6F3EE);
    final previewInk = dark ? const Color(0xFFF2EFE8) : const Color(0xFF1D1B17);
    final previewCard = dark ? const Color(0xFF211F1B) : Colors.white;
    final previewAmber = dark
        ? const Color(0xFFE9A23B).withValues(alpha: 0.35)
        : const Color(0xFFF3D9A4);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ak.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? ak.ink : ak.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 74,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: previewBg,
                    borderRadius: BorderRadius.circular(12),
                    border: dark
                        ? null
                        : Border.all(color: const Color(0xFFECE7DE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        height: 8,
                        decoration: BoxDecoration(
                          color: previewInk,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: previewCard,
                          borderRadius: BorderRadius.circular(8),
                          border: dark
                              ? null
                              : Border.all(color: const Color(0xFFECE7DE)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: previewAmber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 9.5, color: ak.inkSub)),
              ],
            ),
          ),
          if (selected)
            PositionedDirectional(
              top: 9,
              end: 9,
              child: Container(
                width: 20,
                height: 20,
                decoration:
                    BoxDecoration(color: ak.primary, shape: BoxShape.circle),
                child: Icon(Icons.check, size: 12, color: ak.onPrimary),
              ),
            ),
        ],
      ),
    );
  }
}
