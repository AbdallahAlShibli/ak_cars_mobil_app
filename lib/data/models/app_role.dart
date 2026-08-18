import 'escrow.dart';

/// The three roles the app runs on (spec §6).
///
/// Not a permissions system — the backend owns that, on every request,
/// regardless of what this says. This is the client's own read of "who is
/// this session", derived from real account facts in
/// `role_state.dart`'s `activeRoleProvider` (never from a local, user-settable
/// switch — see that file's doc comment for why). The mapping to
/// [EscrowActor] is what makes the role concrete for the escrow machinery: an
/// [AppRole] is a person, an [EscrowActor] is a party in the transition
/// table, and the state machine only ever speaks the latter.
enum AppRole {
  /// Books, tracks, approves. The default for anyone who isn't the other two.
  customer,

  /// Accepts or rejects jobs, starts work, uploads the completion proof. Only
  /// the account that actually owns an approved workshop gets this.
  workshop,

  /// Confirms funds are held, resolves disputes. Only an account whose JWT
  /// carries the backend's `founder` role claim gets this.
  founder;

  EscrowActor get actor => switch (this) {
        AppRole.customer => EscrowActor.customer,
        AppRole.workshop => EscrowActor.workshop,
        AppRole.founder => EscrowActor.founder,
      };
}
