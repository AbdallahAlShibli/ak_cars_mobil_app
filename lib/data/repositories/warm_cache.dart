/// A single value fetched once at start-up and then read synchronously.
///
/// Why this exists: most screens read reference data (spec vocabulary, makes,
/// the parts catalogue) inline while building, with no loading state in the
/// design. Rather than sprinkle `AsyncValue` handling through widgets that
/// have nowhere to render it, the app warms these caches during bootstrap and
/// the widgets keep their synchronous reads.
///
/// [fallback] is what a read sees before the first successful load. It exists
/// so a widget built outside the bootstrap path degrades to empty rather than
/// throwing; production code always warms first.
class WarmCache<T> {
  WarmCache({required T fallback}) : _value = fallback;

  T _value;
  bool _warm = false;

  T get value => _value;

  /// True once [load] has succeeded at least once.
  bool get isWarm => _warm;

  /// Fetches and stores the value. Exceptions propagate: bootstrap decides
  /// whether a failed warm-up is fatal.
  Future<T> load(Future<T> Function() fetch) async {
    _value = await fetch();
    _warm = true;
    return _value;
  }

  /// Replaces the cached value after a write that the caller already knows
  /// the result of, avoiding a redundant round trip.
  void put(T value) {
    _value = value;
    _warm = true;
  }
}
