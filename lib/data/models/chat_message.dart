import '../../core/json/json_utils.dart';

/// A thread can hang off two things, and the key says which.
///
/// Normally it is a booking, and the key is the request id. But contact
/// details are gated on escrow (`core/utils/provider_contact.dart`), so a
/// customer who has not booked yet still needs somewhere to ask — that thread
/// belongs to a *workshop*, and is keyed by this prefix so a provider id can
/// never be mistaken for a request id in the same store. Anything answering a
/// thread has to know which of the two it is: "your car is with us" is a fine
/// reply on a booking and nonsense on an enquiry.
const String providerThreadPrefix = 'provider:';

/// The thread key for a pre-booking enquiry with [providerId].
String providerThreadId(String providerId) =>
    '$providerThreadPrefix$providerId';

/// Whether [threadId] is a pre-booking enquiry rather than a booking's thread.
bool isProviderThread(String threadId) =>
    threadId.startsWith(providerThreadPrefix);

/// One message in the customer ↔ provider thread.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.time,
  });

  final String id;

  /// True when the customer sent it; false for the provider.
  final bool fromUser;
  final String text;
  final DateTime time;

  factory ChatMessage.fromJson(JsonMap json) => ChatMessage(
        id: json.requireString('id'),
        fromUser: json.boolOr('fromUser', false),
        text: json.stringOr('text', ''),
        time: json.dateTimeOr('time', DateTime.now()),
      );

  JsonMap toJson() => {
        'id': id,
        'fromUser': fromUser,
        'text': text,
        'time': time.toIso8601String(),
      };

  ChatMessage copyWith({
    String? id,
    bool? fromUser,
    String? text,
    DateTime? time,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        fromUser: fromUser ?? this.fromUser,
        text: text ?? this.text,
        time: time ?? this.time,
      );

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.id == id &&
      other.fromUser == fromUser &&
      other.text == text &&
      other.time == time;

  @override
  int get hashCode => Object.hash(id, fromUser, text, time);
}
