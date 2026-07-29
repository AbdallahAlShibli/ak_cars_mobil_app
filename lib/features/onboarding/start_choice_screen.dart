import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';

/// Rule 3 — start with a registered car, or skip and choose per request.
///
/// Last step of first launch, so it carries the "3 of 3" progress cue: the
/// point is to make the setup read as nearly over, not as a new form.
///
/// Only the selected option expands its detail (progressive disclosure) —
/// showing both cards' benefit lists at once made the screen a wall of text
/// in Arabic, where every line runs longer.
class StartChoiceScreen extends ConsumerStatefulWidget {
  const StartChoiceScreen({super.key});

  @override
  ConsumerState<StartChoiceScreen> createState() => _StartChoiceScreenState();
}

class _StartChoiceScreenState extends ConsumerState<StartChoiceScreen> {
  bool _addCar = true;

  void _select(bool addCar) {
    if (_addCar == addCar) return;
    HapticFeedback.selectionClick();
    setState(() => _addCar = addCar);
  }

  Future<void> _continue() async {
    HapticFeedback.mediumImpact();
    if (!_addCar) {
      _skip();
      return;
    }
    // Website-style picker: make grid → model → year + Oman plate.
    // Awaited: /add-car pops back onto this screen, so without reacting to
    // the result the user would land right back on this question after
    // finishing the form.
    final saved = await context.push<bool>('/add-car');
    if (!mounted) return;
    // `/add-car` records the choice itself when it saves (add_car_screen.dart),
    // so there is nothing to mark here.
    if (saved ?? false) context.go(AppFlags.startLocation);
  }

