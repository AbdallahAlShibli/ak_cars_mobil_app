import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/oman_plate_input.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/car_catalog.dart';
import '../../data/models.dart';
import '../../data/oman_locations.dart';

/// Add-car — everything on ONE page. Each detail opens a popup picker:
/// make (logo grid), model, year range (validated From ≤ To), plate with
/// 1–2 letters, and governorate → wilayat cascading selection.
class AddCarScreen extends ConsumerStatefulWidget {
  const AddCarScreen({super.key});

  @override
  ConsumerState<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends ConsumerState<AddCarScreen> {
  CarMake? _make;
  String? _model;
  int? _year;
  String? _governorate;
  String? _wilayat;

  final _plateNumber = TextEditingController();
  String _plateLetters = 'A';

  @override
  void dispose() {
    _plateNumber.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _make != null &&
      _model != null &&
      _year != null &&
      _governorate != null &&
      _wilayat != null;

  void _save() {
    if (!_canSave) return;
    final plate = _plateNumber.text.trim().isEmpty
        ? null
        : '${_plateNumber.text.trim()} $_plateLetters';
    ref.read(garageProvider.notifier).add(Car(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          make: _make!.name,
          model: _model!,
          year: _year!,
          plate: plate,
          serviceDueKm: 800,
        ));
    ref.read(regionProvider.notifier).state = _governorate!;
    ref.read(authProvider.notifier).markStartChoiceMade();
    HapticFeedback.heavyImpact();
    final messenger = ScaffoldMessenger.of(context);
    final label = '${_make!.name} $_model';
    context.go('/home');
    messenger.showSnackBar(
      SnackBar(content: Text('$label added to your garage')),
    );
  }

  /// -------------------------------------------------------------- popups

  Future<void> _pickMake() async {
    final make = await _showPopup<CarMake>(
      title: 'Pick a make',
      builder: (context, query) {
        final makes = CarCatalog.makes
            .where((m) => m.name.toLowerCase().contains(query))
            .toList();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 0.86,
          ),
          itemCount: makes.length,
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => Navigator.pop(context, makes[i]),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _make == makes[i]
                      ? AppColors.brand
                      : AppColors.border,
                  width: _make == makes[i] ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MakeLogo(make: makes[i], size: 36),
                  const SizedBox(height: 6),
                  Text(
                    makes[i].name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      searchable: true,
    );
    if (make != null) {
      setState(() {
        _make = make;
        _model = null;
      });
    }
  }

  Future<void> _pickModel() async {
    if (_make == null) return;
    final model = await _showPopup<String>(
      title: 'Choose model — ${_make!.name}',
      searchable: true,
      builder: (context, query) {
        final models = _make!.models
            .where((m) => m.toLowerCase().contains(query))
            .toList();
        return _OptionList(
          options: models,
          selected: _model,
          icon: Icons.directions_car_outlined,
        );
      },
    );
    if (model != null) setState(() => _model = model);
  }

  Future<void> _pickYear() async {
    final year = await _showPopup<int>(
      title: 'Made year',
      builder: (context, _) => _OptionList(
        options: [for (final y in CarCatalog.years) '$y'],
        selected: '${_year ?? ''}',
        icon: Icons.calendar_today_outlined,
        onPick: (v) => Navigator.pop(context, int.parse(v)),
      ),
    );
    if (year != null) setState(() => _year = year);
  }

  Future<void> _pickGovernorate() async {
    final gov = await _showPopup<String>(
      title: 'Governorate',
      searchable: true,
      builder: (context, query) => _OptionList(
        options: OmanLocations.governorates.keys
            .where((g) => g.toLowerCase().contains(query))
            .toList(),
        selected: _governorate,
        icon: Icons.map_outlined,
      ),
    );
    if (gov != null) {
      setState(() {
        _governorate = gov;
        _wilayat = null; // cascade reset
      });
    }
  }

  Future<void> _pickWilayat() async {
    if (_governorate == null) return;
    final wilayat = await _showPopup<String>(
      title: 'Wilayat — $_governorate',
      searchable: true,
      builder: (context, query) => _OptionList(
        options: OmanLocations.wilayatsOf(_governorate!)
            .where((w) => w.toLowerCase().contains(query))
            .toList(),
        selected: _wilayat,
        icon: Icons.location_on_outlined,
      ),
    );
    if (wilayat != null) setState(() => _wilayat = wilayat);
  }

  Future<void> _pickPlateLetters() async {
    final letters = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => PlateLettersPicker(initial: _plateLetters),
    );
    if (letters != null && letters.isNotEmpty) {
      setState(() => _plateLetters = letters);
    }
  }

  Future<T?> _showPopup<T>({
    required String title,
    required Widget Function(BuildContext context, String query) builder,
    bool searchable = false,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PopupScaffold(
        title: title,
        searchable: searchable,
        builder: builder,
      ),
    );
  }

  /// --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add your car')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  const Text(
                    'Tap each field to choose from the list.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.ink2),
                  ),
                  const SizedBox(height: 14),
                  _PickerField(
                    icon: Icons.factory_outlined,
                    label: 'Make',
                    value: _make?.name,
                    onTap: _pickMake,
                  ),
                  _PickerField(
                    icon: Icons.directions_car_outlined,
                    label: 'Model',
                    value: _model,
                    hint: _make == null ? 'Select make first' : null,
                    enabled: _make != null,
                    onTap: _pickModel,
                  ),
                  // Live preview — the car photo changes with the
                  // selected make & model.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: (_make != null && _model != null)
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Column(
                                children: [
                                  CarImage(
                                      make: _make!.name,
                                      model: _model!,
                                      height: 110),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_make!.name} $_model',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink2),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  _PickerField(
                    icon: Icons.calendar_today_outlined,
                    label: 'Made year',
                    value: _year == null ? null : '$_year',
                    onTap: _pickYear,
                  ),
                  _PickerField(
                    icon: Icons.map_outlined,
                    label: 'Governorate',
                    value: _governorate,
                    onTap: _pickGovernorate,
                  ),
                  _PickerField(
                    icon: Icons.location_on_outlined,
                    label: 'Wilayat',
                    value: _wilayat,
                    hint: _governorate == null
                        ? 'Select governorate first'
                        : null,
                    enabled: _governorate != null,
                    onTap: _pickWilayat,
                  ),
                  const SizedBox(height: 10),
                  const Text('Oman plate number',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Optional now — required when booking a service. Letters can be one or two.',
                    style:
                        TextStyle(fontSize: 11.5, color: AppColors.ink3),
                  ),
                  const SizedBox(height: 10),
                  OmanPlateInput(
                    numberController: _plateNumber,
                    letters: _plateLetters,
                    onLettersTap: _pickPlateLetters,
                  ),
                  if (_canSave) ...[
                    const SizedBox(height: 16),
                    Entrance(
                      child: AppCard(
                        color: AppColors.goodSoft,
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.good, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_make!.name} $_model · $_year · $_wilayat, $_governorate',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF046C4E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(_canSave
                    ? 'Save ${_make!.name} $_model'
                    : 'Complete the details above'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable field row that opens a popup picker.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.hint,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? hint;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled ? AppColors.brand : AppColors.border,
                width: filled ? 1.5 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: filled ? AppColors.brand : AppColors.ink3),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: filled ? 10.5 : 13,
                          color: AppColors.ink3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (filled)
                        Text(
                          value!,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700),
                        )
                      else if (hint != null)
                        Text(
                          hint!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.ink3),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more_rounded,
                    color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet scaffold for popup pickers (title + optional search).
class _PopupScaffold extends StatefulWidget {
  const _PopupScaffold({
    required this.title,
    required this.builder,
    required this.searchable,
  });

  final String title;
  final Widget Function(BuildContext context, String query) builder;
  final bool searchable;

  @override
  State<_PopupScaffold> createState() => _PopupScaffoldState();
}

class _PopupScaffoldState extends State<_PopupScaffold> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (widget.searchable) ...[
                TextField(
                  autofocus: false,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: widget.builder(context, _query),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple option list used inside popups; pops the tapped value.
class _OptionList extends StatelessWidget {
  const _OptionList({
    required this.options,
    required this.icon,
    this.selected,
    this.onPick,
  });

  final List<String> options;
  final IconData icon;
  final String? selected;
  final void Function(String value)? onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (onPick != null) {
                  onPick!(o);
                } else {
                  Navigator.pop(context, o);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: selected == o
                        ? AppColors.brand
                        : AppColors.border,
                    width: selected == o ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 17,
                        color: selected == o
                            ? AppColors.brand
                            : AppColors.ink3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(o,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (selected == o)
                      const Icon(Icons.check_rounded,
                          size: 18, color: AppColors.brand),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
