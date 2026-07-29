import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../data/models/app_role.dart';
import '../di/providers.dart';

/// Which of the pilot's three roles (spec §6) is driving the app.
///
/// Device-local, like the theme and the language: it is a fact about who is
/// holding *this* phone, not about the account. When the backend lands, the
/// role comes off the JWT and this notifier becomes a read of that claim —
/// which is why nothing outside it ever writes the preference key directly.
///
/// Defaults to [AppRole.customer]. A customer cannot switch themselves into
/// the workshop or founder panel by accident: the switcher lives at the
/// bottom of Settings and states plainly what it is for.
class RoleNotifier extends Notifier<AppRole> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppRole build() => AppRole.fromKey(_prefs.getString(AppConstants.prefsRole));

  void setRole(AppRole role) {
    state = role;
    _prefs.setString(AppConstants.prefsRole, role.key);
  }
}

final activeRoleProvider =
    NotifierProvider<RoleNotifier, AppRole>(RoleNotifier.new);
