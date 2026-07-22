import '../json/json_utils.dart';

/// Envelope returned by the AK Cars API for a single resource.
///
/// The backend does not use a shared envelope today (see the project's
/// technical-debt list), so [ApiResponse.fromJson] accepts both shapes: a
/// wrapped `{ "data": {...}, "message": "..." }` payload and a bare resource
/// object. That keeps the client working whichever convention the API settles
/// on.
class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    this.message,
    this.success = true,
  });

  final T data;
  final String? message;
  final bool success;

  /// [fromData] converts the resource payload into [T].
  factory ApiResponse.fromJson(
    JsonMap json,
    T Function(Object? data) fromData,
  ) {
    if (json.containsKey('data')) {
      return ApiResponse(
        data: fromData(json['data']),
        message: json.stringOrNull('message'),
        success: json.boolOr('success', true),
      );
    }
    return ApiResponse(data: fromData(json));
  }

  ApiResponse<R> map<R>(R Function(T value) transform) => ApiResponse(
        data: transform(data),
        message: message,
        success: success,
      );
}

/// A page of results plus the cursor metadata needed to request the next one.
///
/// Mirrors the paging shape already used by `GET /api/cars`.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;

  bool get hasMore => page * pageSize < totalCount;
  int get totalPages => pageSize == 0 ? 0 : (totalCount / pageSize).ceil();

  /// Wraps an already-materialised list as a single complete page — what the
  /// mock services return until real paging exists server-side.
  factory PaginatedResponse.single(List<T> items) => PaginatedResponse(
        items: items,
        page: 1,
        pageSize: items.length,
        totalCount: items.length,
      );

  factory PaginatedResponse.fromJson(
    JsonMap json,
    T Function(JsonMap json) fromItem,
  ) {
    final rawItems = json['items'] ?? json['data'] ?? json['results'];
    return PaginatedResponse(
      items: (rawItems as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(fromItem)
          .toList(growable: false),
      page: json.intOr('page', 1),
      pageSize: json.intOr('pageSize', 0),
      totalCount: json.intOr('totalCount', 0),
    );
  }

  PaginatedResponse<R> map<R>(R Function(T item) transform) =>
      PaginatedResponse(
        items: items.map(transform).toList(growable: false),
        page: page,
        pageSize: pageSize,
        totalCount: totalCount,
      );
}
