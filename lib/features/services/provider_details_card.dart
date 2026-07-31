import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/bidi_text.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';

/// The workshop's own record — identity, contact and registration.
///
/// Shared by the parts product page and the service detail page: a buyer
/// deciding whether to hand money to a workshop is asking the same questions
/// either way, and the Oman VAT number in particular must render the same in
/// both places rather than being formatted twice.
class ProviderDetailsCard extends ConsumerWidget {
  const ProviderDetailsCard({
    super.key,
    required this.provider,
    required this.whatsappMessage,
    this.showFulfillments = false,
    this.footer,
  });

  final ServiceProvider provider;

  /// Prefilled WhatsApp text — the caller knows what is being asked about.
  final String whatsappMessage;

  /// Show how the workshop can take the car (visit / pickup / roadside).
  /// Meaningful for a service, not for a part sold over the counter.
  final bool showFulfillments;

  /// Optional action pinned under the contact buttons.
  final Widget? footer;

  void _copy(BuildContext context, String value, String confirmation) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(confirmation)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final locations = ref.watch(locationCatalogProvider);
    final area = locations.localized(provider.area, s.isAr);
    final region = locations.localized(provider.region, s.isAr);

    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(LucideIcons.store,
                  size: 46, radius: 16, foreground: ak.ink),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            provider.name.of(s),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (provider.verified) ...[
                          const SizedBox(width: 5),
                          Icon(LucideIcons.badgeCheck,
                              size: 15, color: ak.success),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isolateNumbers(
                        '$area${s.t('، ', ', ')}$region · '
                        '${provider.distanceKm} ${s.km}',
                        rtl: s.isAr,
                      ),
                      style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showFulfillments && provider.fulfillments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in provider.fulfillments)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ak.surfaceDim,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(f.icon, size: 13, color: ak.inkSub),
                        const SizedBox(width: 5),
                        Text(
                          f == Fulfillment.pickup && provider.pickupFee > 0
                              ? isolateNumbers(
                                  '${f.label(s)} · '
                                  '${provider.pickupFee.toStringAsFixed(0)} '
                                  '${s.omr}',
                                  rtl: s.isAr,
                                )
                              : f.label(s),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _row(
            context,
            ak,
            LucideIcons.clock,
            s.t('ساعات العمل', 'Opening hours'),
            provider.hours?.of(s) ?? s.t('غير محددة', 'Not published'),
          ),
          if (provider.phone case final phone?) ...[
            const SizedBox(height: 9),
            _row(context, ak, LucideIcons.phone, s.t('الهاتف', 'Phone'),
                phone,
                onCopy: () => _copy(
                    context, phone, s.t('تم نسخ الرقم', 'Number copied'))),
          ],
          const SizedBox(height: 9),
          // An Oman VATIN is `OM` + 10 digits and only VAT-registered
          // businesses have one, so the unregistered case says so rather than
          // rendering an empty field.
          if (provider.vatRegistered)
            _row(
              context,
              ak,
              LucideIcons.receiptText,
              s.t('الرقم الضريبي (VAT)', 'VAT number'),
              provider.vatNumber!,
              onCopy: () => _copy(context, provider.vatNumber!,
                  s.t('تم نسخ الرقم الضريبي', 'VAT number copied')),
            )
          else
            _row(
              context,
              ak,
              LucideIcons.receiptText,
              s.t('الرقم الضريبي (VAT)', 'VAT number'),
              s.t('غير مسجّل في ضريبة القيمة المضافة', 'Not VAT registered'),
            ),
          if (provider.crNumber case final cr?) ...[
            const SizedBox(height: 9),
            _row(context, ak, LucideIcons.idCard,
                s.t('السجل التجاري', 'Commercial reg.'), cr),
          ],
          if (provider.vatRegistered) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.fileText, size: 13, color: ak.inkSub),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.t('تصدر هذه الورشة فاتورة ضريبية لكل طلب.',
                        'This workshop issues a VAT invoice with every order.'),
                    style: TextStyle(fontSize: 11, color: ak.inkSub),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              if (provider.phone case final phone?)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: ak.surface,
                    ),
                    onPressed: () => Contact.call(context, phone),
                    icon: const Icon(LucideIcons.phone, size: 15),
                    label: Text(s.t('اتصل', 'Call'),
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
              if (provider.phone != null && provider.whatsapp != null)
                const SizedBox(width: 8),
              if (provider.whatsapp case final whatsapp?)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: const Color(0xFF25A55A),
                    ),
                    onPressed: () => Contact.whatsapp(context, whatsapp,
                        message: whatsappMessage),
                    icon: const Icon(LucideIcons.messageCircle, size: 15),
                    label: Text(s.t('واتساب', 'WhatsApp'),
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AkColors ak,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onCopy,
  }) {
    // Phone numbers, VATINs, CR numbers and opening hours all carry neutral
    // characters (`+`, `–`, `:`) that Arabic's right-to-left order would move
    // to the wrong side of the digits. Only the *rendered* string is isolated;
    // the copy button still puts the raw value on the clipboard.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        Icon(icon, size: 15, color: ak.inkFaint),
        const SizedBox(width: 9),
        Text(label, style: TextStyle(fontSize: 11.5, color: ak.inkSub)),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onCopy,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    isolateNumbers(value, rtl: rtl),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                if (onCopy != null) ...[
                  const SizedBox(width: 5),
                  Icon(LucideIcons.copy, size: 12, color: ak.inkFaint),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width tertiary action used as the card's [ProviderDetailsCard.footer].
class ProviderCardAction extends StatelessWidget {
  const ProviderCardAction({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ak.surfaceDim,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: ak.ink),
        ),
      ),
    );
  }
}
