import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/oman_plate_input.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'review_widgets.dart';

/// "اطلب قطعة + تركيب" — the custom-quote transaction (spec §6).
///
/// What this screen is *not*: a parts catalogue. There is no product to
/// browse, no stock to check and no compatibility lookup, because the workshop
/// is the compatibility expert — the customer describes the need and the car,
/// and one workshop answers with an itemised price. Everything after that is
/// the ordinary escrow machine.
class PartRequestScreen extends ConsumerStatefulWidget {
  const PartRequestScreen({super.key, this.providerId});

  /// Preselected workshop, when the request was started from a workshop's own
  /// page rather than from the services tab.
  final String? providerId;

  @override
  ConsumerState<PartRequestScreen> createState() => _PartRequestScreenState();
}

class _PartRequestScreenState extends ConsumerState<PartRequestScreen> {
  final _description = TextEditingController();
  final _brand = TextEditingController();
  final _symptom = TextEditingController();
  late final TextEditingController _plateNumber;
  String _plateLetters = 'A';

  String? _providerId;
  Fulfillment _fulfillment = Fulfillment.workshop;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _providerId = widget.providerId;
    final (number, letters) = OmanPlateInput.parse(
      ref.read(primaryCarProvider)?.plate,
    );
    _plateNumber = TextEditingController(text: number);
    // The plate widget owns its own field, so the submit button learns that it
    // was filled in from the controller rather than from an `onChanged`.
    _plateNumber.addListener(_refresh);
    _plateLetters = letters;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _description.dispose();
    _brand.dispose();
    _symptom.dispose();
    _plateNumber.removeListener(_refresh);
    _plateNumber.dispose();
    super.dispose();
  }

  /// Workshops in the selected governorate. Same rule as the services tab: the
  /// list says where it is looking, and never quietly widens.
  List<ServiceProvider> get _providers {
    final region = ref.read(regionProvider);
    final all = ref.read(serviceMarketplaceRepositoryProvider).providers;
    final local = [
      for (final p in all)
        if (p.region == region) p,
    ];
    return local.isEmpty ? all : local;
  }

  ServiceProvider? get _provider {
    for (final p in _providers) {
      if (p.id == _providerId) return p;
    }
    return null;
  }

  bool get _ready =>
      _description.text.trim().isNotEmpty &&
      _provider != null &&
      _plateNumber.text.trim().isNotEmpty;

  Future<void> _pickPlateLetters() async {
    final letters = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => PlateLettersPicker(initial: _plateLetters),
    );
    if (letters != null && letters.isNotEmpty) {
      setState(() => _plateLetters = letters);
    }
  }

  Future<void> _send() async {
    final s = S.of(context);
    final provider = _provider;
    final car = ref.read(primaryCarProvider);
    if (!_ready || provider == null) return;
    if (car == null) {
      // The workshop identifies the part from the car. Without one there is
      // nothing to price, so this is a stop, not a warning.
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.t('أضف سيارتك أولاً — الورشة تحدّد القطعة من موديل سيارتك.',
              'Add your car first — the workshop identifies the part from your model.')),
        ),
      );
      context.push('/add-car');
      return;
    }

    setState(() => _sending = true);
    final plate = '${_plateNumber.text.trim()} $_plateLetters'.toUpperCase();
    final request =
        await ref.read(requestsProvider.notifier).placePartRequest(
              CreatePartRequestDraft(
                providerId: provider.id,
                carId: car.id,
                plate: plate,
                fulfillment: _fulfillment.key,
                part: PartRequest(
                  description: _description.text.trim(),
                  preferredBrand: _brand.text.trim().isEmpty
                      ? null
                      : _brand.text.trim(),
                  symptom: _symptom.text.trim().isEmpty
                      ? null
                      : _symptom.text.trim(),
                ),
              ),
              car: car,
            );
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    context.go('/track/${request.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final car = ref.watch(primaryCarProvider);
    final providers = _providers;

    return Scaffold(
      appBar: AppBar(
          title: Text(s.t('اطلب قطعة + تركيب', 'Request a part + fitting'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            AppCard(
              color: ak.surfaceDim,
              child: Text(
                s.t(
                    'اوصف القطعة أو العطل، وتردّ الورشة بسعر مفصّل: سعر القطعة وسعر التركيب كلٌّ على حدة. لا يُحجز أي مبلغ قبل أن تقبل العرض.',
                    'Describe the part or the fault. The workshop replies with an itemised price — the part and the fitting separately. Nothing is held until you accept.'),
                style: TextStyle(fontSize: 12, height: 1.6, color: ak.inkSub),
              ),
            ),
            const SizedBox(height: 18),

            SectionHeader(s.t('سيارتك', 'Your car')),
            const SizedBox(height: 9),
            AppCard(
              onTap: () => context.push(car == null ? '/add-car' : '/garage'),
              child: Row(
                children: [
                  IconTile(car == null
                      ? LucideIcons.plus
                      : LucideIcons.car),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      car?.label ??
                          s.t('أضف سيارتك — الورشة تحدّد القطعة من الموديل',
                              'Add your car — the workshop identifies the part from the model'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, color: ak.inkFaint),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OmanPlateInput(
              numberController: _plateNumber,
              letters: _plateLetters,
              onLettersTap: _pickPlateLetters,
            ),
            const SizedBox(height: 20),

            SectionHeader(s.t('ما الذي تحتاجه؟', 'What do you need?')),
            const SizedBox(height: 9),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: s.t('مثال: طقم فحمات فرامل أمامية + التركيب',
                    'e.g. front brake pads set + fitting'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _brand,
              decoration: InputDecoration(
                labelText:
                    s.t('ماركة أو أصالة تفضّلها (اختياري)',
                        'Preferred brand or origin (optional)'),
                hintText: s.t('أصلي / تجاري / ماركة بعينها',
                    'Genuine / aftermarket / a specific brand'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _symptom,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: s.t('ما الذي تلاحظه في السيارة؟ (اختياري)',
                    'What is the car doing? (optional)'),
                hintText: s.t('صوت، اهتزاز، لمبة تحذير…',
                    'A noise, a vibration, a warning light…'),
              ),
            ),
            const SizedBox(height: 20),

            SectionHeader(s.t('أي ورشة تسعّرها؟', 'Which workshop prices it?')),
            const SizedBox(height: 4),
            Text(
              s.t('الورشة هي من تحدّد القطعة المناسبة لسيارتك.',
                  'The workshop is the one that identifies the right part for your car.'),
              style: TextStyle(fontSize: 11.5, color: ak.inkSub),
            ),
            const SizedBox(height: 10),
            for (final p in providers) ...[
              _WorkshopOption(
                provider: p,
                selected: p.id == _providerId,
                onTap: () => setState(() => _providerId = p.id),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 10),

            SectionHeader(s.t('كيف تصل السيارة؟', 'How does the car get there?')),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final f in (_provider?.fulfillments.toList() ??
                    Fulfillment.values))
                  SelectChip(
                    label: f.label(s),
                    icon: f.icon,
                    selected: _fulfillment == f,
                    onTap: () => setState(() => _fulfillment = f),
                  ),
              ],
            ),
            const SizedBox(height: 22),

            FilledButton(
              onPressed: _ready && !_sending ? _send : null,
              child: Text(_sending
                  ? s.t('جارٍ الإرسال…', 'Sending…')
                  : s.t('أرسل الطلب للتسعير', 'Send for a quote')),
            ),
            const SizedBox(height: 8),
            Text(
              s.t('إرسال الطلب لا يُلزمك بشيء — تقرّر بعد أن ترى السعر.',
                  'Sending costs you nothing — you decide once you see the price.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: ak.inkSub),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable workshop. Shows the rating only where one exists — a
/// workshop nobody has reviewed shows no stars rather than a default score.
class _WorkshopOption extends ConsumerWidget {
  const _WorkshopOption({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final ServiceProvider provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final locations = ref.watch(locationCatalogProvider);

    return AppCard(
      onTap: onTap,
      border: selected ? Border.all(color: ak.primary, width: 1.6) : null,
      child: Row(
        children: [
          IconTile(
            selected
                ? LucideIcons.circleCheckBig
                : LucideIcons.store,
            background: selected ? ak.successSoft : null,
            foreground: selected ? ak.success : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider.name.of(s),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${locations.localized(provider.area, s.isAr)} · ${provider.distanceKm.toStringAsFixed(1)} ${s.km}',
                  style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                ),
                const SizedBox(height: 5),
                RatingSummaryLine(providerId: provider.id),
              ],
            ),
          ),
          if (provider.verified)
            Icon(LucideIcons.badgeCheck, size: 17, color: ak.primary),
        ],
      ),
    );
  }
}
