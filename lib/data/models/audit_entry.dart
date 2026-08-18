import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'escrow.dart';

/// What kind of thing an [AuditEntry] is about.
///
/// Deliberately coarse. The log answers "who changed what, when, and why" for
/// the four things in the pilot that move money, access or visibility — and
/// nothing else. A log that records everything is a log nobody reads.
enum AuditSubjectType {
  /// A booking's escrow position moved.
  booking,

  /// A workshop's [ProviderOnboardingStage] moved — including the approval or
  /// rejection of a new registration (§11 step 3).
  provider,

  /// An offer was switched on or off by the founder.
  offer,

  /// A payout was marked as transferred.
  payout,

  /// A workshop's own stock — an item created/edited/deleted, or a stock
  /// movement recorded (spec: Workshop Provider Dashboard).
  inventory,

  /// A workshop's own roster — a team member created/edited/deactivated.
  staff,

  /// A workshop's own annotation on a customer it has actually served — a
  /// note added.
  customer;

  String get key => name;

  static AuditSubjectType fromKey(String? key) {
    for (final value in AuditSubjectType.values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return AuditSubjectType.booking;
  }
}

extension AuditSubjectTypeX on AuditSubjectType {
  String label(S s) => switch (this) {
        AuditSubjectType.booking => s.t('حجز', 'Booking'),
        AuditSubjectType.provider => s.t('ورشة', 'Workshop'),
        AuditSubjectType.offer => s.t('عرض', 'Offer'),
        AuditSubjectType.payout => s.t('تحويل', 'Payout'),
        AuditSubjectType.inventory => s.t('مخزون', 'Inventory'),
        AuditSubjectType.staff => s.t('فريق', 'Staff'),
        AuditSubjectType.customer => s.t('عميل', 'Customer'),
      };
}

/// One line of the platform's audit trail (spec §6).
///
/// **Written from exactly one place per subject type**, inside the repository
/// that performs the change — never from a screen. That is the whole design:
/// a screen that could write its own audit line could also forget to, and an
/// audit trail with holes in it is worse than none, because it is trusted.
///
/// Distinct from [EscrowEntry], which lives *on* a booking and records only
/// that booking's own state machine. This one is the platform-wide ledger and
/// spans four subject types, which is why it stores ids rather than objects.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.actor,
    required this.actorId,
    required this.action,
    required this.subjectType,
    required this.subjectId,
    this.fromState,
    this.toState,
    this.note,
  });

  final String id;
  final DateTime at;

  /// Which party made the change, in the same vocabulary the escrow machine
  /// uses — so a booking's audit lines and its escrow history agree about who
  /// did what.
  final EscrowActor actor;

  /// The specific account behind [actor]. In the pilot there is one founder
  /// and the workshops are identified by provider id; when the backend lands
  /// this becomes the JWT subject.
  final String actorId;

  /// What happened, as a stable machine key (`escrow.approve`,
  /// `provider.approved`, `offer.enabled`, `payout.marked`). Not display text:
  /// the log is filtered on this, and a filter that matches on a translated
  /// sentence breaks the moment somebody switches language.
  final String action;

  final AuditSubjectType subjectType;
  final String subjectId;

  /// The state before and after, where the subject has states. Both null for
  /// an action that is not a transition (marking a payout).
  final String? fromState;
  final String? toState;

  /// Free text explaining the change. Mandatory in practice for a rejection —
  /// see `ServiceMarketplaceRepository.setProviderStage`, which refuses to
  /// suspend a workshop without one.
  final String? note;

  /// True when this line records a decision a human made rather than something
  /// the machine did on a timer. The founder's filter defaults to these.
  bool get isHumanDecision => actor != EscrowActor.system;

  factory AuditEntry.fromJson(JsonMap json) => AuditEntry(
        id: json.requireString('id'),
        at: json.dateTimeOr('at', DateTime.now()),
        actor: json.enumOr('actor', EscrowActor.values, EscrowActor.system),
        actorId: json.stringOr('actorId', ''),
        action: json.stringOr('action', ''),
        subjectType: AuditSubjectType.fromKey(json.stringOrNull('subjectType')),
        subjectId: json.stringOr('subjectId', ''),
        fromState: json.stringOrNull('fromState'),
        toState: json.stringOrNull('toState'),
        note: json.stringOrNull('note'),
      );

  JsonMap toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'actor': actor.key,
        'actorId': actorId,
        'action': action,
        'subjectType': subjectType.key,
        'subjectId': subjectId,
        'fromState': fromState,
        'toState': toState,
        'note': note,
      };

  AuditEntry copyWith({
    String? id,
    DateTime? at,
    EscrowActor? actor,
    String? actorId,
    String? action,
    AuditSubjectType? subjectType,
    String? subjectId,
    String? fromState,
    String? toState,
    String? note,
  }) =>
      AuditEntry(
        id: id ?? this.id,
        at: at ?? this.at,
        actor: actor ?? this.actor,
        actorId: actorId ?? this.actorId,
        action: action ?? this.action,
        subjectType: subjectType ?? this.subjectType,
        subjectId: subjectId ?? this.subjectId,
        fromState: fromState ?? this.fromState,
        toState: toState ?? this.toState,
        note: note ?? this.note,
      );

  @override
  bool operator ==(Object other) =>
      other is AuditEntry &&
      other.id == id &&
      other.at == at &&
      other.actor == actor &&
      other.actorId == actorId &&
      other.action == action &&
      other.subjectType == subjectType &&
      other.subjectId == subjectId &&
      other.fromState == fromState &&
      other.toState == toState &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, at, actor, actorId, action, subjectType,
      subjectId, fromState, toState, note);
}

extension AuditEntryListX on Iterable<AuditEntry> {
  /// Newest first — the only order a log is ever read in.
  List<AuditEntry> get newestFirst {
    final sorted = [...this]..sort((a, b) => b.at.compareTo(a.at));
    return sorted;
  }

  /// Every line about one subject, for the "history" strip on a workshop card
  /// or a booking.
  List<AuditEntry> about(AuditSubjectType type, String subjectId) => [
        for (final e in this)
          if (e.subjectType == type && e.subjectId == subjectId) e,
      ];

  /// Filtered by subject type; null returns everything.
  List<AuditEntry> ofType(AuditSubjectType? type) =>
      type == null ? [...this] : [for (final e in this) if (e.subjectType == type) e];
}
