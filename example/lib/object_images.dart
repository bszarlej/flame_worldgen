import 'dart:math';
import 'dart:ui';

// Pictures of the scattered objects, drawn once in code, like the tiles.
// Light comes from the top left. Each object stands on the bottom centre of
// its image.

/// Every tree picture: leafy trees in two shades of green, and pines.
final List<Image> treeImages = [
  for (final colors in _leafColors)
    for (var shape = 0; shape < 3; shape++) _leafyTree(colors, Random(shape)),
  _pine(tiers: 3, width: 26, height: 46),
  _pine(tiers: 4, width: 30, height: 54),
];

/// Every rock picture: boulders of three sizes, a mossy one and a pair.
final List<Image> rockImages = [
  _rocks(Random(1), [(13, 9)]),
  _rocks(Random(2), [(18, 12)]),
  _rocks(Random(3), [(24, 16)]),
  _rocks(Random(4), [(22, 15)], mossy: true),
  _rocks(Random(5), [(19, 13), (11, 8)]),
];

/// Every bush picture: plain, with berries and with flowers.
final List<Image> bushImages = [
  _bush(Random(1)),
  _bush(Random(2)),
  _bush(Random(3), dots: (Color(0xFFD7263D), Color(0xFFFF9A9A))),
  _bush(Random(4), dots: (Color(0xFFFFF4D6), Color(0xFFFFD84D))),
];

/// The outline, shadow, base and highlight colour of leaves or stone.
typedef _Colors = (Color, Color, Color, Color);

const _leafColors = <_Colors>[
  (Color(0xFF173A1A), Color(0xFF2E6A2A), Color(0xFF4E9A3A), Color(0xFF7CC152)),
  (Color(0xFF1F3F17), Color(0xFF3B7029), Color(0xFF5C9E36), Color(0xFF93C95A)),
];

const _pineColors = (
  Color(0xFF0F2E1E),
  Color(0xFF1F5536),
  Color(0xFF2E7A4C),
  Color(0xFF4C9D66),
);

const _bark = Color(0xFF6B4226);
const _barkShade = Color(0xFF4A2C19);
const _groundShadow = Color(0x40000000);

Paint _fill(Color color) => Paint()..color = color;

/// A round tree whose crown is a cluster of leafy blobs. [random] varies the
/// blobs.
Image _leafyTree(_Colors colors, Random random) {
  const width = 38;
  const height = 44;
  final (_, shadow, _, highlight) = colors;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  _drawGroundShadow(canvas, width / 2, height - 4, 30);
  _drawTrunk(canvas, width / 2, top: 26, bottom: height - 3, halfWidth: 3.5);

  // The crown: blobs around a centre, each a few pixels bigger or smaller.
  const centre = Offset(width / 2, 18);
  final blobs = <(Offset, double)>[(centre, 10.5)];
  const count = 7;
  final turn = random.nextDouble();
  for (var i = 0; i < count; i++) {
    final angle = (i + turn) / count * 2 * pi;
    final distance = 8.5 + random.nextDouble() * 1.5;
    blobs.add((
      centre + Offset(cos(angle) * distance, sin(angle) * distance * 0.85),
      6.5 + random.nextDouble() * 2,
    ));
  }

  _drawBlobs(canvas, blobs, colors, highlightAbove: centre.dy + 2);

  // A few specks of leaves for texture.
  final speck = _fill(highlight);
  final dark = _fill(shadow);
  for (var i = 0; i < 14; i++) {
    final angle = random.nextDouble() * 2 * pi;
    final distance = random.nextDouble() * 13;
    final at = centre + Offset(cos(angle) * distance, sin(angle) * distance);
    canvas.drawCircle(at, 0.9, at.dy < centre.dy ? speck : dark);
  }

  return recorder.endRecording().toImageSync(width, height);
}

