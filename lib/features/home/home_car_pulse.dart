import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../data/models/models.dart';

/// How a car is doing, summed up from its own maintenance book.
///
/// Direction A of the home redesign ("نبض سيارتك"): one number and one word
/// instead of a list the owner has to read. Both come only from the lines
/// that have a record *and* a schedule to measure it against — an item the
/// owner never logged has no progress, and guessing one would turn the score
/// into decoration.
class CarPulse {
  const CarPulse._({
    required this.score,
    required this.state,
    required this.tracked,
  });

  /// Null when not a single line can be measured yet: the card then keeps its
  /// "when did you last…" prompt and shows no score at all.
  static CarPulse? from(List<DueItem> due) {
    final tracked = [
      for (final d in due.byUrgency)
        if (d.progress != null && d.status != DueStatus.noRecord) d,
    ];
    if (tracked.isEmpty) return null;

    final left = tracked
        .map((d) => 1 - d.progress!.clamp(0.0, 1.0))
        .reduce((a, b) => a + b);
    var score = (left / tracked.length * 100).round();

    final state = tracked.any((d) => d.status == DueStatus.due)
        ? PulseState.overdue
        : tracked.any((d) => d.status == DueStatus.near)
        ? PulseState.soon
        : PulseState.ready;
    // An overdue line must never sit under a reassuring number: the average
    // of a fresh oil change and overdue brakes is not "fine".
    if (state == PulseState.overdue && score > overdueCeiling) {
      score = overdueCeiling;
    }
    return CarPulse._(score: score, state: state, tracked: tracked);
  }

  /// The highest score a car with an overdue item can show.
  static const overdueCeiling = 49;

  /// 0–100: the average share of each measured interval still left.
  final int score;
  final PulseState state;

  /// Measured lines, most urgent first.
  final List<DueItem> tracked;
}

enum PulseState { ready, soon, overdue }

/// The ring, its word, and up to [maxBars] measured lines.
class CarPulseBlock extends StatelessWidget {
  const CarPulseBlock({super.key, required this.pulse});

  final CarPulse pulse;

  static const maxBars = 3;
  static const _ring = 64.0;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final (color, label) = switch (pulse.state) {
      PulseState.ready => (
        ak.success,
        s.t('جاهزة للطريق', 'Ready for the road'),
      ),
      PulseState.soon => (ak.amber, s.t('صيانة قريبة', 'Service coming up')),
      PulseState.overdue => (
        ak.danger,
        s.t('تحتاج صيانة الآن', 'Needs service now'),
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: s.t(
            'درجة العناية ${pulse.score} من 100',
            'Care score ${pulse.score} of 100',
          ),
          child: SizedBox(
            width: _ring,
            height: _ring,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: pulse.score / 100,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: ak.surfaceDim,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                ExcludeSemantics(
                  child: Text(
                    '${pulse.score}',
                    style: AppTheme.numeric(size: 19, color: ak.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                s.t('درجة العناية', 'Care score'),
                style: TextStyle(fontSize: 11.5, color: ak.inkFaint),
              ),
              const SizedBox(height: 6),
              for (final d in pulse.tracked.take(maxBars)) _PulseBar(item: d),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulseBar extends StatelessWidget {
  const _PulseBar({required this.item});

  final DueItem item;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final left = 1 - item.progress!.clamp(0.0, 1.0);
    final color = switch (item.status) {
      DueStatus.due => ak.danger,
      DueStatus.near => ak.amber,
      _ => ak.success,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              item.shortTitle.of(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: ak.inkSub),
            ),
          ),
          Expanded(
            child: SandProgressBar(value: left, color: color, height: 5),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '${(left * 100).round()}%',
              textAlign: TextAlign.end,
              style: AppTheme.numeric(size: 11.5, color: ak.inkSub),
            ),
          ),
        ],
      ),
    );
  }
}
