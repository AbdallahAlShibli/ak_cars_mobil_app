import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';

// What AK Cars tells a brand-new user it does — in one place, derived from
// the flags that decide what this build actually ships.
//
// **The bug this file exists to fix, not a defence against one that might
// happen:** the first-launch tour's second slide sold the parts store
// ("shop parts … with filters for category, provider, price and region")
// while [AppFlags.partsStoreEnabled] has been `false` since the phase-1
// refocus. The Shop tab, its routes and every entry point into it are
// compiled out of the build — so the second thing the app ever said to a new
// user was a feature they could not then find. Copy that names a pillar now
// has to be *built from the same switch that decides whether the pillar is
// reachable*, which is what [introSlides] and [capabilityHighlights] do.
//
// Everything listed below without a flag guard is a phase-1 capability that
// exists end to end: verified providers and booking (`features/services`),
// itemised quotes (`features/services/quote_screen.dart`), the escrow state
// machine (`data/models/escrow.dart`), live tracking with completion proof
// (`features/services/tracking_screen.dart`), and the garage with
// mileage-based reminders (`features/garage`).

/// One tour slide: a claim, the sentence that explains it, and the short
/// chips that make the claim concrete.
class IntroSlide {
  const IntroSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.chips,
  });

  final IconData icon;
  final L title;
  final L body;

  /// Two or three words each. These are the proof, not decoration: a slide
  /// that cannot name three specific things it does is a slide making a claim
  /// the app does not keep.
  final List<L> chips;
}

/// One line of the "what's inside" list — used on the welcome screen and
/// again on the last step, so a user who skips the tour has still been told
/// what the app is for.
class CapabilityLine {
  const CapabilityLine(this.icon, this.text);

  final IconData icon;
  final L text;
}

// ---------------------------------------------------------------- the tour

const _booking = IntroSlide(
  icon: LucideIcons.wrench,
  title: L('ورش موثّقة،\nبضغطة واحدة', 'Trusted workshops,\none tap away'),
  body: L(
    'قارن الورش الموثّقة في منطقتك، واطّلع على خدماتها وأسعارها المعلنة، واحجز الموعد الذي يناسبك.',
    'Compare verified workshops in your region, see the services and prices they publish, and book the slot that suits you.',
  ),
  chips: [
    L('ورش موثّقة', 'Verified shops'),
    L('أسعار معلنة', 'Published prices'),
    L('تختار موعدك', 'You pick the slot'),
  ],
);

/// The one slide that has to land. Escrow is what makes this app different
/// from phoning a workshop directly, so it gets a slide rather than a bullet
/// on somebody else's.
const _escrow = IntroSlide(
  icon: LucideIcons.shieldCheck,
  title: L(
    'مبلغك محفوظ\nحتى ترضى عن العمل',
    'Your money is held\nuntil you approve',
  ),
  body: L(
    'نحتفظ بالمبلغ عند الحجز، ولا يصل الورشة إلا بعد أن تعتمد العمل المنجز. وإن لم يكن على ما يرام، تفتح نزاعاً ويُعاد إليك.',
    'We hold the amount when you book, and the workshop is paid only once you approve the finished work. If it is not right, you raise an issue and it comes back to you.',
  ),
  chips: [
    L('محفوظ عند الحجز', 'Held on booking'),
    L('أنت تعتمد', 'You approve'),
    L('استرداد عند النزاع', 'Refund on dispute'),
  ],
);

const _quotes = IntroSlide(
  icon: LucideIcons.receipt,
  title: L('سعر مفصّل\nقبل أي التزام', 'An itemised price\nbefore you commit'),
  body: L(
    'صِف القطعة أو الإصلاح الذي تحتاجه، فتردّ الورشة بسعر مفصّل — القطعة وأجرة التركيب كلٌّ على حدة. تقبله أو ترفضه، ولا شيء عليك قبل ذلك.',
    'Describe the part or repair you need and the workshop answers with an itemised price — the part and the labour costed separately. Accept it or decline it; nothing is owed until you do.',
  ),
  chips: [
    L('قطعة وأجرة منفصلتان', 'Part + labour split'),
    L('تقبل أو ترفض', 'Accept or decline'),
    L('بلا رسوم مسبقة', 'No upfront fee'),
  ],
);

