import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/ak_cars_app.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  // Loads preferences and warms the reference data every screen reads
  // synchronously, so the first frame is already complete.
  final container = await AppBootstrap.createContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AkCarsApp(),
    ),
  );
}
