import 'dart:async';

import 'package:flutter/foundation.dart';

/// How many API requests are in flight, for the app-wide loading bar.
///
/// `DioApiClient` calls [begin] when a request starts and [end] when its last
/// attempt settles, so a read that is retried counts once.
///
/// [busy] changes in a microtask, never synchronously. A request can start
/// while a widget is building — a provider's `build()` fetching on its first
/// watch — and a listener rebuilding in that moment would throw. The microtask
/// also folds a request that starts and finishes in the same turn into no
/// change at all.
class NetworkActivity {
  var _inFlight = 0;
  var _scheduled = false;
  var _disposed = false;

  /// True while at least one request is in flight.
  final busy = ValueNotifier<bool>(false);

  void begin() {
    _inFlight++;
    _schedule();
  }

  void end() {
    if (_inFlight > 0) _inFlight--;
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) busy.value = _inFlight > 0;
    });
  }

  void dispose() {
    _disposed = true;
    busy.dispose();
  }
}