  void _skip() {
    ref.read(authProvider.notifier).markStartChoiceMade();
    context.go(AppFlags.startLocation);
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: Column(
          children: [
            _StepBar(
              step: 3,
              of: 3,
              onSkip: _skip,
              skipLabel: s.t('تخطّي', 'Skip'),
              stepLabel: s.t('الخطوة ٣ من ٣', 'Step 3 of 3'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  Entrance(
                    child: Text(
                      s.t('كيف تود أن تبدأ؟', 'How would you like to start?'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Entrance(
                    delayMs: 60,
                    child: Text(
                      s.t(
                        'خطوة واحدة أخيرة. سجّل سيارتك ليصبح كل شيء مطابقاً لها، أو تصفّح أولاً — يمكنك تغيير هذا في أي وقت من ملفك الشخصي.',
                        'One last step. Register your car so everything matches it, or browse first — you can change this anytime from your profile.',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: ak.inkSub,
                        height: 1.65,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Entrance(
                    delayMs: 120,
                    child: _ChoiceCard(
                      selected: _addCar,
                      onTap: () => _select(true),
                      icon: LucideIcons.car,
                      title: s.t('أضف سيارتي الآن', 'Add my car now'),
                      subtitle: s.t('موصى به · أقل من دقيقة',
                          'Recommended · under a minute'),
                      body: s.t(
                        'اختر الشركة والموديل من الكتالوج، وأضف لوحتك العمانية.',
                        'Pick your make and model from the catalog, and add your Oman plate.',
                      ),
                      benefits: [
                        (
                          LucideIcons.wrench,
                          s.t('عروض أسعار من ورش تخدم سيارتك بالتحديد',
                              'Quotes from workshops that service your exact car'),
                        ),
                        (
                          LucideIcons.shoppingBag,
                          s.t('قطع غيار مفلترة على موديلك وسنة الصنع',
                              'Parts filtered to your model and year'),
                        ),
                        (
                          LucideIcons.bellRing,
                          s.t('تذكيرات صيانة محسوبة من ممشى سيارتك',
                              'Service reminders worked out from your mileage'),
                        ),
                      ],
                      steps: [
                        s.t('١ الشركة', '1 Make'),
                        s.t('٢ الموديل', '2 Model'),
                        s.t('٣ السنة واللوحة', '3 Year & plate'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Entrance(
                    delayMs: 180,
                    child: _ChoiceCard(
                      selected: !_addCar,
                      onTap: () => _select(false),
                      icon: LucideIcons.compass,
                      title: s.t('ليس الآن', 'Not now'),
                      subtitle: s.t('تصفّح بحرية', 'Browse freely'),
                      body: s.t(
                        'اذهب مباشرة إلى التطبيق واختر تفاصيل السيارة في كل مرة تقدم فيها طلباً.',
                        'Go straight into the app and pick the car details each time you make a request.',
                      ),
                      benefits: [
                        (
                          LucideIcons.compass,
                          s.t('تصفّح الإعلانات والورش والقطع في كل عُمان',
                              'Browse listings, workshops, and parts across Oman'),
                        ),
                        (
                          LucideIcons.clock3,
                          s.t('أضف سيارتك لاحقاً من "مرآبي" في أي وقت',
                              'Add your car later from My Garage, anytime'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Entrance(
                    delayMs: 240,
                    child: Row(
                      children: [
                        Icon(LucideIcons.shieldCheck,
                            size: 15, color: ak.inkFaint),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.t(
                              'بياناتك تبقى على جهازك ولا تُعرض على أي مزوّد خدمة حتى تطلب ذلك بنفسك.',
                              'Your details stay on your device and are shared with a provider only when you ask.',
                            ),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: ak.inkFaint,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomBar(
              label: _addCar
                  ? s.t('اختر سيارتي', 'Choose my car')
                  : s.t('متابعة إلى التطبيق', 'Continue to the app'),
              icon: _addCar ? LucideIcons.car : LucideIcons.compass,
              onTap: _continue,
            ),
          ],
        ),
      ),
    );
  }
}

/// Top row: "Step 3 of 3" + a thin filled track, with Skip on the far end.
///
/// The bar is the reassurance that setup is nearly over — the old screen
/// gave no sense of where in the flow the user was.
class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.step,
    required this.of,
    required this.onSkip,
    required this.skipLabel,
    required this.stepLabel,
  });

  final int step;
  final int of;
  final VoidCallback onSkip;
  final String skipLabel;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: ak.inkFaint,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i <= of; i++) ...[
                      if (i > 1) const SizedBox(width: 5),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= step ? ak.ink : ak.surfaceDim,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onSkip,
            child: Text(
              skipLabel,
              style: TextStyle(color: ak.inkSub, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable option card. Unselected it is a quiet one-liner; selected it
/// lifts, gains an ink border, and expands its benefits and step chips.
class _ChoiceCard extends StatefulWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.benefits,
    this.steps = const [],
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;

  /// Icon + line pairs shown once the card is selected.
  final List<(IconData, String)> benefits;

  /// Optional "1 Make › 2 Model › 3 Year & plate" preview of the form.
  final List<String> steps;

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final on = widget.selected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.985 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ak.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: on ? ak.primary : ak.border,
              width: on ? 2 : 1,
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: ak.ink.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: on ? ak.primary : ak.surfaceDim,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 21,
                      color: on ? ak.onPrimary : ak.inkSub,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: on ? ak.amberText : ak.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Radio(selected: on),
                ],
              ),
              // Only the chosen card explains itself, so the screen stays
              // short enough to read without scrolling on a small phone.
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: on ? 1 : 0,
                    child: on
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 14),
                              Text(
                                widget.body,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: ak.inkSub,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (final (icon, line) in widget.benefits)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 9),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: ak.surfaceDim,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(icon,
                                            size: 13, color: ak.ink),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 3),
                                          child: Text(
                                            line,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: ak.ink,
                                              height: 1.45,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (widget.steps.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                // Wraps to a second line rather than
                                // clipping — the step labels are longer in
                                // Arabic.
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    for (var i = 0;
                                        i < widget.steps.length;
                                        i++) ...[
                                      if (i > 0)
                                        // Mirrors in Arabic — a fixed
                                        // right-chevron would point back up
                                        // the step order in RTL.
                                        Icon(
                                          Directionality.of(context) ==
                                                  TextDirection.rtl
                                              ? Icons.chevron_left_rounded
                                              : Icons.chevron_right_rounded,
                                          size: 15,
                                          color: ak.inkFaint,
                                        ),
                                      StatusBadge(widget.steps[i]),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated radio dot — fills with ink and draws a tick when selected.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? ak.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? ak.primary : ak.border,
          width: 1.5,
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: selected ? 1 : 0,
        child: Icon(LucideIcons.check, size: 14, color: ak.onPrimary),
      ),
    );
  }
}

/// Bottom action bar — a hairline divider keeps the pill readable while the
/// list scrolls underneath it.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: ak.bg,
        border: Border(top: BorderSide(color: ak.divider)),
      ),
      child: FilledButton(
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
