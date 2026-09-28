import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../core/coords.dart';
import '../core/tile_type.dart';

/// The hitboxes of one solid tile [type] in one [chunk] of a `ProceduralMap`
/// with `collision: true`.
///
/// This is the `other` component your collision callbacks receive when they
/// touch solid tiles:
///
/// ```dart
/// @override
/// void onCollisionStart(Set<Vector2> points, PositionComponent other) {
///   super.onCollisionStart(points, other);
///   if (other is SolidTiles) {
///     if (other.type.hasTag('liquid')) splash();
///     stop();
///   }
/// }
/// ```
///
/// The map adds these as its children when a chunk loads and removes them
/// when it unloads. Neighbouring tiles of the same type are merged into as
/// few passive [RectangleHitbox]es as possible, but never across chunk
/// borders. The hitboxes are solid, so a component that's entirely inside
/// one still collides with it.
class SolidTiles extends PositionComponent {
  /// Creates the hitboxes of [type] in [chunk], whose top-left corner is at
  /// [position] and which is [size] pixels large. Each of [rects] becomes a
  /// passive, solid [RectangleHitbox], relative to [position].
  SolidTiles({
    required this.type,
    required this.chunk,
    required Vector2 super.position,
    required Vector2 super.size,
    required Iterable<Rect> rects,
  }) : super(
         children: [
           for (final rect in rects)
             RectangleHitbox(
               position: Vector2(rect.left, rect.top),
               size: Vector2(rect.width, rect.height),
               collisionType: CollisionType.passive,
               isSolid: true,
             ),
         ],
       );

  /// The tile type of every hitbox.
  final TileType type;

  /// The chunk the hitboxes belong to.
  final ChunkCoord chunk;

  @override
  String toString() => 'SolidTiles(${type.name}, $chunk)';
}
