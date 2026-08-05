import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// What stands in the place of a phone number before a booking is protected.
///
/// Not a blocked-off gap and not a telling-off: it says *why* the number is not
/// there yet — off-platform work carries no guarantee — and hands over the
/// channel that does work today, the in-app thread. See
/// `core/utils/provider_contact.dart` for the rule itself.
class ContactLockedCard extends StatelessWidget {
  const ContactLockedCard({super.key, this.onMessageProvider});

  /// Opens the thread with this workshop. Null where no thread exists to open,
  /// in which case the card explains and offers nothing it cannot do.
  final VoidCallback? onMessageProvider;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.messagesSquare, size: 17, color: ak.inkSub),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('التواصل المباشر يُفتح بعد تأكيد الحجز',
                          'Direct contact opens once the booking is confirmed'),
                      style: context.text.labelStrong.copyWith(color: ak.ink),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      s.t(
                          'حتى ذلك الحين راسل الورشة داخل التطبيق — ما يُتفق '
                              'عليه خارج المنصة لا يغطّيه الضمان.',
                          'Until then, message the workshop in the app — '
                              'anything agreed outside it is not covered by '
                              'the guarantee.'),
                      style: context.text.bodySecondary.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onMessageProvider != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: ak.surface,
              ),
              onPressed: onMessageProvider,
              icon: const Icon(LucideIcons.messageCircle, size: 15),
              label: Text(s.t('راسل الورشة', 'Message the workshop')),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the customer gets by booking here rather than agreeing something on
/// the phone — every line a thing this app actually does.
///
/// Positive framing on purpose: "why book through the app", never "do not deal
/// outside it". The negative version puts an idea in the reader's head that was
/// not there, and makes the platform sound wary of its own users.
///
/// Visually quiet — a dim surface with no filled colour — because the confirm
/// button underneath it is the primary action on the screen and this must not
/// compete with it.
class BookingValueCard extends StatelessWidget {
  const BookingValueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    final points = <(IconData, String)>[
      (
        LucideIcons.lock,
        s.t('مبلغك محجوز حتى ترضى عن العمل',
            'Your money is held until you are happy with the work')
      ),
      (
        LucideIcons.camera,
        s.t('إثبات مصوّر لكل خدمة تُنفَّذ',
            'Photo proof of every service carried out')
      ),
      (
        LucideIcons.fileText,
        s.t('يُسجَّل تلقائياً في سجل صيانة سيارتك',
            "Logged automatically in your car's service history")
      ),
      (
        LucideIcons.star,
        s.t('تقييمك موثّق ويساعد غيرك',
            'Your review is verified and helps the next owner')
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('لماذا تحجز عبر التطبيق؟', 'Why book through the app?'),
            style: context.text.labelStrong.copyWith(color: ak.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (icon, text) in points) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 14, color: ak.inkFaint),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      text,
                      style: context.text.bodySecondary.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
