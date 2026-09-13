import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../i18n/strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/bidi_text.dart';
import 'widgets.dart';

/// A workshop's opening hours as *data* rather than as a sentence somebody
/// typed.
///
/// The API stores `hours` as a free-text [L] pair ("Sat–Thu 7:30–19:00 · Fri
/// closed"), and it stays that way — this is the structure the editor works
/// in, rendered back to that string on save. Typing the sentence by hand is
/// how the two languages drift apart, how "١٩:٠٠" ends up next to "19:00",
/// and how a workshop ends up advertising hours nothing can parse.
///
/// [parse] reads an already-stored sentence back into this shape so the
/// picker opens on what is actually saved; it returns null when the text is
/// not recognisable, and the editor then says so rather than quietly
/// replacing it.
@immutable
class WorkingHours {
  const WorkingHours({
    required this.openDays,
    required this.opens,
    required this.closes,
  });

  /// Open days, as `DateTime.monday` … `DateTime.sunday` values.
  final Set<int> openDays;
  final TimeOfDay opens;
  final TimeOfDay closes;

  /// The week in the order Oman reads it — Saturday first, Friday last.
  static const week = <int>[
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

  /// What the picker opens on when there is nothing stored to read back —
  /// the ordinary Omani working week, not an empty form.
  static const standard = WorkingHours(
    openDays: {
      DateTime.saturday,
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    },
    opens: TimeOfDay(hour: 8, minute: 0),
    closes: TimeOfDay(hour: 18, minute: 0),
  );

  WorkingHours copyWith({
    Set<int>? openDays,
    TimeOfDay? opens,
    TimeOfDay? closes,
  }) => WorkingHours(
    openDays: openDays ?? this.openDays,
    opens: opens ?? this.opens,
    closes: closes ?? this.closes,
  );

  /// A closing time at or before the opening time — worth saying out loud,
  /// since it is a typo far more often than it is an overnight shift.
  bool get closesBeforeItOpens => _minutes(closes) <= _minutes(opens);

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  /// 24-hour, zero-padded: the same shape as the schedule's slot template,
  /// and unambiguous in both languages.
  static String formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  static String dayLabel(int day, S s) => switch (day) {
    DateTime.saturday => s.t('السبت', 'Sat'),
    DateTime.sunday => s.t('الأحد', 'Sun'),
    DateTime.monday => s.t('الاثنين', 'Mon'),
    DateTime.tuesday => s.t('الثلاثاء', 'Tue'),
    DateTime.wednesday => s.t('الأربعاء', 'Wed'),
    DateTime.thursday => s.t('الخميس', 'Thu'),
    _ => s.t('الجمعة', 'Fri'),
  };

  /// Both languages, written the same way — which is the point of not typing
  /// them.
  L format() => L(_render(const S(true)), _render(const S(false)));

  String _render(S s) {
    if (openDays.isEmpty) return s.t('مغلقة مؤقتاً', 'Temporarily closed');
    final open = _joinRuns(week.where(openDays.contains).toList(), s);
    final closed = week.where((d) => !openDays.contains(d)).toList();
    final range = '${formatTime(opens)}–${formatTime(closes)}';
    if (closed.isEmpty) return '$open $range';
    final names = _joinRuns(closed, s);
    return '$open $range · ${s.t('$names مغلق', '$names closed')}';
  }

  /// Contiguous days collapse into a range ("Sat–Thu"); two days read better
  /// as a pair ("Thu, Fri") than as a range of two.
  static String _joinRuns(List<int> days, S s) {
    final runs = <List<int>>[];
    for (final day in week) {
      if (!days.contains(day)) continue;
      final previous = week.indexOf(day) - 1;
      if (runs.isNotEmpty &&
          previous >= 0 &&
          runs.last.last == week[previous]) {
        runs.last.add(day);
      } else {
        runs.add([day]);
      }
    }
    final separator = s.t('، ', ', ');
    return runs
        .map(
          (run) => switch (run.length) {
            1 => dayLabel(run.first, s),
            2 => '${dayLabel(run.first, s)}$separator${dayLabel(run.last, s)}',
            _ => '${dayLabel(run.first, s)}–${dayLabel(run.last, s)}',
          },
        )
        .join(separator);
  }

  /// Reads a stored sentence back into structure, or null when it is not
  /// recognisable. English is tried first: it is the canonical form [format]
  /// writes, so a value this editor wrote round-trips exactly.
  static WorkingHours? parse(L? hours) =>
      _parse(hours?.en) ?? _parse(hours?.ar);

  static WorkingHours? _parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = _normalize(raw);
    final times = RegExp(r'(\d{1,2}):(\d{2})').allMatches(text).toList();
    if (times.length < 2) return null;
    final opens = _time(times[0]);
    final closes = _time(times[1]);
    if (opens == null || closes == null) return null;

    final (open, closed) = _daySets(text);
    // "Fri closed" on its own still says which days are open — every other
    // one. A day named on both sides is closed: the explicit word wins.
    if (open.isEmpty && closed.isEmpty) return null;
    final openDays = open.isNotEmpty ? open : {...week};
    openDays.removeAll(closed);
    if (openDays.isEmpty) return null;
    return WorkingHours(openDays: openDays, opens: opens, closes: closes);
  }

