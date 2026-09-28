import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_worldgen/flame_worldgen.dart';

import 'object_images.dart';

// The objects scattered over the world, drawn in code like the tiles.

/// Components the player can't walk through.
mixin Obstacle on PositionComponent {}

/// Components drawn in front of the ones whose bottom edge is higher up, so
/// the player can walk behind a tree's crown.
mixin SortByY on PositionComponent {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sortByY();
  }

  /// Updates the priority after the component moved.
  void sortByY() => priority = positionOfAnchor(Anchor.bottomCenter).y.floor();
}

/// An object drawn as one of [images], picked by its spot.
class Prop extends PositionComponent with SortByY {
  Prop(ScatterSpot spot, List<Image> images)
    : _image = images[spot.random.nextInt(images.length)],
      super(position: spot.position, anchor: Anchor.bottomCenter) {
    size = Vector2(_image.width.toDouble(), _image.height.toDouble());
  }

  final Image _image;

  /// Sharp pixels when zoomed in, like the tiles.
  static final _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  void render(Canvas canvas) => canvas.drawImage(_image, Offset.zero, _paint);
}

/// A tree. Its trunk blocks the player.
class Tree extends Prop with Obstacle {
  Tree(ScatterSpot spot) : super(spot, treeImages);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      RectangleHitbox(
        position: Vector2(size.x / 2 - 3, size.y - 7),
        size: Vector2(6, 4),
        collisionType: CollisionType.passive,
      ),
    );
  }
}

/// A boulder in the mountains.
class Rock extends Prop {
  Rock(ScatterSpot spot) : super(spot, rockImages);
}

/// A bush in the plains, which the player can walk through.
class Bush extends Prop {
  Bush(ScatterSpot spot) : super(spot, bushImages);
}
