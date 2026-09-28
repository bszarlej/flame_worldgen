import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_worldgen/flame_worldgen.dart';

/// A small walker that can't enter solid tiles.
class Player extends PositionComponent with CollisionCallbacks {
  Player({super.position})
    : super(size: Vector2.all(10), anchor: Anchor.center);

  static const _walkSpeed = 100.0;
  static const _runSpeed = 400.0;

  /// Where the player wants to go. Doesn't need to be normalized.
  final direction = Vector2.zero();

  /// Whether the player moves at running speed.
  var running = false;

  /// The position before this frame's move.
  final _previous = Vector2.zero();

  final _fill = Paint()..color = const Color(0xFFE8463C);
  final _outline = Paint()
    ..color = const Color(0xFF3A1210)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    _previous.setFrom(position);
    if (!direction.isZero()) {
      final speed = running ? _runSpeed : _walkSpeed;
      position += direction.normalized() * speed * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final centre = (size / 2).toOffset();
    canvas
      ..drawCircle(centre, size.x / 2, _fill)
      ..drawCircle(centre, size.x / 2, _outline);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is! SolidTiles) return;
    for (final wall in other.children.whereType<RectangleHitbox>()) {
      _pushOutOf(wall.toAbsoluteRect());
    }
  }

  /// Moves the player out of [wall], back the way it came.
  ///
  /// Pushing out along the axis the player entered from, rather than the
  /// one with the smallest overlap, lets it slide along walls without
  /// catching on the seams between neighbouring hitboxes.
  void _pushOutOf(Rect wall) {
    final me = toAbsoluteRect();
    if (!me.overlaps(wall)) return;
    final moved = position - _previous;
    final before = me.shift(-moved.toOffset());
    // Positions are 32-bit floats, so after being pushed out, the player can
    // still overlap the wall by a rounding error.
    const tolerance = 0.01;
    final cameFromTheSide =
        before.bottom > wall.top + tolerance &&
        before.top < wall.bottom - tolerance;
    if (cameFromTheSide && moved.x != 0) {
      position.x += moved.x > 0 ? wall.left - me.right : wall.right - me.left;
    } else if (moved.y != 0) {
      position.y += moved.y > 0 ? wall.top - me.bottom : wall.bottom - me.top;
    }
  }
}
