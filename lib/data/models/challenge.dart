import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'maintenance.dart';

/// One checkable task inside a [WeeklyChallenge].
class ChallengeStep {
  const ChallengeStep({
    required this.id,
    required this.title,
    this.done = false,
  });

  final String id;
  final L title;
  final bool done;

  factory ChallengeStep.fromJson(JsonMap json) => ChallengeStep(
        id: json.requireString('id'),
        title: L.fromJson(json['title']),
        done: json.boolOr('done', false),
      );

  JsonMap toJson() => {
        'id': id,
        'title': title.toJson(),
        'done': done,
      };

  ChallengeStep copyWith({String? id, L? title, bool? done}) => ChallengeStep(
        id: id ?? this.id,
        title: title ?? this.title,
        done: done ?? this.done,
      );

  @override
  bool operator ==(Object other) =>
      other is ChallengeStep &&
      other.id == id &&
      other.title == title &&
      other.done == done;

  @override
  int get hashCode => Object.hash(id, title, done);
}

/// The active weekly challenge. Completing every step grants loyalty points
/// and a badge, and extends the weekly streak.
class WeeklyChallenge {
  const WeeklyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
    required this.rewardPoints,
    required this.badgeName,
    required this.endsInDays,
    this.feedsMaintenance,
    this.recordTitle,
  });

  final String id;
  final L title;
  final L description;
  final List<ChallengeStep> steps;
  final int rewardPoints;
  final L badgeName;
  final int endsInDays;

  /// When set, completing the challenge writes a maintenance record of this
  /// type — the handoff's "challenge feeds the maintenance log".
  final MaintenanceType? feedsMaintenance;

  /// Title of the record [feedsMaintenance] writes. Null falls back to
  /// [challengeRecordTitle].
  ///
  /// Carried per challenge because the record has to say what was actually
  /// done: an EV owner who inspected a charging cable must not find "tyre
  /// pressure check" in their service history.
  final L? recordTitle;

  int get doneCount => steps.where((s) => s.done).length;
  bool get allDone => doneCount == steps.length;

  factory WeeklyChallenge.fromJson(JsonMap json) => WeeklyChallenge(
        id: json.requireString('id'),
        title: L.fromJson(json['title']),
        description: L.fromJson(json['description']),
        steps: json.objectList('steps').map(ChallengeStep.fromJson).toList(),
        rewardPoints: json.intOr('rewardPoints', 0),
        badgeName: L.fromJson(json['badgeName']),
        endsInDays: json.intOr('endsInDays', 0),
        feedsMaintenance: json['feedsMaintenance'] == null
            ? null
            : json.enumOr(
                'feedsMaintenance',
                MaintenanceType.values,
                MaintenanceType.oil,
              ),
        recordTitle:
            json['recordTitle'] == null ? null : L.fromJson(json['recordTitle']),
      );

  JsonMap toJson() => {
        'id': id,
        'title': title.toJson(),
        'description': description.toJson(),
        'steps': [for (final s in steps) s.toJson()],
        'rewardPoints': rewardPoints,
        'badgeName': badgeName.toJson(),
        'endsInDays': endsInDays,
        'feedsMaintenance': feedsMaintenance?.key,
        'recordTitle': recordTitle?.toJson(),
      };

  WeeklyChallenge copyWith({
    String? id,
    L? title,
    L? description,
    List<ChallengeStep>? steps,
    int? rewardPoints,
    L? badgeName,
    int? endsInDays,
    MaintenanceType? feedsMaintenance,
    L? recordTitle,
  }) =>
      WeeklyChallenge(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        steps: steps ?? this.steps,
        rewardPoints: rewardPoints ?? this.rewardPoints,
        badgeName: badgeName ?? this.badgeName,
        endsInDays: endsInDays ?? this.endsInDays,
        feedsMaintenance: feedsMaintenance ?? this.feedsMaintenance,
        recordTitle: recordTitle ?? this.recordTitle,
      );

  @override
  bool operator ==(Object other) =>
      other is WeeklyChallenge &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.rewardPoints == rewardPoints &&
      other.badgeName == badgeName &&
      other.endsInDays == endsInDays &&
      other.feedsMaintenance == feedsMaintenance &&
      other.recordTitle == recordTitle &&
      Object.hashAll(other.steps) == Object.hashAll(steps);

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        rewardPoints,
        badgeName,
        endsInDays,
        feedsMaintenance,
        recordTitle,
        Object.hashAll(steps),
      );
}

