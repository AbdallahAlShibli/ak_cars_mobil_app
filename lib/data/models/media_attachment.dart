import '../../core/json/json_utils.dart';

/// Every file a user attaches anywhere in the app: completion-proof photos, a
/// workshop's commercial-registration certificate, anything added later.
///
/// **The bytes travel with the record, base64-encoded.** There is no upload
/// endpoint, no storage bucket, and no URL — an attachment is a value, and it
/// is stored in the database column next to the row that owns it. That is a
/// deliberate choice with a real cost (a 400 KB photo is ~533 KB of base64 in
/// every request and every response that carries it), taken because the pilot
/// has no object storage and a half-uploaded file with a dangling URL is a
/// worse failure than a large payload.
///
/// What that buys: a record composed offline on a phone is *complete*. It can
/// be created, validated, equality-compared and persisted without a second
/// round trip, and the id it is born with is the id the database stores.
///
/// [kind] is derived from [mimeType] rather than stored, so the two can never
/// disagree — a record claiming `kind: photo` over PDF bytes is not a state
/// this type can represent.
class MediaAttachment {
  const MediaAttachment({
    required this.id,
    required this.base64Data,
    required this.mimeType,
    this.fileName = '',
    this.caption = '',
  });

  /// GUID, generated at capture time on the device. See `core/utils/guid.dart`.
  final String id;

  /// The file's bytes, base64-encoded, **without** a `data:` prefix.
  ///
  /// The prefix is a browser-URL convention, not part of the encoding; storing
  /// it would mean every reader has to strip it and every writer has to
  /// remember it. [dataUri] builds one on demand for the one caller that wants
  /// it.
  final String base64Data;

  /// IANA media type, e.g. `image/jpeg`, `image/png`, `application/pdf`.
  /// The single source of truth for how this attachment gets rendered.
  final String mimeType;

  /// What the file was called on the device. Shown for documents, which have
  /// no thumbnail to identify them by. Empty is fine for a camera capture —
  /// nobody names a photo they just took.
  final String fileName;

  /// What the uploader said this is of ("الفلتر القديم"). Optional — an
  /// uncaptioned photo is still evidence.
  final String caption;

  /// How to render this: an image, a video, or a file with no preview.
  MediaKind get kind {
    final type = mimeType.toLowerCase();
    if (type.startsWith('image/')) return MediaKind.image;
    if (type.startsWith('video/')) return MediaKind.video;
    return MediaKind.document;
  }

  /// Size of the *decoded* file in bytes, computed from the base64 length
  /// rather than by decoding — this is read to draw a "1.2 MB" label, and
  /// decoding a megabyte to count it would be absurd.
  ///
  /// Base64 packs 3 bytes into 4 characters; each `=` at the end is one byte
  /// of padding that is not real data.
  int get byteLength {
    final length = base64Data.length;
    if (length == 0) return 0;
    var padding = 0;
    if (base64Data.endsWith('==')) {
      padding = 2;
    } else if (base64Data.endsWith('=')) {
      padding = 1;
    }
    return (length ~/ 4) * 3 - padding;
  }

  /// True when there are actually bytes here. An attachment with an empty
  /// [base64Data] is a placeholder, and callers that gate on evidence — the
  /// proof sheet, workshop approval — must not count it.
  bool get hasBytes => base64Data.isNotEmpty;

  /// `data:image/jpeg;base64,…` — for the rare consumer that wants a URL
  /// rather than bytes. Rendering goes through `core/media/media_view.dart`,
  /// which decodes to bytes and does not use this.
  String get dataUri => 'data:$mimeType;base64,$base64Data';

  factory MediaAttachment.fromJson(JsonMap json) => MediaAttachment(
        id: json.requireString('id'),
        base64Data: json.stringOr('base64Data', ''),
        mimeType: json.stringOr('mimeType', 'application/octet-stream'),
        fileName: json.stringOr('fileName', ''),
        caption: json.stringOr('caption', ''),
      );

  JsonMap toJson() => {
        'id': id,
        'base64Data': base64Data,
        'mimeType': mimeType,
        'fileName': fileName,
        'caption': caption,
      };

  MediaAttachment copyWith({
    String? id,
    String? base64Data,
    String? mimeType,
    String? fileName,
    String? caption,
  }) =>
      MediaAttachment(
        id: id ?? this.id,
        base64Data: base64Data ?? this.base64Data,
        mimeType: mimeType ?? this.mimeType,
        fileName: fileName ?? this.fileName,
        caption: caption ?? this.caption,
      );

  /// Compares [id] and metadata but **not** [base64Data].
  ///
  /// The id is a GUID minted once for one specific file, so two attachments
  /// with the same id hold the same bytes by construction. Comparing a
  /// megabyte of base64 character-by-character inside a widget rebuild — which
  /// is where model equality gets called — would be a real cost for an answer
  /// the id already gave. [byteLength] is compared as a cheap guard so a
  /// truncated copy is not mistaken for the original.
  @override
  bool operator ==(Object other) =>
      other is MediaAttachment &&
      other.id == id &&
      other.mimeType == mimeType &&
      other.fileName == fileName &&
      other.caption == caption &&
      other.base64Data.length == base64Data.length;

  @override
  int get hashCode =>
      Object.hash(id, mimeType, fileName, caption, base64Data.length);

  @override
  String toString() =>
      'MediaAttachment($id, $mimeType, ${byteLength}B, "$fileName")';
}

/// How an attachment is rendered. Derived from the MIME type, never stored.
enum MediaKind { image, video, document }
