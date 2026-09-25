import '../hash.dart';
import 'gradients.dart';

/// (√3 - 1) / 2, skews the input onto the simplex grid.
const _f2 = 0.3660254037844386;

/// (3 - √3) / 6, unskews back.
const _g2 = 0.21132486540518713;

/// Scales the raw result to [-1, 1].
///
/// This is 1 / 0.0100802047028114, the largest possible raw value: every
/// gradient points at the sample, at the midpoint of a simplex edge. It was
/// found by numeric search.
const _scale = 99.20433458271864;

/// 2D simplex noise at ([x], [y]) for [seed], in the range [-1, 1].
double simplex2(double x, double y, int seed) {
  final s = (x + y) * _f2;
  final i = (x + s).floor();
  final j = (y + s).floor();
  final t = (i + j) * _g2;
  final x0 = x - (i - t);
  final y0 = y - (j - t);

  // Which of the two triangles in the skewed cell contains the point.
  final i1 = x0 > y0 ? 1 : 0;
  final j1 = 1 - i1;

  final x1 = x0 - i1 + _g2;
  final y1 = y0 - j1 + _g2;
  final x2 = x0 - 1 + 2 * _g2;
  final y2 = y0 - 1 + 2 * _g2;

  final n0 = _corner(i, j, x0, y0, seed);
  final n1 = _corner(i + i1, j + j1, x1, y1, seed);
  final n2 = _corner(i + 1, j + 1, x2, y2, seed);
  return ((n0 + n1 + n2) * _scale).clamp(-1.0, 1.0);
}

double _corner(int i, int j, double x, double y, int seed) {
  var t = 0.5 - x * x - y * y;
  if (t <= 0) return 0;
  t *= t;
  return t * t * gradientDot(hash2(i, j, seed), x, y);
}
