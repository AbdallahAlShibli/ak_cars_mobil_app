import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Offline car artwork — a vector side profile drawn at paint time.
///
/// Why this exists: every car picture used to come from a remote CDN
/// (`cdn.imagin.studio`), so on a phone with no connection — or a release
/// Android build, which until now shipped without the INTERNET permission —
/// the whole app showed grey placeholder icons. The silhouette needs no
/// network, no bundled photography and no third-party image licence, so a
/// car always has a picture. Drop a real photo into `assets/cars/` and
/// register it in `core/media/vehicle_assets.dart` and it takes over.
///
/// The drawing is deterministic: the same make/model always produces the same
/// body shape and paint colour, so a car does not change appearance between
/// screens or rebuilds.

/// Body shapes the silhouette can draw. Inferred from the model name.
enum CarBodyType { sedan, suv, hatchback, coupe, pickup, van }

/// Keyword → body type. First match wins, checked against "make model".
const _bodyKeywords = <CarBodyType, List<String>>{
  CarBodyType.pickup: [
    'hilux', 'ranger', 'navara', 'd-max', 'dmax', 'f-150', 'f150',
    'silverado', 'sierra', 'colorado', 'tundra', 'tacoma', 'triton',
    'bt-50', 'l200', 'gladiator', 'pickup', 'pick-up',
  ],
  CarBodyType.van: [
    'hiace', 'urvan', 'transit', 'starex', 'staria', 'carnival', 'sienna',
    'alphard', 'vito', 'sprinter', 'caravan', 'h-1', 'van',
  ],
  CarBodyType.suv: [
    'patrol', 'land cruiser', 'prado', 'fortuner', 'pajero', 'x-trail',
    'rav4', 'cr-v', 'crv', 'tucson', 'santa fe', 'sportage', 'sorento',
    'explorer', 'tahoe', 'suburban', 'wrangler', 'range rover', 'discovery',
    'defender', 'jeep', 'gx', 'lx', 'q7', 'q5', 'x5', 'x7', 'glc', 'gle',
    'cx-5', 'cx-9', 'seltos', 'creta', 'kicks', 'juke', 'koleos', 'terrain',
    'traverse', 'escalade', 'expedition', '4runner', 'sequoia', 'highlander',
    'pathfinder', 'armada', 'telluride', 'palisade', 'suv',
  ],
  CarBodyType.coupe: [
    'mustang', 'camaro', 'corvette', 'challenger', 'supra', 'brz', '86',
    'z4', 'tt', 'coupe',
  ],
  CarBodyType.hatchback: [
    'yaris', 'swift', 'i10', 'i20', 'picanto', 'rio', 'march', 'mirage',
    'spark', 'jazz', 'fit', 'golf', 'polo', 'aygo', 'hatchback',
  ],
};

/// Best-guess body shape for a car. Unknown models draw as a sedan — the
/// most common shape, and the least wrong-looking default.
CarBodyType carBodyType(String make, String model) {
  final haystack = '$make $model'.toLowerCase();
  for (final entry in _bodyKeywords.entries) {
    for (final keyword in entry.value) {
      if (haystack.contains(keyword)) return entry.key;
    }
  }
  return CarBodyType.sedan;
}

/// Paint colours, keyed by the same English colour names the spec catalog
/// uses (`SpecCatalog.colors`). Kept local so `core/` does not depend on the
/// mock data layer.
const _paintColors = <String, Color>{
  'white': Color(0xFFECEAE4),
  'black': Color(0xFF23211D),
  'silver': Color(0xFFC3C6CB),
  'gray': Color(0xFF9AA0A6),
  'grey': Color(0xFF9AA0A6),
  'blue': Color(0xFF2C4A6E),
  'red': Color(0xFF9B2A32),
  'maroon': Color(0xFF7B2D3B),
  'beige': Color(0xFFD9C9A8),
  'brown': Color(0xFF6B4A2F),
  'gold': Color(0xFFC9A24B),
  'green': Color(0xFF35604A),
  'orange': Color(0xFFC96B1E),
  'yellow': Color(0xFFE0B93B),
};

