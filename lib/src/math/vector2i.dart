import 'dart:math' as math;

import 'package:flame/game.dart' show Vector2;

/// A simple integer vector class for 2D coordinates.
class Vector2i implements Comparable<Vector2i> {
  final int x;
  final int y;

  const Vector2i(this.x, this.y);

  /// Zero vector (0,0)
  static const zero = Vector2i(0, 0);

  /// One vector (1,1)
  static const one = Vector2i(1, 1);

  /// Copy with optional overrides
  Vector2i copyWith({int? x, int? y}) => Vector2i(x ?? this.x, y ?? this.y);

  /// Add another Vector2i
  Vector2i operator +(Vector2i other) => Vector2i(x + other.x, y + other.y);

  /// Subtract another Vector2i
  Vector2i operator -(Vector2i other) => Vector2i(x - other.x, y - other.y);

  /// Multiply by scalar or another Vector2i (element-wise)
  Vector2i operator *(Object other) {
    if (other is int) return Vector2i(x * other, y * other);
    if (other is Vector2i) return Vector2i(x * other.x, y * other.y);
    throw ArgumentError('Can only multiply by int or Vector2i');
  }

  /// Divide by scalar or another Vector2i (integer division)
  Vector2i operator /(Object other) {
    if (other is int) return Vector2i(x ~/ other, y ~/ other);
    if (other is Vector2i) return Vector2i(x ~/ other.x, y ~/ other.y);
    throw ArgumentError('Can only divide by int or Vector2i');
  }

  /// Modulo with scalar or another Vector2i
  Vector2i operator %(Object other) {
    if (other is int) return Vector2i(x % other, y % other);
    if (other is Vector2i) return Vector2i(x % other.x, y % other.y);
    throw ArgumentError('Can only modulo with int or Vector2i');
  }

  /// Negation
  Vector2i operator -() => Vector2i(-x, -y);

  /// Equality check
  @override
  bool operator ==(Object other) =>
      other is Vector2i && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  /// Compare by y first, then x (like row-major ordering)
  @override
  int compareTo(Vector2i other) {
    if (y == other.y) return x.compareTo(other.x);
    return y.compareTo(other.y);
  }

  /// Absolute value
  Vector2i abs() => Vector2i(x.abs(), y.abs());

  /// Manhattan distance
  int manhattanDistance(Vector2i other) =>
      (x - other.x).abs() + (y - other.y).abs();

  /// Euclidean distance (int rounded)
  double distanceTo(Vector2i other) =>
      math.sqrt(math.pow((x - other.x), 2) + math.pow((y - other.y), 2));

  /// Clamp values between min and max
  Vector2i clamp(Vector2i min, Vector2i max) =>
      Vector2i(x.clamp(min.x, max.x), y.clamp(min.y, max.y));

  /// Convert to Vector2 (float)
  Vector2 toVector2() => Vector2(x.toDouble(), y.toDouble());

  @override
  String toString() => 'Vector2i($x, $y)';
}