/// Product rule: a completed challenge that feeds the maintenance log writes
/// a record under [WeeklyChallenge.recordTitle], or this when the challenge
/// does not name one. Attributed to the app rather than a workshop.
const challengeRecordTitle =
    L('فحص ضغط الإطارات (تحدي)', 'Tyre pressure check (challenge)');

const challengeRecordWorkshop = 'AK Challenge';

/// An archived challenge in the user's history.
class PastChallenge {
  const PastChallenge({required this.title, required this.points});

  final L title;
  final int points;

  factory PastChallenge.fromJson(JsonMap json) => PastChallenge(
        title: L.fromJson(json['title']),
        points: json.intOr('points', 0),
      );

  JsonMap toJson() => {'title': title.toJson(), 'points': points};

  PastChallenge copyWith({L? title, int? points}) => PastChallenge(
        title: title ?? this.title,
        points: points ?? this.points,
      );

  @override
  bool operator ==(Object other) =>
      other is PastChallenge && other.title == title && other.points == points;

  @override
  int get hashCode => Object.hash(title, points);
}

/// Next week's challenge, teased but not yet startable.
class LockedChallenge {
  const LockedChallenge({required this.title, required this.points});

  final L title;
  final int points;

  factory LockedChallenge.fromJson(JsonMap json) => LockedChallenge(
        title: L.fromJson(json['title']),
        points: json.intOr('points', 0),
      );

  JsonMap toJson() => {'title': title.toJson(), 'points': points};

  LockedChallenge copyWith({L? title, int? points}) => LockedChallenge(
        title: title ?? this.title,
        points: points ?? this.points,
      );

  @override
  bool operator ==(Object other) =>
      other is LockedChallenge &&
      other.title == title &&
      other.points == points;

  @override
  int get hashCode => Object.hash(title, points);
}

/// Everything the challenge screen renders: the active challenge, the tease
/// for next week, history, and the loyalty totals.
class ChallengeBoard {
  const ChallengeBoard({
    required this.current,
    required this.next,
    required this.history,
    required this.streakWeeks,
    required this.completedCount,
    required this.points,
    required this.badgeCount,
  });

  final WeeklyChallenge? current;
  final LockedChallenge? next;
  final List<PastChallenge> history;
  final int streakWeeks;
  final int completedCount;

  /// Loyalty points balance.
  final int points;
  final int badgeCount;

  static const empty = ChallengeBoard(
    current: null,
    next: null,
    history: [],
    streakWeeks: 0,
    completedCount: 0,
    points: 0,
    badgeCount: 0,
  );

  factory ChallengeBoard.fromJson(JsonMap json) => ChallengeBoard(
        current: json.objectOrNull('current') == null
            ? null
            : WeeklyChallenge.fromJson(json.requireObject('current')),
        next: json.objectOrNull('next') == null
            ? null
            : LockedChallenge.fromJson(json.requireObject('next')),
        history:
            json.objectList('history').map(PastChallenge.fromJson).toList(),
        streakWeeks: json.intOr('streakWeeks', 0),
        completedCount: json.intOr('completedCount', 0),
        points: json.intOr('points', 0),
        badgeCount: json.intOr('badgeCount', 0),
      );

  JsonMap toJson() => {
        'current': current?.toJson(),
        'next': next?.toJson(),
        'history': [for (final h in history) h.toJson()],
        'streakWeeks': streakWeeks,
        'completedCount': completedCount,
        'points': points,
        'badgeCount': badgeCount,
      };

  ChallengeBoard copyWith({
    WeeklyChallenge? Function()? current,
    LockedChallenge? Function()? next,
    List<PastChallenge>? history,
    int? streakWeeks,
    int? completedCount,
    int? points,
    int? badgeCount,
  }) =>
      ChallengeBoard(
        current: current != null ? current() : this.current,
        next: next != null ? next() : this.next,
        history: history ?? this.history,
        streakWeeks: streakWeeks ?? this.streakWeeks,
        completedCount: completedCount ?? this.completedCount,
        points: points ?? this.points,
        badgeCount: badgeCount ?? this.badgeCount,
      );
}