/// A pine of [tiers] stacked triangles, narrowing towards the top.
Image _pine({required int tiers, required int width, required int height}) {
  final (outline, shadow, base, highlight) = _pineColors;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final middle = width / 2;

  _drawGroundShadow(canvas, middle, height - 4, width * 0.8);
  _drawTrunk(
    canvas,
    middle,
    top: height - 14,
    bottom: height - 3,
    halfWidth: 2.5,
  );

  final crownBottom = height - 10.0;
  const crownTop = 2.0;
  final tierHeight = (crownBottom - crownTop) / (tiers + 1) * 2;
  for (var tier = 0; tier < tiers; tier++) {
    // Tier 0 is the widest, at the bottom. Later tiers overlap it.
    final fraction = tier / tiers;
    final bottom =
        crownBottom - fraction * (crownBottom - crownTop - tierHeight);
    final top = bottom - tierHeight;
    final halfWidth = (width / 2 - 1.5) * (1 - fraction * 0.55);

    Path triangle(double grow) => Path()
      ..moveTo(middle, top - grow)
      ..lineTo(middle + halfWidth + grow, bottom + grow * 0.5)
      ..lineTo(middle - halfWidth - grow, bottom + grow * 0.5)
      ..close();

    canvas
      ..drawPath(triangle(1.5), _fill(outline))
      ..drawPath(triangle(0), _fill(shadow))
      // The lit left side.
      ..drawPath(
        Path()
          ..moveTo(middle, top)
          ..lineTo(middle + halfWidth * 0.15, bottom - 2)
          ..lineTo(middle - halfWidth + 1, bottom - 1)
          ..close(),
        _fill(base),
      )
      ..drawPath(
        Path()
          ..moveTo(middle - 1, top + 3)
          ..lineTo(middle - halfWidth * 0.2, bottom - 3)
          ..lineTo(middle - halfWidth * 0.6, bottom - 2)
          ..close(),
        _fill(highlight),
      );
  }

  return recorder.endRecording().toImageSync(width, height);
}

void _drawGroundShadow(Canvas canvas, double x, double y, double width) {
  canvas.drawOval(
    Rect.fromCenter(center: Offset(x, y), width: width, height: width * 0.3),
    _fill(_groundShadow),
  );
}

/// A trunk that flares out at its roots, shaded on the right.
void _drawTrunk(
  Canvas canvas,
  double x, {
  required double top,
  required double bottom,
  required double halfWidth,
}) {
  final trunk = Path()
    ..moveTo(x - halfWidth, top)
    ..lineTo(x + halfWidth, top)
    ..lineTo(x + halfWidth, bottom - 3)
    ..lineTo(x + halfWidth + 2, bottom)
    ..lineTo(x - halfWidth - 2, bottom)
    ..lineTo(x - halfWidth, bottom - 3)
    ..close();
  canvas
    ..drawPath(trunk, _fill(_bark))
    ..drawRect(
      Rect.fromLTRB(x + halfWidth * 0.2, top, x + halfWidth, bottom - 1),
      _fill(_barkShade),
    );
}

/// Draws round [blobs] of leaves: an outline, then the shadowed blobs, then
/// their lit part up and to the left, then highlights on the blobs above
/// [highlightAbove].
void _drawBlobs(
  Canvas canvas,
  List<(Offset, double)> blobs,
  _Colors colors, {
  required double highlightAbove,
}) {
  final (outline, shadow, base, highlight) = colors;
  for (final (at, radius) in blobs) {
    canvas.drawCircle(at, radius + 1.5, _fill(outline));
  }
  for (final (at, radius) in blobs) {
    canvas.drawCircle(at, radius, _fill(shadow));
  }
  for (final (at, radius) in blobs) {
    canvas.drawCircle(at.translate(-1.2, -1.6), radius - 1.2, _fill(base));
  }
  for (final (at, radius) in blobs) {
    if (at.dy > highlightAbove) continue;
    canvas.drawCircle(
      at.translate(-radius * 0.3, -radius * 0.35),
      radius * 0.42,
      _fill(highlight),
    );
  }
}

const _stoneColors = (
  Color(0xFF2B2B31),
  Color(0xFF5D5D67),
  Color(0xFF9C9CA6),
  Color(0xFFC9C9D2),
);

/// Boulders side by side, each (width, height) in pixels, the tallest first.
Image _rocks(
  Random random,
  List<(double, double)> sizes, {
  bool mossy = false,
}) {
  const margin = 3.0;
  final width = sizes.fold(0.0, (sum, size) => sum + size.$1) + margin * 2;
  final height = sizes.first.$2 + margin * 2;
  final ground = height - margin;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  final rocks = <Rect>[];
  var left = margin;
  for (final (w, h) in sizes) {
    rocks.add(Rect.fromLTWH(left, ground - h, w, h));
    left += w - 1;
  }
  for (final rect in rocks) {
    _drawGroundShadow(canvas, rect.center.dx, ground - 1, rect.width + 4);
  }
  for (final rect in rocks) {
    _drawBoulder(canvas, rect, random, mossy: mossy);
  }
  return recorder.endRecording().toImageSync(width.ceil(), height.ceil());
}

