import 'package:flame/components.dart';

import '../utils/utils.dart';

class Vector2i {
  final int x;
  final int y;

  const Vector2i(this.x, this.y);

  factory Vector2i.fromPackedKey(int key) {
    final (x, y) = unpackKey(key);
    return Vector2i(x, y);
  }

  factory Vector2i.fromVector2(Vector2 vec2) {
    return Vector2i(vec2.x.floor(), vec2.y.floor());
  }

  @override
  int get hashCode => Object.hash(x, y);

  Vector2i operator *(int scalar) => Vector2i(x * scalar, y * scalar);

  Vector2i operator +(Vector2i other) => Vector2i(x + other.x, y + other.y);

  Vector2i operator -(Vector2i other) => Vector2i(x - other.x, y - other.y);

  Vector2i operator ~/(int scalar) => Vector2i(x ~/ scalar, y ~/ scalar);

  @override
  bool operator ==(Object other) =>
      other is Vector2i && x == other.x && y == other.y;

  @override
  String toString() => 'Vector2i($x, $y)';

  int toPackedKey() => packKey(x, y);

  Vector2 toVector2() => Vector2(x.toDouble(), y.toDouble());
}
