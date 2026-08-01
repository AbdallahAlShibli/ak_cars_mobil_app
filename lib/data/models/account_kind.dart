import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';

/// What the person registering said they are (spec §8).
///
/// Deliberately *not* the same thing as [AppRole]. An [AppRole] answers "which
/// panel is this device driving right now" and is device-local and switchable;
/// this is a fact about the account, chosen once at registration, and choosing
/// [workshop] grants nothing on its own — it starts an application the founder
/// has to approve (§11).
enum AccountKind { customer, workshop }

extension AccountKindX on AccountKind {
  String label(S s) => switch (this) {
        AccountKind.customer => s.t('حساب عميل', 'Customer account'),
        AccountKind.workshop => s.t('حساب ورشة', 'Workshop account'),
      };

  String description(S s) => switch (this) {
        AccountKind.customer =>
          s.t('احجز وتابع صيانة سياراتك', 'Book and track your car care'),
        AccountKind.workshop =>
          s.t('استقبل طلبات واعرض خدماتك', 'Receive jobs and list your services'),
      };

  IconData get icon => switch (this) {
        AccountKind.customer => LucideIcons.user,
        AccountKind.workshop => LucideIcons.store,
      };

  /// Stable wire value.
  String get key => name;

  static AccountKind fromKey(String? key) {
    for (final value in AccountKind.values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return AccountKind.customer;
  }
}