/// A faceted boulder filling [rect], flat where it rests on the ground.
void _drawBoulder(
  Canvas canvas,
  Rect rect,
  Random random, {
  required bool mossy,
}) {
  final (outline, shadow, base, highlight) = _stoneColors;
  final centre = rect.center;

  // Corners around an ellipse, each pulled in or out a little.
  const corners = 9;
  final turn = random.nextDouble();
  final points = <Offset>[];
  for (var i = 0; i < corners; i++) {
    final angle = (i + turn) / corners * 2 * pi;
    final reach = 0.85 + random.nextDouble() * 0.2;
    points.add(
      Offset(
        centre.dx + cos(angle) * rect.width / 2 * reach,
        min(
          centre.dy + sin(angle) * rect.height / 2 * reach * 1.15,
          rect.bottom,
        ),
      ),
    );
  }

  /// The boulder's outline, scaled around its centre and shifted.
  Path shape(double scale, Offset shift) {
    final path = Path();
    for (final (i, point) in points.indexed) {
      final p = centre + (point - centre) * scale + shift;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  final body = shape(1, Offset.zero);
  canvas
    ..drawPath(
      body,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    )
    ..drawPath(body, _fill(shadow))
    ..save()
    ..clipPath(body)
    // The lit top, then the brightest facet.
    ..drawPath(
      shape(0.85, Offset(-rect.width * 0.08, -rect.height * 0.14)),
      _fill(base),
    )
    ..drawPath(
      shape(0.4, Offset(-rect.width * 0.18, -rect.height * 0.28)),
      _fill(highlight),
    );

  // A crack.
  final crack = centre + Offset(rect.width * 0.12, -rect.height * 0.25);
  canvas.drawPath(
    Path()
      ..moveTo(crack.dx, crack.dy)
      ..lineTo(crack.dx + 2, crack.dy + rect.height * 0.2)
      ..lineTo(crack.dx + 1, crack.dy + rect.height * 0.35),
    Paint()
      ..color = shadow
      ..style = PaintingStyle.stroke,
  );

  if (mossy) {
    // A flat patch on the lit top, with a few lighter tufts.
    final (dark, moss, light) = _mossColors;
    final patch = <Offset>[
      for (var i = 0; i < 4; i++)
        Offset(
          rect.left + rect.width * (0.22 + i * 0.13),
          rect.top + rect.height * (0.14 + random.nextDouble() * 0.12),
        ),
    ];
    for (final at in patch) {
      canvas.drawOval(
        Rect.fromCenter(center: at.translate(0, 0.8), width: 6, height: 3.5),
        _fill(dark),
      );
    }
    for (final at in patch) {
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 5, height: 2.8),
        _fill(moss),
      );
    }
    for (final at in patch.take(3)) {
      canvas.drawCircle(at.translate(-0.8, -0.6), 0.8, _fill(light));
    }
  }
  canvas.restore();
}

/// The shadow, base and highlight colour of moss on a boulder.
const _mossColors = (Color(0xFF3B7029), Color(0xFF5C9E36), Color(0xFF93C95A));

const _bushColors = (
  Color(0xFF1C4519),
  Color(0xFF2F6E28),
  Color(0xFF45913A),
  Color(0xFF6DB84E),
);

/// A round bush of a few leafy blobs. With [dots], a colour and its
/// highlight, it has berries or flowers.
Image _bush(Random random, {(Color, Color)? dots}) {
  const width = 24;
  const height = 19;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  _drawGroundShadow(canvas, width / 2, height - 3, 22);
  final blobs = <(Offset, double)>[
    for (final (x, y, radius) in const [
      (6.5, 11.0, 4.5),
      (17.5, 11.0, 4.5),
      (12.0, 12.0, 5.0),
      (9.0, 7.5, 4.5),
      (15.0, 7.5, 4.5),
    ])
      (
        Offset(x + random.nextDouble() - 0.5, y + random.nextDouble() - 0.5),
        radius + random.nextDouble() * 0.8,
      ),
  ];
  _drawBlobs(canvas, blobs, _bushColors, highlightAbove: 9);

  if (dots case (final color, final shine)) {
    // Spread over the bush, each a little off its place.
    for (final (x, y) in const [
      (7.0, 9.0),
      (12.0, 5.5),
      (17.0, 8.5),
      (10.0, 13.0),
      (15.5, 12.5),
    ]) {
      final at = Offset(
        x + random.nextDouble() * 2 - 1,
        y + random.nextDouble() * 2 - 1,
      );
      canvas
        ..drawCircle(at, 1.3, _fill(color))
        ..drawCircle(at.translate(-0.4, -0.4), 0.5, _fill(shine));
    }
  }
  return recorder.endRecording().toImageSync(width, height);
}
