import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../data/models/models.dart';
import '../../state/challenge_state.dart';

final _fmt = intl.NumberFormat('#,###', 'en');

/// Weekly challenge (handoff #4d): streak badge, black challenge card with
/// checkable steps + progress, stats row, locked next week, history.
class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final state = ref.watch(challengeProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            SandHeader(
              s.weeklyChallenge,
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: ak.surface,
                  border: Border.all(color: ak.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.flame, size: 13, color: ak.amber),
                    const SizedBox(width: 6),
                    Text(
                      s.t('${state.streakWeeks} أسابيع متتالية',
                          '${state.streakWeeks}-week streak'),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ------------------------------------------------ challenge card
            if (state.current != null)
              _ChallengeCard(challenge: state.current!)
            else
              _AllDoneCard(s: s),
            const SizedBox(height: 14),
            // ------------------------------------------------ stats
            Row(
              children: [
                _StatCard(
                    value: '${state.completedCount}',
                    label: s.t('تحدياً أكملته', 'Challenges done')),
                const SizedBox(width: 11),
                _StatCard(
                  value: _fmt.format(state.points),
                  label: s.t('نقطة ولاء', 'Loyalty points'),
                  valueColor: ak.amberText,
                ),
                const SizedBox(width: 11),
                _StatCard(
                    value: '${state.badgeCount}',
                    label: s.t('وسام', 'Badges')),
              ],
            ),
            const SizedBox(height: 14),
            // ------------------------------------------------ next week
            if (state.next != null) ...[
              Text(s.t('الأسبوع القادم', 'Next week'),
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _NextWeekCard(next: state.next!),
              const SizedBox(height: 14),
            ],
            // ------------------------------------------------ history
            Text(s.t('تحديات أكملتها', 'Completed challenges'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SandCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, p) in state.history.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: i == state.history.length - 1
                            ? null
                            : Border(
                                bottom: BorderSide(color: ak.divider)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                                color: ak.successSoft,
                                shape: BoxShape.circle),
                            child: Icon(LucideIcons.check,
                                size: 13, color: ak.success),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(p.title.of(s),
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text(
                            '+${p.points}',
                            style: AppTheme.numeric(
                                size: 10, color: ak.amberText),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The black (ink) hero card with steps, progress and reward.
class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.challenge});

  final WeeklyChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // On the dark theme the "black card" flips to the cream primary,
    // mirroring how primary buttons invert.
    final cardBg = dark ? ak.surface : const Color(0xFF1D1B17);
    final cardFg = dark ? ak.ink : const Color(0xFFF6F3EE);
    final cardSub = dark ? ak.inkSub : const Color(0xFFB5AF9F);
    final cardFaint =
        dark ? ak.divider : const Color(0xFFF6F3EE).withValues(alpha: 0.12);
    final done = challenge.doneCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: dark ? Border.all(color: ak.border) : null,
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x381D1B17),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3D9A4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  s.t('تحدي هذا الأسبوع', "This week's challenge"),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D1B17),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                s.t('ينتهي بعد ${challenge.endsInDays} أيام',
                    'Ends in ${challenge.endsInDays} days'),
                style: TextStyle(fontSize: 10, color: cardSub),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            challenge.title.of(s),
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: cardFg),
          ),
          const SizedBox(height: 4),
          Text(
            challenge.description.of(s),
            style: TextStyle(fontSize: 11, color: cardSub, height: 1.7),
          ),
          const SizedBox(height: 14),
          for (final step in challenge.steps) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(challengeProvider.notifier).toggleStep(step.id);
              },
              child: Row(
                children: [
                  step.done
                      ? Container(
                          width: 19,
                          height: 19,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6FBE95),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              size: 12, color: Color(0xFF1D1B17)),
                        )
                      : Container(
                          width: 19,
                          height: 19,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cardFg.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                        ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.title.of(s),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: step.done
                            ? cardFg
                            : cardFg.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  if (step.done)
                    Text(
                      s.t('تم', 'Done'),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6FBE95),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 7,
                    child: Stack(
                      children: [
                        Container(
                            color: cardFg.withValues(alpha: 0.15)),
                        FractionallySizedBox(
                          widthFactor: challenge.steps.isEmpty
                              ? 0
                              : done / challenge.steps.length,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3D9A4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$done/${challenge.steps.length}',
                    style: AppTheme.numeric(
                        size: 10,
                        weight: FontWeight.w600,
                        color: cardSub),
                  ),
                  TextSpan(text: ' ${s.t('خطوات', 'steps')}'),
                ]),
                style: TextStyle(fontSize: 10, color: cardSub),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  if (!challenge.allDone) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(s.t('أكمل كل الخطوات أولاً',
                            'Finish all the steps first')),
                      ),
                    );
                    return;
                  }
                  HapticFeedback.mediumImpact();
                  final ok = await ref
                      .read(challengeProvider.notifier)
                      .completeChallenge();
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(s.t(
                          '+${challenge.rewardPoints} نقطة ووسام «${challenge.badgeName.ar}» 🎉',
                          '+${challenge.rewardPoints} points and the "${challenge.badgeName.en}" badge 🎉',
                        )),
                      ),
                    );
                  }
                },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: challenge.allDone ? 1 : 0.55,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: dark ? ak.primary : const Color(0xFFF6F3EE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      s.t('أكمل التحدي', 'Complete challenge'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            dark ? ak.onPrimary : const Color(0xFF1D1B17),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: cardFaint)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 15, color: Color(0xFFF3D9A4)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: s.t('المكافأة: ', 'Reward: ')),
                      TextSpan(
                        text: '+${challenge.rewardPoints} ${s.t('نقطة', 'points')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF3D9A4),
                        ),
                      ),
                      TextSpan(
                        text: s.t(' + وسام «${challenge.badgeName.ar}»',
                            ' + "${challenge.badgeName.en}" badge'),
                      ),
                    ]),
                    style: TextStyle(fontSize: 11, color: cardSub),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard({required this.s});

  final S s;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return SandCard(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: ak.successSoft, shape: BoxShape.circle),
            child: Icon(LucideIcons.partyPopper, size: 20, color: ak.success),
          ),
          const SizedBox(height: 10),
          Text(
            s.t('أكملت تحدي هذا الأسبوع!', "This week's challenge is done!"),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            s.t('تحدٍّ جديد يُفتح الأحد القادم.',
                'A new challenge unlocks next Sunday.'),
            style: TextStyle(fontSize: 11, color: ak.inkSub),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Expanded(
      child: SandCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value,
                style:
                    AppTheme.numeric(size: 18, color: valueColor ?? ak.ink)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, color: ak.inkSub),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextWeekCard extends StatelessWidget {
  const _NextWeekCard({required this.next});

  final LockedChallenge next;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ak.inkFaint, style: BorderStyle.solid),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ak.surface.withValues(alpha: 0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ak.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.lock, size: 16, color: ak.inkSub),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next.title.of(s),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ak.inkSub),
                ),
                const SizedBox(height: 2),
                Text(
                  s.t('يُفتح الأحد القادم · +${next.points} نقطة',
                      'Unlocks next Sunday · +${next.points} points'),
                  style: TextStyle(fontSize: 10, color: ak.inkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
