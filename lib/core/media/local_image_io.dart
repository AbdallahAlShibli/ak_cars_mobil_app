import 'dart:io';

import 'package:flutter/material.dart';

/// Mobile/desktop: [path] is a real file on disk.
///
/// [onError] draws the same fallback the caller uses for a broken remote
/// image, so a deleted temp file and a dead URL look alike to the user
/// instead of one of them rendering as blank space.
Widget localImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  required WidgetBuilder onError,
}) => Image.file(
  File(path),
  fit: fit,
  errorBuilder: (context, _, _) => onError(context),
);