/// Muted fallback palette used when the car has no recorded colour. Picked
/// deterministically from the make/model so the same car always looks the
/// same, and so a list of cars is not monochrome.
const _fallbackPalette = <Color>[
  Color(0xFF3A4A5C),
  Color(0xFF6B5B4A),
  Color(0xFF4A5A50),
  Color(0xFF8A8378),
  Color(0xFF5A4A56),
  Color(0xFF2F3B44),
];

Color carPaintColor(String make, String model, String? color) {
  final named = _paintColors[color?.trim().toLowerCase() ?? ''];
  if (named != null) return named;
  final hash = '$make $model'.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xFFFF);
  return _fallbackPalette[hash % _fallbackPalette.length];
}

/// A car drawn as a side profile, scaled to fit the widget's constraints.
class CarArtwork extends StatelessWidget {
  const CarArtwork({
    super.key,
    required this.make,
    required this.model,
    this.color,
    this.variant = 0,
  });

  final String make;
  final String model;

  /// Exterior colour name (`'White'`, `'Silver'`, …). Null → derived from
  /// the make/model so the car still gets a stable, plausible paint.
  final String? color;

  /// Distinguishes repeated renders of the same car — a photo carousel uses
  /// the page index so the "photos" are not identical. Even variants face
  /// right, odd variants face left.
  final int variant;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _CarSilhouettePainter(
        body: carBodyType(make, model),
        bodyColor: carPaintColor(make, model, color),
        variant: variant,
      ),
      isComplex: true,
      willChange: false,
    );
  }
}

/// The silhouette is authored in this fixed viewbox and scaled to fit.
const _viewBox = Size(104, 46);

class _CarSilhouettePainter extends CustomPainter {
  _CarSilhouettePainter({
    required this.body,
    required this.bodyColor,
    required this.variant,
  });

  final CarBodyType body;
  final Color bodyColor;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Contain the viewbox in the available space, centred.
    final scale = math.min(
      size.width / _viewBox.width,
      size.height / _viewBox.height,
    );
    final drawn = Size(_viewBox.width * scale, _viewBox.height * scale);

    canvas.save();
    canvas.translate(
      (size.width - drawn.width) / 2,
      (size.height - drawn.height) / 2,
    );
    canvas.scale(scale);

    // Odd variants show the other side of the car.
    if (variant.isOdd) {
      canvas.translate(_viewBox.width, 0);
      canvas.scale(-1, 1);
    }

    final shape = _shapeFor(body);
    _paintShadow(canvas, shape);
    _paintBody(canvas, shape);
    _paintGlass(canvas, shape);
    for (final wheel in shape.wheels) {
      _paintWheel(canvas, wheel);
    }

    canvas.restore();
  }

  void _paintShadow(Canvas canvas, _CarShape shape) {
    final rect = Rect.fromCenter(
      center: Offset(_viewBox.width / 2, 41.5),
      width: shape.length,
      height: 4.5,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0x2A1D1B17)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
  }

  void _paintBody(Canvas canvas, _CarShape shape) {
    final light = Color.lerp(bodyColor, Colors.white, 0.22)!;
    final dark = Color.lerp(bodyColor, Colors.black, 0.28)!;

    canvas.drawPath(
      shape.body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, bodyColor, dark],
          stops: const [0, 0.55, 1],
        ).createShader(shape.body.getBounds()),
    );

    // Belt-line highlight — the reflection that reads as "car" more than any
    // other single detail.
    canvas.drawPath(
      shape.beltLine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(bodyColor, Colors.white, 0.45)!.withValues(alpha: 0.7),
    );

    canvas.drawPath(
      shape.body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = dark.withValues(alpha: 0.55),
    );
  }

  void _paintGlass(Canvas canvas, _CarShape shape) {
    final glass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDCE4EC), Color(0xFF9AA7B4)],
      ).createShader(shape.glassBounds);
    for (final window in shape.windows) {
      canvas.drawPath(window, glass);
    }
  }

  void _paintWheel(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFF23211D));
    canvas.drawCircle(center, 4.4, Paint()..color = const Color(0xFF3A3733));
    canvas.drawCircle(center, 3.1, Paint()..color = const Color(0xFFBFC3C7));
    canvas.drawCircle(center, 1.1, Paint()..color = const Color(0xFF8B8F93));
  }

  @override
  bool shouldRepaint(_CarSilhouettePainter old) =>
      old.body != body || old.bodyColor != bodyColor || old.variant.isOdd != variant.isOdd;
}

