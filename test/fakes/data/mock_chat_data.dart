import 'package:ak_cars_mobil_app/core/i18n/strings.dart';

/// Canned provider answers used while the real-time chat backend is pending.
/// Read only by `MockChatService`.
abstract final class MockChatData {
  /// How long the provider "types" before answering.
  static const replyDelay = Duration(milliseconds: 1400);

  /// Answers on a **pre-booking enquiry** thread, where nothing has been
  /// booked and no car has been handed over. Kept separate from
  /// [providerReplies] because those all assume a job in progress — replying
  /// "your car is with us" to someone who has not booked reads as the app
  /// talking about somebody else's booking.
  static const enquiryReplies = <L>[
    L('أهلاً بك! تفضّل، ما الذي تحتاجه لسيارتك؟',
        'Welcome! Go ahead — what does your car need?'),
    L('نعم، هذه الخدمة متوفرة لدينا. احجز الموعد من التطبيق ونؤكّده لك.',
        'Yes, we offer that. Book a slot in the app and we will confirm it.'),
    L('السعر المعروض في التطبيق هو السعر النهائي لهذه الخدمة.',
        'The price shown in the app is the final price for this service.'),
    L('في خدمتك — إن احتجت أي تفصيل آخر قبل الحجز فاسأل.',
        'Happy to help — ask anything else you need before booking.'),
  ];

  static const providerReplies = <L>[
    L('مرحباً! سيارتك عندنا — العمل يسير على ما يرام.',
        'Hello! Your car is with us — work is going well.'),
    L('نتوقع أن تكون جاهزة بحلول الساعة 4 عصراً اليوم.',
        'We expect it to be ready by 4 pm today.'),
    L('بالتأكيد، سنرسل الصور فور الانتهاء.',
        'Sure, we will send photos once we finish.'),
    L('على الرحب والسعة! هل تحتاج شيئاً آخر؟',
        'You are welcome! Anything else you need?'),
  ];
}