  /// Folds away everything that varies without changing the meaning:
  /// Arabic-Indic digits, the four dashes, the alef and ta-marbuta
  /// spellings, and letter case.
  static String _normalize(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.write(rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.write(rune - 0x06F0);
      } else if ('–—−ـ'.contains(ch)) {
        buffer.write('-');
      } else if ('أإآ'.contains(ch)) {
        buffer.write('ا');
      } else if (ch == 'ة') {
        buffer.write('ه');
      } else {
        buffer.write(ch.toLowerCase());
      }
    }
    return buffer.toString();
  }

  /// Every spelling of a day name that turns up in stored hours, longest
  /// first per language so "saturday" wins over "sat" and "السبت" over "سبت".
  static const _dayPatterns = <int, List<String>>{
    DateTime.saturday: ['saturday', 'sat', 'السبت', 'سبت'],
    DateTime.sunday: ['sunday', 'sun', 'الاحد', 'احد'],
    DateTime.monday: ['monday', 'mon', 'الاثنين', 'اثنين'],
    DateTime.tuesday: ['tuesday', 'tue', 'الثلاثاء', 'ثلاثاء'],
    DateTime.wednesday: ['wednesday', 'wed', 'الاربعاء', 'اربعاء'],
    DateTime.thursday: ['thursday', 'thu', 'الخميس', 'خميس'],
    DateTime.friday: ['friday', 'fri', 'الجمعه', 'جمعه'],
  };

  /// Splits the day names in [text] into the days the workshop is open and
  /// the days it says it is closed.
  ///
  /// Day names group into *phrases* — runs separated by nothing but spaces,
  /// dashes and list separators ("Sat–Thu", "Thu, Fri"). A phrase counts as
  /// closed when "closed"/"مغلق" sits beside it with no time and no other day
  /// name in between. That adjacency, rather than a separator, is what makes
  /// the shape found in the database — "السبت–الخميس ٧:٣٠–١٩:٠٠ الجمعة مغلق",
  /// with nothing at all before "الجمعة" — read correctly.
  static (Set<int>, Set<int>) _daySets(String text) {
    final phrases = _phrases(text);
    final open = <int>{};
    final closed = <int>{};
    for (var i = 0; i < phrases.length; i++) {
      final phrase = phrases[i];
      final from = i == 0 ? 0 : phrases[i - 1].last.$2;
      final to = i + 1 < phrases.length ? phrases[i + 1].first.$1 : text.length;
      // Windows stop at the nearest time: a word on the far side of the
      // opening hours is describing some other phrase, not this one.
      final before = _afterLastDigit(text.substring(from, phrase.first.$1));
      final after = _beforeFirstDigit(text.substring(phrase.last.$2, to));
      final target = _saysClosed(before) || _saysClosed(after) ? closed : open;
      target.addAll(_expand(phrase, text));
    }
    return (open, closed);
  }

  /// Day-name occurrences as `(start, end, day)`, grouped into phrases.
  static List<List<(int, int, int)>> _phrases(String text) {
    final matches = <(int, int, int)>[];
    for (final entry in _dayPatterns.entries) {
      for (final pattern in entry.value) {
        var at = text.indexOf(pattern);
        while (at >= 0) {
          matches.add((at, at + pattern.length, entry.key));
          at = text.indexOf(pattern, at + pattern.length);
        }
      }
    }
    // Earliest first, longest first on a tie, then drop anything overlapping
    // a match already kept — that is what discards the "sat" inside
    // "saturday" and the "سبت" inside "السبت".
    matches.sort((a, b) {
      final byStart = a.$1.compareTo(b.$1);
      return byStart != 0 ? byStart : (b.$2 - b.$1).compareTo(a.$2 - a.$1);
    });
    final phrases = <List<(int, int, int)>>[];
    var end = -1;
    for (final match in matches) {
      if (match.$1 < end) continue;
      final gap = end < 0 ? null : text.substring(end, match.$1);
      if (gap != null && _joinsPhrase(gap)) {
        phrases.last.add(match);
      } else {
        phrases.add([match]);
      }
      end = match.$2;
    }
    return phrases;
  }

  /// Only spaces, dashes and list separators keep two day names in one
  /// phrase — a time or a word between them starts a new one.
  static bool _joinsPhrase(String gap) =>
      gap.length <= 8 && RegExp(r'^[\s\-,،/&+]*$').hasMatch(gap);

  /// A dash between two day names is a range ("Sat–Thu"); anything else is a
  /// list ("Thu, Fri").
  static Set<int> _expand(List<(int, int, int)> phrase, String text) {
    final days = <int>{};
    for (var i = 0; i < phrase.length; i++) {
      days.add(phrase[i].$3);
      if (i + 1 >= phrase.length) continue;
      if (!text.substring(phrase[i].$2, phrase[i + 1].$1).contains('-')) {
        continue;
      }
      days.addAll(_range(phrase[i].$3, phrase[i + 1].$3));
    }
    return days;
  }

  static bool _saysClosed(String window) =>
      window.contains('closed') || window.contains('مغلق');

  static String _afterLastDigit(String value) {
    final index = value.lastIndexOf(RegExp(r'\d'));
    return index < 0 ? value : value.substring(index + 1);
  }

  static String _beforeFirstDigit(String value) {
    final index = value.indexOf(RegExp(r'\d'));
    return index < 0 ? value : value.substring(0, index);
  }

  static Iterable<int> _range(int from, int to) sync* {
    var index = week.indexOf(from);
    final end = week.indexOf(to);
    while (index != end) {
      yield week[index];
      index = (index + 1) % week.length;
    }
    yield week[end];
  }

  static TimeOfDay? _time(RegExpMatch match) {
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  bool operator ==(Object other) =>
      other is WorkingHours &&
      other.opens == opens &&
      other.closes == closes &&
      other.openDays.length == openDays.length &&
      other.openDays.containsAll(openDays);

  @override
  int get hashCode =>
      Object.hash(opens, closes, Object.hashAllUnordered(openDays));

  @override
  String toString() => format().en;
}

