/// Free-text matching shared by every searchable model.
///
/// **Tokens are ANDed, not matched as one substring.** A buyer typing
/// "camry 2017" is naming two facts about one car, and a substring match
/// against "2017 Toyota Camry SE" fails because the words are in the other
/// order. Splitting on whitespace and requiring every token to appear
/// somewhere in the record is what makes "toyota muscat", "denso filter" and
/// "camry 2017" all behave the way the person typing them expects.
///
/// Each token also gets a punctuation-stripped comparison, so "90915 yzze1"
/// finds part number `90915-YZZE1`.
abstract final class SearchMatch {
  static final _separators = RegExp(r'\s+');
  static final _punctuation = RegExp(r'[^a-z0-9؀-ۿ]');

  /// True when every token in [query] appears in at least one of [fields].
  /// An empty or whitespace-only query matches everything.
  static bool all(String query, Iterable<String?> fields) {
    final tokens = query.trim().toLowerCase().split(_separators)
      ..removeWhere((t) => t.isEmpty);
    if (tokens.isEmpty) return true;

    final haystack =
        fields.where((f) => f != null && f.isNotEmpty).join(' ').toLowerCase();
    if (haystack.isEmpty) return false;
    final bare = haystack.replaceAll(_punctuation, '');

    for (final token in tokens) {
      if (haystack.contains(token)) continue;
      final bareToken = token.replaceAll(_punctuation, '');
      if (bareToken.isNotEmpty && bare.contains(bareToken)) continue;
      return false;
    }
    return true;
  }
}
