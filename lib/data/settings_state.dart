import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Injected in main() after SharedPreferences loads.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

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
  static const _kLang = 'akcars_lang';
  static const _kTheme = 'akcars_theme';
  static const _kNotifications = 'akcars_notifications';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  SettingsState build() {
    // First launch defaults per the handoff: Arabic + cream light theme.
    final lang = _prefs.getString(_kLang) ?? 'ar';
    final theme = _prefs.getString(_kTheme) ?? 'light';
    return SettingsState(
      locale: Locale(lang),
      themeMode: switch (theme) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      notifications: _prefs.getBool(_kNotifications) ?? true,
    );
  }

  void setLanguage(String code) {
    state = state.copyWith(locale: Locale(code));
    _prefs.setString(_kLang, code);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setString(_kTheme, switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    });
  }

  void setNotifications(bool enabled) {
    state = state.copyWith(notifications: enabled);
    _prefs.setBool(_kNotifications, enabled);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
