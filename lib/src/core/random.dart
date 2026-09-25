import 'dart:math';

import 'hash.dart';

const _twoPow32 = 4294967296;
const _twoPow26 = 67108864;
const _twoPow53 = 9007199254740992;

/// A [Random] that produces the same sequence on every platform.
///
/// `dart:math`'s `Random(seed)` doesn't guarantee that its sequence is the
/// same on native and on the web. This one is counter-based: the n-th value
/// is `hash1(n, seed)`.
class WorldRandom implements Random {
  /// Creates a generator whose sequence is determined by [seed].
  WorldRandom(int seed) : _seed = seed;

  final int _seed;
  int _position = 0;

  int _next() => hash1(_position++, _seed);

  /// Returns a random integer in the range `0` to [max], exclusive.
  ///
  /// [max] must be between 1 and 2^32, like in `dart:math`.
  @override
  int nextInt(int max) {
    if (max <= 0 || max > _twoPow32) {
      throw RangeError.range(max, 1, _twoPow32, 'max');
    }
    // Rejection sampling avoids a bias towards small values.
    final limit = _twoPow32 - _twoPow32 % max;
    int value;
    do {
      value = _next();
    } while (value >= limit);
    return value % max;
  }

  /// Returns a random double in the range `0.0` to `1.0`, exclusive, with 53
  /// bits of precision.
  @override
  double nextDouble() {
    final high = _next() >>> 5;
    final low = _next() >>> 6;
    return (high * _twoPow26 + low) / _twoPow53;
  }

  /// Returns a random boolean.
  @override
  bool nextBool() => _next() >>> 31 == 1;
}
