import '../../core/json/json_utils.dart';
import 'media_attachment.dart';

/// The workshop's evidence that the job was done (spec §2, "إثبات الإنجاز").
///
/// This is the object the whole escrow rests on: the customer approves a
/// release because of what is in here, so it is stored as its own record with
/// its own timestamp rather than as loose fields on the booking.
///
/// [media] is legitimately empty when the workshop submitted notes only. The
/// approval screen says so in words rather than drawing placeholder tiles —
/// an empty gallery must never look like photos that failed to load, and it
/// must certainly never be filled with invented ones.
///
/// Each entry is a [MediaAttachment]: the photo's bytes, base64-encoded, held
/// on the record itself. A proof is complete the moment the workshop composes
/// it, with no upload step that could half-succeed and leave the customer
/// looking at a broken image while being asked to release money.
class ProofOfWork {
  const ProofOfWork({
    required this.id,
    required this.requestId,
    required this.notes,
    required this.submittedAt,
    this.media = const [],
    this.includesPartBoxPhoto = false,
  });

  /// GUID.
  final String id;

  /// GUID of the service request this proves.
  final String requestId;

  /// What the workshop wrote — free text, in whatever language they typed.
  /// Not an [L]: this is user-authored content, not app copy, so it is never
  /// translated and never guessed at.
  final String notes;

  final DateTime submittedAt;
  final List<MediaAttachment> media;

  /// The workshop's declaration that the proof shows the **part's own box or
  /// label**, not just the fitted result.
  ///
  /// Required before a `BookingType.customQuote` job may reach
  /// `proofSubmitted` (spec §6): the customer paid for a specific part from a
  /// specific brand, and a photo of a closed bonnet proves neither. It is a
  /// declaration, not a verification — the app cannot tell what is in a
  /// picture — which is why it is the workshop that ticks it and the customer
  /// who sees that it was ticked.
  final bool includesPartBoxPhoto;

  /// Whether there is any evidence attached at all.
  ///
  /// Counts only attachments that actually carry bytes: an entry with an empty
  /// `base64Data` is a placeholder, and letting one satisfy the "at least one
  /// photo" rule would turn the escrow gate into a formality.
  bool get hasMedia => media.any((m) => m.hasBytes);

  factory ProofOfWork.fromJson(JsonMap json) => ProofOfWork(
        id: json.requireString('id'),
        requestId: json.stringOr('requestId', ''),
        notes: json.stringOr('notes', ''),
        submittedAt: json.dateTimeOr('submittedAt', DateTime.now()),
        media: json.objectList('media').map(MediaAttachment.fromJson).toList(),
        includesPartBoxPhoto: json.boolOr('includesPartBoxPhoto', false),
      );

  JsonMap toJson() => {
        'id': id,
        'requestId': requestId,
        'notes': notes,
        'submittedAt': submittedAt.toIso8601String(),
        'media': [for (final m in media) m.toJson()],
        'includesPartBoxPhoto': includesPartBoxPhoto,
      };

  ProofOfWork copyWith({
    String? id,
    String? requestId,
    String? notes,
    DateTime? submittedAt,
    List<MediaAttachment>? media,
    bool? includesPartBoxPhoto,
  }) =>
      ProofOfWork(
        id: id ?? this.id,
        requestId: requestId ?? this.requestId,
        notes: notes ?? this.notes,
        submittedAt: submittedAt ?? this.submittedAt,
        media: media ?? this.media,
        includesPartBoxPhoto:
            includesPartBoxPhoto ?? this.includesPartBoxPhoto,
      );

  @override
  bool operator ==(Object other) =>
      other is ProofOfWork &&
      other.id == id &&
      other.requestId == requestId &&
      other.notes == notes &&
      other.submittedAt == submittedAt &&
      other.includesPartBoxPhoto == includesPartBoxPhoto &&
      _sameMedia(other.media);

  bool _sameMedia(List<MediaAttachment> other) {
    if (other.length != media.length) return false;
    for (var i = 0; i < media.length; i++) {
      if (other[i] != media[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        requestId,
        notes,
        submittedAt,
        includesPartBoxPhoto,
        Object.hashAll(media),
      );
}
