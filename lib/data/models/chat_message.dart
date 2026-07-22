import '../../core/json/json_utils.dart';

/// One message in the per-request customer ↔ provider thread.
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
