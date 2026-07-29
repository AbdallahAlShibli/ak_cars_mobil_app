import '../../core/json/json_utils.dart';

/// One attachment on a completion proof.
///
/// [uri] is whatever the storage layer hands back — an https URL from the
/// backend, or a local file path while a device upload is still queued. The
/// model does not care which; the widget that renders it does.
class ProofMedia {
  const ProofMedia({
    required this.id,
    required this.uri,
    this.kind = ProofMediaKind.photo,
    this.caption = '',
  });

  final String id;
  final String uri;
  final ProofMediaKind kind;

  /// What the workshop said this shot is of ("الفلتر القديم"). Optional —
  /// an uncaptioned photo is still evidence.
  final String caption;

  factory ProofMedia.fromJson(JsonMap json) => ProofMedia(
        id: json.requireString('id'),
        uri: json.stringOr('uri', ''),
        kind: json.enumOr('kind', ProofMediaKind.values, ProofMediaKind.photo),
        caption: json.stringOr('caption', ''),
      );

  JsonMap toJson() => {
        'id': id,
        'uri': uri,
        'kind': kind.name,
        'caption': caption,
      };

  ProofMedia copyWith({
    String? id,
    String? uri,
    ProofMediaKind? kind,
    String? caption,
  }) =>
      ProofMedia(
        id: id ?? this.id,
        uri: uri ?? this.uri,
        kind: kind ?? this.kind,
        caption: caption ?? this.caption,
      );

  @override
  bool operator ==(Object other) =>
      other is ProofMedia &&
      other.id == id &&
      other.uri == uri &&
      other.kind == kind &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(id, uri, kind, caption);
}

enum ProofMediaKind { photo, video }

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
class ProofOfWork {
  const ProofOfWork({
    required this.id,
    required this.requestId,
    required this.notes,
    required this.submittedAt,
    this.media = const [],
    this.includesPartBoxPhoto = false,
  });

  final String id;
  final String requestId;

  /// What the workshop wrote — free text, in whatever language they typed.
  /// Not an [L]: this is user-authored content, not app copy, so it is never
  /// translated and never guessed at.
  final String notes;

  final DateTime submittedAt;
  final List<ProofMedia> media;

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

  bool get hasMedia => media.isNotEmpty;

  factory ProofOfWork.fromJson(JsonMap json) => ProofOfWork(
        id: json.requireString('id'),
        requestId: json.stringOr('requestId', ''),
        notes: json.stringOr('notes', ''),
        submittedAt: json.dateTimeOr('submittedAt', DateTime.now()),
        media: json.objectList('media').map(ProofMedia.fromJson).toList(),
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
    List<ProofMedia>? media,
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

  bool _sameMedia(List<ProofMedia> other) {
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
