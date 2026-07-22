import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../di/providers.dart';

/// Device-local preferences.
///
/// These stay in SharedPreferences rather than behind a service: they are
/// settings of *this installation*, not of the account, and must apply before
/// the first frame with no network involved.
class SettingsState {
  const SettingsState({
    required this.locale,
    required this.themeMode,
    required this.notifications,
  });

  final Locale locale;

  /// Defaults to [ThemeMode.light] (cream "Sand"); the settings screen
  /// offers dark and "follow system".
  final ThemeMode themeMode;
  final bool notifications;

  bool get isArabic => locale.languageCode == 'ar';

  SettingsState copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? notifications,
  }) =>
      SettingsState(
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        notifications: notifications ?? this.notifications,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  SettingsState build() {
    // First launch defaults per the handoff: Arabic + cream light theme.
    final lang = _prefs.getString(AppConstants.prefsLanguage) ?? 'ar';
    final theme = _prefs.getString(AppConstants.prefsTheme) ?? 'light';
    return SettingsState(
      locale: Locale(lang),
      themeMode: switch (theme) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      notifications: _prefs.getBool(AppConstants.prefsNotifications) ?? true,
    );
  }

  void setLanguage(String code) {
    state = state.copyWith(locale: Locale(code));
    _prefs.setString(AppConstants.prefsLanguage, code);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setString(AppConstants.prefsTheme, switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    });
  }

  void setNotifications(bool enabled) {
    state = state.copyWith(notifications: enabled);
    _prefs.setBool(AppConstants.prefsNotifications, enabled);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

/// Region selected for service discovery. Defaults to the first governorate
/// the marketplace operates in.
final regionProvider = StateProvider<String>((ref) {
  final regions = ref.watch(catalogRepositoryProvider).serviceRegions;
  return regions.isEmpty ? '' : regions.first;
});