/// The working-hours editor: open days as chips, opening and closing time as
/// real time pickers, and a preview of the exact sentence a customer will
/// read in each language.
///
/// [value] is null when nothing recognisable is stored. The field then shows
/// what *is* stored, verbatim, and offers to take it over — replacing text
/// the founder cannot see would be the one behaviour worse than the free-text
/// box this replaced.
class WorkingHoursField extends StatelessWidget {
  const WorkingHoursField({
    super.key,
    required this.value,
    required this.onChanged,
    this.savedText,
  });

  final WorkingHours? value;
  final ValueChanged<WorkingHours> onChanged;

  /// The stored sentence, shown only while [value] is null.
  final String? savedText;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final hours = value;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ak.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clock, size: 15, color: ak.inkSub),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  s.t('ساعات العمل', 'Working hours'),
                  style: context.text.labelStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (hours == null)
            _Unparsed(
              savedText: savedText,
              onTake: () => onChanged(WorkingHours.standard),
            )
          else ...[
            Text(
              s.t('أيام العمل', 'Open days'),
              style: TextStyle(fontSize: 11.5, color: ak.inkSub),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final day in WorkingHours.week)
                  SelectChip(
                    label: WorkingHours.dayLabel(day, s),
                    selected: hours.openDays.contains(day),
                    onTap: () {
                      final days = {...hours.openDays};
                      if (!days.remove(day)) days.add(day);
                      onChanged(hours.copyWith(openDays: days));
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    icon: LucideIcons.sunrise,
                    label: s.t('يفتح', 'Opens'),
                    time: hours.opens,
                    onPicked: (t) => onChanged(hours.copyWith(opens: t)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _TimeTile(
                    icon: LucideIcons.sunset,
                    label: s.t('يغلق', 'Closes'),
                    time: hours.closes,
                    onPicked: (t) => onChanged(hours.copyWith(closes: t)),
                  ),
                ),
              ],
            ),
            if (hours.closesBeforeItOpens) ...[
              const SizedBox(height: AppSpacing.sm),
              _Hint(
                icon: LucideIcons.triangleAlert,
                color: ak.amberText,
                message: s.t(
                  'وقت الإغلاق قبل وقت الفتح — تأكد منه.',
                  'The closing time is before the opening time — check it.',
                ),
              ),
            ],
            if (hours.openDays.isEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _Hint(
                icon: LucideIcons.calendarOff,
                color: ak.dangerText,
                message: s.t(
                  'لا يوجد يوم عمل واحد — ستظهر الورشة مغلقة طوال الأسبوع.',
                  'No open day at all — the workshop reads as closed all week.',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _Preview(hours: hours),
          ],
        ],
      ),
    );
  }
}

