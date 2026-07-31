import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/oman_plate_input.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/service_marketplace_repository.dart';
import '../../data/services/service_marketplace_service.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import 'service_detail_screen.dart';

/// Time & place:
/// - fulfillment options come from real provider capacity;
/// - emergency services default to roadside and skip time slots (ASAP);
/// - the plate uses the same Oman plate widget as car registration,
///   prefilled from the garage and saved back to the car.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.offeringId});

  final String offeringId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late Fulfillment _fulfillment;
  late String _slot;
  late final TextEditingController _plateNumber;
  String _plateLetters = 'A';
  bool _confirming = false;

  ServiceMarketplaceRepository get _marketplace =>
      ref.read(serviceMarketplaceRepositoryProvider);

  /// The offering at the price the customer will actually be charged — a live
  /// offer's discount is already applied. Everything downstream (the total,
  /// the draft, the escrow amount, the receipt) reads this one value, which is
  /// why a discount cannot be advertised on the home page and then quietly
  /// dropped at confirmation.
  ServiceOffering get _offering =>
      _marketplace.pricedOffering(widget.offeringId)!;

  BookingAvailability get _availability =>
      _marketplace.availabilityFor(_offering.provider.id);

  bool get _isEmergency => _offering.categoryId == 'sos';

  bool get _needsSlot => _fulfillment != Fulfillment.roadside;

  @override
  void initState() {
    super.initState();
    // The first slot the provider can actually take. Preselecting
    // `slots.first` would offer a slot the chip itself renders as "full" and
    // refuses to tap — and would still book it, since the confirm button never
    // looks at availability.
    _slot = _availability.slots.firstWhereOrNull(_availability.isAvailable) ?? '';
    final car = ref.read(primaryCarProvider);
    // Same plate as registered with the car — prefilled and editable.
    final (number, letters) = OmanPlateInput.parse(car?.plate);
    _plateNumber = TextEditingController(text: number);
    _plateLetters = letters;

    // Emergency services go roadside by default; otherwise workshop,
    // falling back to whatever the provider actually offers.
    final offered = _offering.provider.fulfillments;
    if (_isEmergency && offered.contains(Fulfillment.roadside)) {
      _fulfillment = Fulfillment.roadside;
    } else if (offered.contains(Fulfillment.workshop)) {
      _fulfillment = Fulfillment.workshop;
    } else {
      // A provider that lists no fulfillment at all is bad data, not a reason
      // to crash the screen on open.
      _fulfillment = offered.firstOrNull ?? Fulfillment.workshop;
    }
  }

  @override
  void dispose() {
    _plateNumber.dispose();
    super.dispose();
  }

  /// Running total, computed with the same rule the repository prices the
  /// request with, so what the button says is what gets charged.
  double get _total {
    final selected = ref.read(selectedAddOnsProvider);
    return calculateRequestTotal(
      offering: _offering,
      addOns: _marketplace
          .addOnsFor(_offering.provider.id)
          .where((a) => selected.contains(a.id)),
      fulfillment: _fulfillment,
    );
  }

  String _slotLabel(S s) {
    if (!_needsSlot) {
      return s.t('في أقرب وقت · المزود في طريقه إليك',
          'ASAP · provider heads to you');
    }
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final date =
        DateFormat('EEE d MMM', s.isAr ? 'ar' : 'en').format(tomorrow);
    return '$date · $_slot';
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

  Future<void> _confirm() async {
    final s = S.of(context);
    // Rule 8: plate number is mandatory on every service request.
    if (_plateNumber.text.trim().isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(s.t('أدخل رقم لوحة السيارة للمتابعة',
                'Enter the car plate number to continue'))),
      );
      return;
    }
    // A workshop or pickup booking needs a time the provider can take. There
    // is none left to pick when every slot is already full.
    if (_needsSlot && _slot.isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(s.t('لا توجد مواعيد متاحة لدى هذا المزود',
                'This provider has no available slots'))),
      );
      return;
    }
    setState(() => _confirming = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final car = ref.read(primaryCarProvider) ??
        const Car(id: 'adhoc', make: 'Selected', model: 'car', year: 2020);
    final plate =
        '${_plateNumber.text.trim()} $_plateLetters'.toUpperCase();

    // Resolved before the await: leaving this screen mid-booking disposes the
    // widget, and `ref` cannot be read after that — but the booking has already
    // been placed by then, so the garage sync and the add-on reset still have
    // to happen.
    final requests = ref.read(requestsProvider.notifier);
    final garage = ref.read(garageProvider.notifier);
    final selectedAddOns = ref.read(selectedAddOnsProvider.notifier);
    final intent = ref.read(maintenanceBookingIntentProvider.notifier);

    // Set when this booking was started from a maintenance item. It only ever
    // applies to the car it was raised for — switching the default car between
    // tapping the reminder and confirming must not file the service against
    // the wrong vehicle.
    final maintenanceItemKey =
        intent.state?.carId == car.id ? intent.state?.itemKey : null;

    // The repository prices and stores the booking and raises the
    // "request sent" notification — nothing is held in escrow until the
    // founder confirms the transfer landed (spec §3, note 2).
    final request = await requests.place(
      CreateServiceRequestDraft(
        offering: _offering,
        car: car,
        plate: plate,
        fulfillment: _fulfillment,
        slot: _slotLabel(s),
        addOnIds: selectedAddOns.state,
        maintenanceItemKey: maintenanceItemKey,
      ),
    );

    // Keep the garage in sync — the plate entered here becomes the
    // car's registered plate.
    if (car.id != 'adhoc' && car.plate != plate) {
      garage.setPlate(car.id, plate);
    }
    selectedAddOns.state = {};
    // Consumed: the next booking is a fresh one unless the owner starts it
    // from a reminder again.
    intent.state = null;
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    context.go('/track/${request.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = _offering.provider;
    final car = ref.watch(primaryCarProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('الوقت والمكان', 'Time & place'))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  if (_isEmergency) ...[
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.badSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.triangleAlert,
                              color: AppColors.bad, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.t('طلب طارئ — سيتوجه المزود إلى موقعك فور قبول الطلب.',
                                  'Emergency request — the provider is dispatched to your location as soon as they accept.'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF991B1B),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final f in Fulfillment.values) ...[
                    _FulfillmentCard(
                      fulfillment: f,
                      offered: provider.fulfillments.contains(f),
                      selected: _fulfillment == f,
                      fee: f == Fulfillment.pickup ? provider.pickupFee : null,
                      onTap: () => setState(() => _fulfillment = f),
                    ),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 6),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _needsSlot
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s.t('غداً', 'Tomorrow')} · ${DateFormat('EEE d MMM', s.isAr ? 'ar' : 'en').format(DateTime.now().add(const Duration(days: 1)))}',
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final s in _availability.slots)
                                    _SlotChip(
                                      label: s,
                                      booked:
                                          !_availability.isAvailable(s),
                                      selected: _slot == s,
                                      onTap: () =>
                                          setState(() => _slot = s),
                                    ),
                                ],
                              ),
                            ],
                          )
                        : Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.zap,
                                    color: AppColors.brand, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s.t('لا حاجة لحجز موعد — متوسط زمن الاستجابة 25 دقيقة.',
                                        'No booking slot needed — average response time is 25 minutes.'),
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(s.t('لوحة السيارة', 'Car plate'),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      if (car?.plate != null)
                        StatusBadge.good(
                            s.t('من مرآبك', 'From your garage'))
                      else
                        StatusBadge.warn(s.t('مطلوبة', 'Required')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    car != null
                        ? s.t('مسجلة لسيارتك ${car.label} — وسيتم تحديث مرآبك أيضاً.',
                            'Registered to your ${car.label} — it updates your garage too.')
                        : s.t('أدخل لوحة السيارة الخاصة بهذا الطلب.',
                            'Enter the plate of the car for this request.'),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.ink3),
                  ),
                  const SizedBox(height: 10),
                  OmanPlateInput(
                    numberController: _plateNumber,
                    letters: _plateLetters,
                    onLettersTap: _pickPlateLetters,
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      children: [
                        // Says out loud which schedule line this booking will
                        // update, and on which car — and only when the owner
                        // actually started from that reminder.
                        if (ref.watch(maintenanceBookingIntentProvider)
                            case final intent?
                            when intent.carId == car?.id) ...[
                          _SummaryRow(
                            label: s.t('لصيانة', 'For maintenance'),
                            value: intent.title.of(s),
                          ),
                          const SizedBox(height: 6),
                        ],
                        _SummaryRow(
                          label: _offering.name.of(s),
                          value: _offering.price != null
                              ? '${s.omr} ${_offering.price!.toStringAsFixed(2)}'
                              : s.t('عرض سعر بعد الفحص',
                                  'Quote after inspection'),
                        ),
                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: s.t('طريقة التنفيذ', 'Fulfillment'),
                          value: switch (_fulfillment) {
                            Fulfillment.pickup =>
                              '${_fulfillment.label(s)} · +${s.omr} ${provider.pickupFee.toStringAsFixed(0)}',
                            Fulfillment.roadside =>
                              '${_fulfillment.label(s)} · ${s.t('في أقرب وقت', 'ASAP')}',
                            _ =>
                              '${_fulfillment.label(s)} · ${s.t('مجاناً', 'free')}',
                          },
                        ),
                        const SizedBox(height: 6),
                        _SummaryRow(
                            label: s.t('الموعد', 'When'),
                            value: _slotLabel(s)),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.t('الإجمالي', 'Total'),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              '${s.omr} ${_total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        EscrowBanner(
                          s.t('محفوظ بأمان — يُحرَّر فقط بعد موافقتك على العمل المنجز.',
                              'Held safely — released only after you approve the finished work.'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                style: _isEmergency
                    ? FilledButton.styleFrom(backgroundColor: AppColors.bad)
                    : null,
                onPressed: _confirming ? null : _confirm,
                child: _confirming
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_isEmergency
                        ? s.t('اطلب المساعدة الآن — ${_total.toStringAsFixed(2)} ر.ع',
                            'Request help now — OMR ${_total.toStringAsFixed(2)}')
                        : s.t('تأكيد ودفع ${_total.toStringAsFixed(2)} ر.ع',
                            'Confirm & pay OMR ${_total.toStringAsFixed(2)}')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FulfillmentCard extends StatelessWidget {
  const _FulfillmentCard({
    required this.fulfillment,
    required this.offered,
    required this.selected,
    required this.onTap,
    this.fee,
  });

  final Fulfillment fulfillment;
  final bool offered;
  final bool selected;
  final VoidCallback onTap;
  final double? fee;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final subtitle = switch (fulfillment) {
      _ when !offered =>
        s.t('غير متوفرة لدى هذا المزود', 'Not offered by this provider'),
      Fulfillment.workshop =>
        s.t('مجاناً · اختر موعداً بالأسفل', 'Free · pick a slot below'),
      Fulfillment.pickup => s.t(
          '+ ${fee?.toStringAsFixed(0)} ر.ع · متوفرة لدى هذا المزود',
          '+ OMR ${fee?.toStringAsFixed(0)} · offered by this provider'),
      Fulfillment.roadside => s.t(
          'في أقرب وقت · متوسط الاستجابة 25 دقيقة',
          'ASAP · avg 25 min response'),
    };

    return Opacity(
      opacity: offered ? 1 : 0.45,
      child: AppCard(
        onTap: offered ? onTap : null,
        border: Border.all(
          color: selected && offered ? AppColors.brand : Colors.transparent,
          width: 2.5,
        ),
        child: Row(
          children: [
            IconTile(
              fulfillment.icon,
              background: selected && offered
                  ? AppColors.brandSoft
                  : AppColors.field,
              foreground: selected && offered
                  ? AppColors.brand
                  : AppColors.ink2,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fulfillment.label(s),
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.ink3)),
                ],
              ),
            ),
            if (offered)
              Icon(
                selected
                    ? LucideIcons.circleCheckBig
                    : LucideIcons.circle,
                color: selected
                    ? AppColors.brand
                    : const Color(0xFFD8D1C4),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.booked,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool booked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: booked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient:
              !booked && selected ? AppColors.brandGradient : null,
          color: booked
              ? AppColors.field
              : selected
                  ? null
                  : AppColors.card,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          booked
              ? '$label · ${S.of(context).t('محجوز', 'full')}'
              : label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: booked
                ? const Color(0xFFC3CBD8)
                : selected
                    ? Colors.white
                    : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
