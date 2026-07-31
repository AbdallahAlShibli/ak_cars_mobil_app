import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/catalog_state.dart';
import '../i18n/strings.dart';
import '../theme/app_colors.dart';

/// Yellow Omani private plate: [ number | letter(s) | عُمان ].
/// Shared by car registration and service booking so the plate is
/// entered the same way everywhere.
class OmanPlateInput extends StatelessWidget {
  const OmanPlateInput({
    super.key,
    required this.numberController,
    required this.letters,
    required this.onLettersTap,
  });

  final TextEditingController numberController;
  final String letters;
  final VoidCallback onLettersTap;

  static const plateYellow = Color(0xFFFFC72C);
  static const plateInk = Color(0xFF1A1A1A);

  /// Parses a stored plate like "12345 AB" into (number, letters).
  static (String, String) parse(String? plate) {
    if (plate == null || plate.trim().isEmpty) return ('', 'A');
    final parts = plate.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return (parts.first, parts.last.toUpperCase());
    final digits = plate.replaceAll(RegExp(r'[^0-9]'), '');
    final alpha = plate.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    return (digits, alpha.isEmpty ? 'A' : alpha);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: plateYellow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: plateInk, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              maxLength: 5,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: plateInk,
                letterSpacing: 4,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: '12345',
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0x552A2A2A),
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          Container(width: 3, color: plateInk),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onLettersTap();
              },
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      letters,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: plateInk,
                        letterSpacing: 2,
                      ),
                    ),
                    const Icon(LucideIcons.chevronDown,
                        color: plateInk),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 3, color: plateInk),
          const Expanded(
            flex: 3,
            child: Center(
              child: Text(
                'عُمان',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: plateInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plate letters picker — one or two letters, order preserved, **repeats
/// allowed** (`AA`, `BB`, … are real Omani plates).
///
/// Tapping a letter appends it rather than toggling it, which is what makes a
/// repeat possible; a full pair slides along (first letter drops off) and the
/// backspace button undoes the last tap.
/// Use with `showModalBottomSheet<String>`.
class PlateLettersPicker extends ConsumerStatefulWidget {
  const PlateLettersPicker({super.key, required this.initial});

  final String initial;

  @override
  ConsumerState<PlateLettersPicker> createState() =>
      _PlateLettersPickerState();
}

class _PlateLettersPickerState extends ConsumerState<PlateLettersPicker> {
  late final List<String> _picked = widget.initial.split('');

  /// Appends a letter — the same letter twice is a valid plate, so this must
  /// not toggle. Once two are picked the pair slides: the oldest drops off.
  void _pick(String letter) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_picked.length == 2) _picked.removeAt(0);
      _picked.add(letter);
    });
  }

  /// Undoes the last tap — the only way to unpick a letter now that tapping
  /// one adds it.
  void _undo() {
    if (_picked.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _picked.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final plateLetters = ref.watch(vehicleCatalogProvider).plateLetters;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('حروف اللوحة', 'Plate letters'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              s.t('اختر حرفاً أو حرفين — الترتيب مهم، ويمكن تكرار نفس الحرف (مثل AA).',
                  'Pick one or two letters — order matters, and the same '
                      'letter can repeat (e.g. AA).'),
              style: TextStyle(fontSize: 12, color: ak.inkSub),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      _picked.isEmpty ? '—' : _picked.join(),
                      key: ValueKey(_picked.join()),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: ak.ink,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: IconButton(
                    onPressed: _picked.isEmpty ? null : _undo,
                    icon: const Icon(LucideIcons.delete, size: 20),
                    color: ak.inkSub,
                    tooltip: s.t('حذف آخر حرف', 'Delete last letter'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in plateLetters)
                  Builder(builder: (context) {
                    // How many times this letter is in the pair — 2 means the
                    // plate repeats it, which the badge has to make obvious.
                    final used = _picked.where((p) => p == l).length;
                    return GestureDetector(
                      onTap: () => _pick(l),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: used > 0 ? ak.primary : ak.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: used > 0 ? ak.primary : ak.border),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                l,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: used > 0 ? ak.onPrimary : ak.ink,
                                ),
                              ),
                            ),
                            if (used == 2)
                              PositionedDirectional(
                                top: 3,
                                end: 4,
                                child: Text(
                                  '×2',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: ak.onPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, _picked.join()),
              child: Text(_picked.isEmpty
                  ? s.t('اختر حرفاً واحداً على الأقل', 'Pick at least one letter')
                  : s.t('استخدم "${_picked.join()}"', 'Use "${_picked.join()}"')),
            ),
          ],
        ),
      ),
    );
  }
}
