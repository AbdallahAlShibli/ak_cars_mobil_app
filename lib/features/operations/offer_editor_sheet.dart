import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'admin_form_widgets.dart';

/// Create or edit one [Offer], from the founder panel's Offers tab.
///
/// Pass [existing] to edit. The workshop and the service are fixed on an edit
/// and only choosable on a create: [Offer.referencePrice] is the catalogue's
/// published price for that exact service, so moving an offer onto a different
/// service is not an edit, it is a different offer.
Future<void> showOfferEditorSheet(BuildContext context, {Offer? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OfferEditorSheet(existing: existing),
  );
}

class _OfferEditorSheet extends ConsumerStatefulWidget {
  const _OfferEditorSheet({this.existing});

  final Offer? existing;

  @override
  ConsumerState<_OfferEditorSheet> createState() => _OfferEditorSheetState();
}

class _OfferEditorSheetState extends ConsumerState<_OfferEditorSheet> {
  late String? _workshopId = widget.existing?.workshopId;
  late String? _offeringId = widget.existing?.serviceOfferingId;
  late final _discountedPrice = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.discountedPrice.toString(),
  );
  late DateTime _startsAt = widget.existing?.startsAt ?? DateTime.now();
  late DateTime _endsAt =
      widget.existing?.endsAt ?? DateTime.now().add(const Duration(days: 14));
  late final Set<String> _regions = {...?widget.existing?.regions};
  late bool _activeByFounder = widget.existing?.activeByFounder ?? true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _discountedPrice.dispose();
    super.dispose();
  }

  ServiceOffering? get _offering {
    final offeringId = _offeringId;
    if (offeringId == null) return null;
    return ref
        .read(serviceMarketplaceRepositoryProvider)
        .offeringById(offeringId);
  }

  double? get _discounted => double.tryParse(_discountedPrice.text.trim());

  bool get _ready {
    final offering = _offering;
    final discounted = _discounted;
    return _workshopId != null &&
        offering != null &&
        offering.price != null &&
        discounted != null &&
        discounted > 0 &&
        discounted < offering.price! &&
        _endsAt.isAfter(_startsAt);
  }

  Future<void> _submit() async {
    final s = S.of(context);
    final referencePrice = _offering!.price!;
    final discountedPrice = _discounted!;

    setState(() => _saving = true);
    try {
      final notifier = ref.read(adminOffersProvider.notifier);
      if (widget.existing == null) {
        await notifier.create(
          workshopId: _workshopId!,
          serviceOfferingId: _offeringId!,
          referencePrice: referencePrice,
          discountedPrice: discountedPrice,
          startsAt: _startsAt,
          endsAt: _endsAt,
          regions: _regions,
          activeByFounder: _activeByFounder,
        );
      } else {
        await notifier.edit(
          widget.existing!.id,
          referencePrice: referencePrice,
          discountedPrice: discountedPrice,
          startsAt: _startsAt,
          endsAt: _endsAt,
          regions: _regions,
          activeByFounder: _activeByFounder,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t('تعذّر الحفظ — حاول مرة أخرى.', "Couldn't save — try again."),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startsAt : _endsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startsAt = picked;
        // A start pushed past the end leaves a window that can never open, and
        // the Save button would only go quiet without saying why.
        if (!_endsAt.isAfter(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(days: 14));
        }
      } else {
        _endsAt = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final workshops = marketplace.providers;
    final offeringsForWorkshop = _workshopId == null
        ? const <ServiceOffering>[]
        : marketplace.offerings
              .where((o) => o.provider.id == _workshopId)
              .toList();
    final offering = _offering;
    final published = offering?.price;
    final discounted = _discounted;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: ak.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: ak.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                const _SheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    0,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconTile(
                        _isEdit ? LucideIcons.pencil : LucideIcons.tag,
                        size: 38,
                        radius: 13,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEdit
                                  ? s.t('تعديل العرض', 'Edit offer')
                                  : s.t('عرض جديد', 'New offer'),
                              style: context.text.cardTitle,
                            ),
                            Text(
                              s.t(
                                'خصم محدَّد بمدة على خدمة مسعّرة',
                                'A time-boxed discount on a priced service',
                              ),
                              style: context.text.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),
                        tooltip: s.t('إغلاق', 'Close'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: ak.divider),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenMargin,
                      AppSpacing.lg,
                      AppSpacing.screenMargin,
                      AppSpacing.xl,
                    ),
                    children: [
                      _FieldGroup(
                        label: s.t('على أي خدمة', 'What it applies to'),
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _workshopId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: s.t('الورشة', 'Workshop'),
                              prefixIcon: Icon(
                                LucideIcons.store,
                                size: 16,
                                color: ak.inkSub,
                              ),
                            ),
                            items: [
                              for (final w in workshops)
                                DropdownMenuItem(
                                  value: w.id,
                                  child: Text(
                                    w.name.of(s),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _isEdit
                                ? null
                                : (v) => setState(() {
                                    _workshopId = v;
                                    _offeringId = null;
                                  }),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButtonFormField<String>(
                            initialValue: _offeringId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: s.t('الخدمة', 'Service'),
                              prefixIcon: Icon(
                                LucideIcons.wrench,
                                size: 16,
                                color: ak.inkSub,
                              ),
                            ),
                            items: [
                              for (final o in offeringsForWorkshop)
                                DropdownMenuItem(
                                  value: o.id,
                                  child: Text(
                                    o.name.of(s).replaceAll('\n', ' '),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (_workshopId == null || _isEdit)
                                ? null
                                : (v) => setState(() => _offeringId = v),
                          ),
                          if (_isEdit) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _Hint(
                              s.t(
                                'الورشة والخدمة لا تُغيَّران بعد الإنشاء — '
                                    'العرض على خدمة أخرى هو عرض آخر.',
                                'Workshop and service are fixed after '
                                    'creation — an offer on a different '
                                    'service is a different offer.',
                              ),
                            ),
                          ],
                          if (offering != null && published == null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _Hint(
                              s.t(
                                'هذه الخدمة بعرض سعر بعد الفحص — لا يمكن '
                                    'إنشاء عرض عليها.',
                                'This service is quote-only — an offer needs '
                                    'a published price.',
                              ),
                              danger: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      _FieldGroup(
                        label: s.t('السعر', 'Price'),
                        children: [
                          TextField(
                            controller: _discountedPrice,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: s.t(
                                'السعر بعد الخصم',
                                'Discounted price',
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(14),
                                child: RialGlyph(fontSize: 14, color: ak.ink),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _PricePreview(
                            published: published,
                            discounted: discounted,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      _FieldGroup(
                        label: s.t('المدة', 'Window'),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AdminDatePickerField(
                                  label: s.t('يبدأ', 'Starts'),
                                  date: _startsAt,
                                  onTap: () => _pickDate(start: true),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AdminDatePickerField(
                                  label: s.t('ينتهي', 'Ends'),
                                  date: _endsAt,
                                  onTap: () => _pickDate(start: false),
                                ),
                              ),
                            ],
                          ),
                          if (!_endsAt.isAfter(_startsAt)) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _Hint(
                              s.t(
                                'تاريخ الانتهاء يجب أن يكون بعد البداية.',
                                'The end date must come after the start.',
                              ),
                              danger: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      _FieldGroup(
                        label: s.t('المناطق (اختياري)', 'Regions (optional)'),
                        children: [
                          Text(
                            s.t(
                              'اتركها فارغة ليسري العرض في منطقة الورشة نفسها.',
                              "Leave empty to run it in the workshop's own "
                                  'region.',
                            ),
                            style: context.text.bodySecondary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final region in marketplace.providerRegions)
                                SelectChip(
                                  label: region,
                                  selected: _regions.contains(region),
                                  onTap: () => setState(() {
                                    if (!_regions.add(region)) {
                                      _regions.remove(region);
                                    }
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      // A Material of its own, not an AppCard: a ListTile
                      // paints its ink on the nearest Material ancestor, and
                      // AppCard's coloured DecoratedBox would sit on top of it
                      // — Flutter asserts on exactly this.
                      Material(
                        color: ak.surfaceDim,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              s.t('ظاهر للعملاء', 'Visible to customers'),
                              style: context.text.labelStrong,
                            ),
                            subtitle: Text(
                              s.t(
                                'يظهر في الرئيسية وصفحة الخدمات متى استوفى '
                                    'بقية الشروط.',
                                'Shows on Home and Services once it meets the '
                                    'other conditions.',
                              ),
                              style: context.text.bodySecondary,
                            ),
                            value: _activeByFounder,
                            onChanged: (v) =>
                                setState(() => _activeByFounder = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _ready && !_saving ? _submit : null,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.check, size: 18),
                          label: Text(
                            _isEdit
                                ? s.t('حفظ التعديل', 'Save changes')
                                : s.t('نشر العرض', 'Publish offer'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The grab handle at the top of the sheet — the only affordance saying it can
/// be dragged shut, on a sheet tall enough that the close button leaves thumb
/// reach as soon as the keyboard opens.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: AkColors.of(context).border,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}

/// A labelled group of fields. The editor asks four separate questions — what,
/// how much, for how long, where — and stacking the inputs flat made them read
/// as one undifferentiated form.
class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: context.text.bodySecondary.copyWith(
            color: ak.inkFaint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...children,
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          danger ? LucideIcons.circleAlert : LucideIcons.info,
          size: 13,
          color: danger ? ak.dangerText : ak.inkFaint,
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySecondary.copyWith(
              height: 1.45,
              color: danger ? ak.dangerText : ak.inkSub,
            ),
          ),
        ),
      ],
    );
  }
}

/// What the customer will actually see, computed from the two prices as they
/// are typed.
///
/// The reference price is never typed here — it is the catalogue's published
/// price for the selected service (home-page spec §3, rule 1) — so the only
/// way to know whether a number is a real saving *before* saving it is to show
/// the arithmetic back.
class _PricePreview extends StatelessWidget {
  const _PricePreview({required this.published, required this.discounted});

  final double? published;
  final double? discounted;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final reference = published;

    if (reference == null) {
      return _Hint(
        s.t(
          'اختر خدمة لتظهر هنا مقارنة السعر.',
          'Pick a service to see the price comparison.',
        ),
      );
    }

    final price = discounted;
    final valid = price != null && price > 0 && price < reference;
    final percent = valid ? ((reference - price) / reference * 100).round() : 0;

    return AppCard(
      color: ak.surfaceDim,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('السعر المعلن', 'Published price'),
                  style: context.text.bodySecondary,
                ),
                const SizedBox(height: 2),
                RialAmount(
                  reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelStrong.copyWith(
                    decoration: valid ? TextDecoration.lineThrough : null,
                    color: valid ? ak.inkFaint : ak.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (valid)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('يوفّر على العميل', 'Customer saves'),
                    style: context.text.bodySecondary,
                  ),
                  const SizedBox(height: 2),
                  RialAmount(
                    reference - price,
                    suffix: ' · $percent%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelStrong.copyWith(color: ak.success),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Text(
                s.t(
                  'أدخل سعراً أقل من المعلن.',
                  'Enter a price below the published one.',
                ),
                style: context.text.bodySecondary.copyWith(color: ak.inkFaint),
              ),
            ),
        ],
      ),
    );
  }
}
