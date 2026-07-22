import '../../../core/i18n/strings.dart';

/// Canned provider answers used while the real-time chat backend is pending.
/// Read only by `MockChatService`.
abstract final class MockChatData {
  /// How long the provider "types" before answering.
  static const replyDelay = Duration(milliseconds: 1400);

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
