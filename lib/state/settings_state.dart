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
  }) => SettingsState(
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

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

/// Which workshop-application stage the owner has dismissed the "My account"
/// status card for, or null while they have dismissed nothing.
///
/// Stores the stage key, not a boolean: the card says one specific thing
/// ("approved", "under review", "needs a change"), and dismissing one of
/// those sentences is not consent to never hear the next one. When the
/// founder later suspends or approves the workshop the stage changes, this
/// no longer matches, and the card comes back on its own.
class WorkshopNoticeDismissalNotifier extends Notifier<String?> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  String? build() =>
      _prefs.getString(AppConstants.prefsWorkshopNoticeDismissedStage);

  /// Hide the card for [stageKey] until the stage itself changes.
  void dismiss(String stageKey) {
    state = stageKey;
    _prefs.setString(AppConstants.prefsWorkshopNoticeDismissedStage, stageKey);
  }

  /// Bring it back — what the always-visible status row in "My account" does
  /// when tapped, so a dismissal is never a one-way door.
  void restore() {
    state = null;
    _prefs.remove(AppConstants.prefsWorkshopNoticeDismissedStage);
  }

  bool isDismissedFor(String stageKey) => state == stageKey;
}

final workshopNoticeDismissalProvider =
    NotifierProvider<WorkshopNoticeDismissalNotifier, String?>(
      WorkshopNoticeDismissalNotifier.new,
    );

/// Region selected for service discovery. Defaults to the first governorate
/// the marketplace operates in.
///
/// **`ref.read`, not `ref.watch`, and that is load-bearing.** This is a
/// `StateProvider`: the closure below only ever supplies the *initial*
/// value, and every real change to it afterwards is a plain `.state =`
/// write from the region picker (`settings_screen.dart`,
/// `services_screen.dart`). If this instead `watch`ed the catalogue
/// repository, every `WarmCacheNotice.announce()` — which
/// `SessionRefresh` fires on *both* sign-in and sign-out, since the public
/// catalogues are re-warmed either way — would invalidate this whole
/// provider and re-run the closure, discarding whatever region the user had
/// selected and silently snapping it back to `regions.first`. That is a
/// device preference, not account data; a sign-out clearing the signed-in
/// user's own information must not also reset it, or reset the Services/
/// Home/Garage/Register screens that filter by it out from under someone
/// who is still signed in and simply refreshed their session. `read` still
/// lets a fresh install (an empty catalogue warmed a moment before this is
/// first touched) pick a sensible default — it just never does so again.
final regionProvider = StateProvider<String>((ref) {
  final regions = ref.read(catalogRepositoryProvider).serviceRegions;
  return regions.isEmpty ? '' : regions.first;
});
