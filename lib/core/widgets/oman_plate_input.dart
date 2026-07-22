import 'package:flutter/material.dart';
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
                    const Icon(Icons.arrow_drop_down_rounded,
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

/// Plate letters picker — one or two letters, order preserved.
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

  void _toggle(String letter) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_picked.contains(letter)) {
        _picked.remove(letter);
      } else {
        if (_picked.length == 2) _picked.removeAt(0);
        _picked.add(letter);
      }
    });
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
              s.t('اختر حرفاً أو حرفين — الترتيب مهم.',
                  'Pick one or two letters — order matters.'),
              style: TextStyle(fontSize: 12, color: ak.inkSub),
            ),
            const SizedBox(height: 14),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  _picked.isEmpty ? '—' : _picked.join(),
                  key: ValueKey(_picked.join()),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: ak.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in plateLetters)
                  GestureDetector(
                    onTap: () => _toggle(l),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color:
                            _picked.contains(l) ? ak.primary : ak.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                _picked.contains(l) ? ak.primary : ak.border),
                      ),
                      child: Center(
                        child: Text(
                          l,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color:
                                _picked.contains(l) ? ak.onPrimary : ak.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
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
