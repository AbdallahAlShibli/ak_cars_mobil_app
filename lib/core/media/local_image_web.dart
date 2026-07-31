import 'package:flutter/material.dart';

/// Web: `image_picker` returns a `blob:` URL, which the network loader reads
/// directly. There is no file system to reach for here.
Widget localImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  required WidgetBuilder onError,
}) => Image.network(
  path,
  fit: fit,
  errorBuilder: (context, _, _) => onError(context),
);
