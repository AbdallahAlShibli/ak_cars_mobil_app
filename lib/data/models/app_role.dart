import '../../core/i18n/strings.dart';
import 'escrow.dart';

/// The three roles the pilot runs on (spec §6), all on one build.
///
/// Not a permissions system — the backend will own that. This is the pilot's
/// answer to "who is holding the phone right now", and it decides which
/// escrow transitions the UI offers. The mapping to [EscrowActor] is what
/// makes that concrete: an [AppRole] is a person, an [EscrowActor] is a party
/// in the transition table, and the state machine only ever speaks the latter.
enum AppRole {
  /// Books, tracks, approves. The only role a real user has.
  customer,

  /// Accepts or rejects jobs, starts work, uploads the completion proof.
  workshop,

  /// You. Confirms funds are held, resolves disputes. Spec §6: "وظيفتها
  /// التشغيل لا الإبهار" — an operating tool, not a showpiece.
  founder;

  String get key => name;

  EscrowActor get actor => switch (this) {
        AppRole.customer => EscrowActor.customer,
        AppRole.workshop => EscrowActor.workshop,
        AppRole.founder => EscrowActor.founder,
      };

  static AppRole fromKey(String? key) {
    for (final role in AppRole.values) {
      if (role.key == key) return role;
    }
    return AppRole.customer;
  }
}

extension AppRoleX on AppRole {
  String label(S s) => switch (this) {
        AppRole.customer => s.t('عميل', 'Customer'),
        AppRole.workshop => s.t('ورشة', 'Workshop'),
        AppRole.founder => s.t('مؤسس', 'Founder'),
      };

  String description(S s) => switch (this) {
        AppRole.customer =>
          s.t('يحجز، يتابع، يوافق.', 'Books, tracks, approves.'),
        AppRole.workshop => s.t('تقبل/ترفض، تبدأ، ترفع الإثبات.',
            'Accepts or rejects, starts work, submits proof.'),
        AppRole.founder => s.t('يحرّك حالات الضمان يدوياً ويحلّ النزاعات.',
            'Moves escrow states by hand and resolves disputes.'),
      };

  /// Whether this role gets an operator panel of its own.
  bool get hasPanel => this != AppRole.customer;

  /// Where switching into this role should land.
  String get panelRoute => switch (this) {
        AppRole.customer => '/bookings',
        AppRole.workshop => '/workshop',
        AppRole.founder => '/admin',
      };
}