/// Stored hours the parser could not read — shown as they are, with the one
/// action that is safe to offer.
class _Unparsed extends StatelessWidget {
  const _Unparsed({required this.savedText, required this.onTake});

  final String? savedText;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final saved = (savedText ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          saved.isEmpty
              ? s.t('لم تُضبط ساعات العمل بعد.', 'No working hours set yet.')
              : s.t(
                  'المحفوظ حالياً نص حر لا يمكن قراءته كأيام وأوقات:',
                  'What is saved is free text that cannot be read as days and '
                      'times:',
                ),
          style: TextStyle(fontSize: 11.5, color: ak.inkSub, height: 1.5),
        ),
        if (saved.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: ak.surfaceDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isolateNumbers(saved, rtl: s.isAr),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: onTake,
            icon: const Icon(LucideIcons.clock4, size: 15),
            label: Text(
              s.t('اضبطها بالمنتقي', 'Set them with the picker'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

/// One tappable time — the whole tile is the target, not a 24px icon.
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.label,
    required this.time,
    required this.onPicked,
  });

  final IconData icon;
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPicked;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          helpText: label,
          // The stored sentence is 24-hour, and so is every workshop sign in
          // Oman — a 12-hour picker would only add a conversion step.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: ak.surfaceDim,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: ak.inkSub),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10.5, color: ak.inkSub),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    WorkingHours.formatTime(time),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 14, color: ak.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Both stored sentences, exactly as they will be saved and read.
class _Preview extends StatelessWidget {
  const _Preview({required this.hours});

  final WorkingHours hours;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final text = hours.format();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('كما سيقرأها العميل', 'What the customer will read'),
            style: TextStyle(fontSize: 10.5, color: ak.inkFaint),
          ),
          const SizedBox(height: 5),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              isolateNumbers(text.ar, rtl: true),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              text.en,
              style: TextStyle(fontSize: 12, color: ak.inkSub),
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-line warning under the pickers.
class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.color, required this.message});

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          message,
          style: TextStyle(fontSize: 11, color: color, height: 1.45),
        ),
      ),
    ],
  );
}