/// Geometry of one body style inside [_viewBox].
class _CarShape {
  _CarShape({
    required this.body,
    required this.beltLine,
    required this.windows,
    required this.wheels,
    required this.length,
  });

  final Path body;
  final Path beltLine;
  final List<Path> windows;
  final List<Offset> wheels;

  /// Bumper-to-bumper width, used to size the ground shadow.
  final double length;

  Rect get glassBounds =>
      windows.isEmpty ? Rect.zero : windows.first.getBounds().inflate(12);
}

Path _polygon(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

_CarShape _shapeFor(CarBodyType body) => switch (body) {
      CarBodyType.sedan => _sedan(),
      CarBodyType.suv => _suv(),
      CarBodyType.hatchback => _hatchback(),
      CarBodyType.coupe => _coupe(),
      CarBodyType.pickup => _pickup(),
      CarBodyType.van => _van(),
    };

_CarShape _sedan() {
  final body = Path()
    ..moveTo(4, 34)
    ..quadraticBezierTo(2.5, 25, 7, 22)
    ..lineTo(22, 19)
    ..lineTo(34, 17)
    ..quadraticBezierTo(39, 9, 48, 8.5)
    ..lineTo(62, 8.5)
    ..quadraticBezierTo(72, 10, 80, 18)
    ..lineTo(94, 20)
    ..quadraticBezierTo(100, 22, 99, 34)
    ..close();
  return _CarShape(
    body: body,
    beltLine: Path()
      ..moveTo(10, 24)
      ..quadraticBezierTo(52, 20.5, 96, 24),
    windows: [
      _polygon(const [
        Offset(37, 16.4),
        Offset(48.5, 10.4),
        Offset(56.5, 10.4),
        Offset(56.5, 16.4),
      ]),
      _polygon(const [
        Offset(59, 10.4),
        Offset(69, 10.9),
        Offset(76.5, 16.4),
        Offset(59, 16.4),
      ]),
    ],
    wheels: const [Offset(26, 33), Offset(78, 33)],
    length: 95,
  );
}

_CarShape _suv() {
  final body = Path()
    ..moveTo(5, 34)
    ..quadraticBezierTo(3, 23, 8, 20)
    ..lineTo(20, 17.5)
    ..lineTo(31, 15)
    ..quadraticBezierTo(35, 6.5, 44, 6)
    ..lineTo(80, 6.5)
    ..quadraticBezierTo(88, 7, 90, 12)
    ..lineTo(93, 19)
    ..quadraticBezierTo(99, 21, 98, 34)
    ..close();
  return _CarShape(
    body: body,
    beltLine: Path()
      ..moveTo(11, 22)
      ..quadraticBezierTo(52, 18.5, 95, 22),
    windows: [
      _polygon(const [
        Offset(34, 14.2),
        Offset(44, 8.4),
        Offset(53, 8.4),
        Offset(53, 14.2),
      ]),
      _polygon(const [
        Offset(55.5, 8.4),
        Offset(67, 8.4),
        Offset(67, 14.2),
        Offset(55.5, 14.2),
      ]),
      _polygon(const [
        Offset(69.5, 8.4),
        Offset(82, 8.6),
        Offset(86, 14.2),
        Offset(69.5, 14.2),
      ]),
    ],
    wheels: const [Offset(26, 33), Offset(79, 33)],
    length: 96,
  );
}

_CarShape _hatchback() {
  final body = Path()
    ..moveTo(9, 34)
    ..quadraticBezierTo(7, 25, 11.5, 22)
    ..lineTo(25, 19.5)
    ..lineTo(35, 17.5)
    ..quadraticBezierTo(39, 9.5, 47, 9)
    ..lineTo(66, 9.5)
    ..quadraticBezierTo(78, 11, 84, 20)
    ..quadraticBezierTo(88, 24, 87, 34)
    ..close();
  return _CarShape(
    body: body,
    beltLine: Path()
      ..moveTo(14, 24)
      ..quadraticBezierTo(50, 20.5, 85, 24),
    windows: [
      _polygon(const [
        Offset(38, 16.8),
        Offset(47.5, 11),
        Offset(55.5, 11),
        Offset(55.5, 16.8),
      ]),
      _polygon(const [
        Offset(58, 11),
        Offset(67, 11.2),
        Offset(74, 16.8),
        Offset(58, 16.8),
      ]),
    ],
    wheels: const [Offset(29, 33), Offset(72, 33)],
    length: 82,
  );
}

_CarShape _coupe() {
  final body = Path()
    ..moveTo(4, 34)
    ..quadraticBezierTo(2.5, 26, 7, 23.5)
    ..lineTo(24, 20.5)
    ..lineTo(38, 18.5)
    ..quadraticBezierTo(44, 11, 54, 10.5)
    ..lineTo(62, 11)
    ..quadraticBezierTo(78, 13.5, 90, 21)
    ..quadraticBezierTo(99, 24, 98, 34)
    ..close();
  return _CarShape(
    body: body,
    beltLine: Path()
      ..moveTo(10, 25.5)
      ..quadraticBezierTo(52, 22, 95, 26),
    windows: [
      _polygon(const [
        Offset(41, 18),
        Offset(54, 12.4),
        Offset(61, 12.8),
        Offset(61, 18),
      ]),
      _polygon(const [
        Offset(63.5, 13),
        Offset(74, 15.4),
        Offset(80, 18),
        Offset(63.5, 18),
      ]),
    ],
    wheels: const [Offset(26, 33), Offset(79, 33)],
    length: 95,
  );
}

_CarShape _pickup() {
  final body = Path()
    ..moveTo(4, 34)
    ..quadraticBezierTo(2.5, 23, 7, 20)
    ..lineTo(19, 17.5)
    ..lineTo(30, 15)
    ..quadraticBezierTo(34, 7, 43, 6.5)
    ..lineTo(58, 7)
    ..quadraticBezierTo(62, 8, 63, 15)
    ..lineTo(63, 20)
    ..lineTo(99, 20)
    ..lineTo(99, 34)
    ..close();
  return _CarShape(
    body: body,
    beltLine: Path()
      ..moveTo(10, 22)
      ..lineTo(62, 19)
      ..moveTo(64, 23.5)
      ..lineTo(98, 23.5),
    windows: [
      _polygon(const [
        Offset(33, 14.2),
        Offset(43, 8.9),
        Offset(50, 8.9),
        Offset(50, 14.2),
      ]),
      _polygon(const [
        Offset(52.5, 8.9),
        Offset(58, 9.2),
        Offset(60.5, 14.2),
        Offset(52.5, 14.2),
      ]),
    ],
    wheels: const [Offset(25, 33), Offset(82, 33)],
    length: 97,
  );
}

_CarShape _van() {
  final body = Path()
    ..moveTo(5, 34)
    ..quadraticBezierTo(3, 20, 9, 16)
    ..lineTo(20, 10)
    ..quadraticBezierTo(24, 5.5, 32, 5)
    ..lineTo(88, 5.5)
    ..quadraticBezierTo(95, 6, 96, 12)
    ..lineTo(97, 26)
    ..quadraticBezierTo(98, 31, 96, 34)
    ..close();
  return _CarShape(
    body: body,
    beltLine: Path()
      ..moveTo(11, 21)
      ..quadraticBezierTo(52, 18.5, 95, 21),
    windows: [
      _polygon(const [
        Offset(15.5, 16.6),
        Offset(24, 8.2),
        Offset(33, 8.2),
        Offset(33, 16.6),
      ]),
      _polygon(const [
        Offset(35.5, 8.2),
        Offset(57, 8.2),
        Offset(57, 16.6),
        Offset(35.5, 16.6),
      ]),
      _polygon(const [
        Offset(59.5, 8.2),
        Offset(80, 8.2),
        Offset(80, 16.6),
        Offset(59.5, 16.6),
      ]),
    ],
    wheels: const [Offset(24, 33), Offset(80, 33)],
    length: 94,
  );
}
