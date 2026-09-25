import '../hash.dart';
import 'gradients.dart';

/// Scales the raw result to [-1, 1].
///
/// With unit gradients, 2D Perlin noise peaks at √2 / 2 in the middle of a
/// cell when every gradient points at the sample.
const _scale = 1.4142135623730951;

/// 2D Perlin noise at ([x], [y]) for [seed], in the range [-1, 1].
double perlin2(double x, double y, int seed) {
  final x0 = x.floor();
  final y0 = y.floor();
  final fx = x - x0;
  final fy = y - y0;

  final g00 = gradientDot(hash2(x0, y0, seed), fx, fy);
  final g10 = gradientDot(hash2(x0 + 1, y0, seed), fx - 1, fy);
  final g01 = gradientDot(hash2(x0, y0 + 1, seed), fx, fy - 1);
  final g11 = gradientDot(hash2(x0 + 1, y0 + 1, seed), fx - 1, fy - 1);

  final u = _fade(fx);
  final v = _fade(fy);
  final top = g00 + u * (g10 - g00);
  final bottom = g01 + u * (g11 - g01);
  return ((top + v * (bottom - top)) * _scale).clamp(-1.0, 1.0);
}

/// 6t⁵ - 15t⁴ + 10t³, which has zero first and second derivatives at 0 and 1
/// so cell borders don't show.
double _fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);