const _tracking = IntroSlide(
  icon: LucideIcons.route,
  title: L(
    'تابع العمل،\nواحفظ تاريخ سيارتك',
    'Follow the work,\nkeep the history',
  ),
  body: L(
    'تابع كل مرحلة مباشرة مع صور الإنجاز من الورشة، ويبقى كل عمل في سجل سيارتك مع تذكيرات صيانة محسوبة من ممشاها.',
    'Watch each stage as it happens, with the workshop’s completion photos, and every job stays in your car’s record alongside reminders worked out from its mileage.',
  ),
  chips: [
    L('حالة مباشرة', 'Live status'),
    L('صور إنجاز', 'Photo proof'),
    L('تذكيرات الصيانة', 'Service reminders'),
  ],
);

// Phase-2 pillars. Present here so flipping the flag brings the slide back
// with the tab, and absent from the tour while the tab is compiled out.

const _parts = IntroSlide(
  icon: LucideIcons.shoppingBag,
  title: L('قطع مناسبة،\nتوصلك حيث أنت', 'Parts that fit,\ndelivered right'),
  body: L(
    'تسوّق قطع الغيار لسيارتك — أو لأي سيارة — مع فلاتر للفئة والمزوّد والسعر والمنطقة.',
    'Shop parts for your car — or any car — with filters for category, provider, price, and region.',
  ),
  chips: [
    L('تناسب سيارتك', 'Fits your car'),
    L('مزوّدون معتمدون', 'Approved sellers'),
    L('توصيل داخل عُمان', 'Delivery in Oman'),
  ],
);

const _marketplace = IntroSlide(
  icon: LucideIcons.carFront,
  title: L('اشترِ وبِع\nسيارتك', 'Buy and sell\nyour car'),
  body: L(
    'تصفّح السيارات المعروضة في عُمان، أو انشر إعلان سيارتك بالتفاصيل والصور في دقائق.',
    'Browse the cars listed across Oman, or publish your own ad with details and photos in minutes.',
  ),
  chips: [
    L('إعلانات عُمان', 'Oman listings'),
    L('انشر إعلانك', 'Post your ad'),
    L('فلاتر دقيقة', 'Precise filters'),
  ],
);

/// The tour, in the order a new user should meet the product: what it does,
/// why the money is safe, how a price gets agreed, and what happens after.
List<IntroSlide> introSlides() => [
  _booking,
  _escrow,
  if (AppFlags.requestPartInstall) _quotes,
  _tracking,
  if (AppFlags.partsStoreEnabled) _parts,
  if (AppFlags.carMarketplaceEnabled) _marketplace,
];

// ---------------------------------------------------------- what's inside

/// The short version of the tour: four lines, no scrolling, same promises.
List<CapabilityLine> capabilityHighlights() => [
  const CapabilityLine(
    LucideIcons.wrench,
    L('احجز لدى ورش موثّقة في منطقتك', 'Book verified workshops near you'),
  ),
  const CapabilityLine(
    LucideIcons.shieldCheck,
    L(
      'مبلغك محفوظ حتى تعتمد العمل',
      'Your payment is held until you approve the work',
    ),
  ),
  const CapabilityLine(
    LucideIcons.route,
    L('تابع كل مرحلة مع صور الإنجاز', 'Track every stage, with photo proof'),
  ),
  // Deliberately not the "Service reminders worked out from your mileage"
  // wording the "Add my car now" card uses: this recap sits on the same
  // screen as that card, and the same sentence twice on one page reads as a
  // rendering bug rather than as emphasis.
  const CapabilityLine(
    LucideIcons.bellRing,
    L(
      'سجلّ صيانة لسيارتك مع تذكير بمواعيدها',
      'A service record for your car, with due-date reminders',
    ),
  ),
  if (AppFlags.partsStoreEnabled)
    const CapabilityLine(
      LucideIcons.shoppingBag,
      L(
        'قطع غيار تناسب سيارتك مع التوصيل',
        'Parts that fit your car, delivered',
      ),
    ),
  if (AppFlags.carMarketplaceEnabled)
    const CapabilityLine(
      LucideIcons.carFront,
      L('اشترِ وبِع السيارات في عُمان', 'Buy and sell cars across Oman'),
    ),
];

/// Three words for the welcome screen's chip strip — the fastest possible
/// answer to "what is this app".
List<L> introChips() => const [
  L('ورش موثّقة', 'Verified shops'),
  L('دفع محفوظ', 'Protected payment'),
  L('تتبّع مباشر', 'Live tracking'),
];
