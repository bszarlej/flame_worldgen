import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_worldgen/flame_worldgen.dart';

import 'y_priority.dart';

enum PropType {
  tree(anchor: Anchor(0.5, 0.96), srcRect: Rect.fromLTWH(16, 0, 32, 32)),
  narrowTree(anchor: Anchor(0.5, 0.83), srcRect: Rect.fromLTWH(0, 0, 16, 32)),
  fruitTree(anchor: Anchor(0.5, 0.96), srcRect: Rect.fromLTWH(48, 0, 32, 32)),
  bush(anchor: Anchor(0.5, 0.94), srcRect: Rect.fromLTWH(16, 48, 16, 16)),
  fruitBush(anchor: Anchor(0.5, 0.94), srcRect: Rect.fromLTWH(0, 48, 16, 16)),
  sunFlower(
    anchor: Anchor(0.5, 0.938),
    srcRect: Rect.fromLTWH(128, 32, 16, 32),
  );

  final Anchor anchor;
  final Rect srcRect;

  const PropType({required this.anchor, required this.srcRect});

  factory PropType.fromRect(Rect srcRect) {
    return PropType.values.firstWhere((type) => type.srcRect == srcRect);
  }

  double calculateWeight(double noise, Vector2i worldPos) => switch (this) {
    PropType.tree => 0.55,
    PropType.narrowTree => 0.27,
    PropType.fruitTree => 0.02,
    PropType.bush => 0.1,
    PropType.fruitBush => 0.01,
    PropType.sunFlower => 0.05,
  };

  WeightedSprite toWeightedSprite() =>
      WeightedSprite.single(srcRect, weight: calculateWeight);
}

class Prop extends PositionComponent with HasGameReference, YPriority {
  late final Sprite sprite;
  final PropType type;

  Prop({required this.type, super.position})
    : super(size: type.srcRect.size.toVector2(), anchor: type.anchor);

  @override
  bool get canMove => false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    sprite = Sprite(
      game.images.fromCache('props.png'),
      srcPosition: type.srcRect.topLeft.toVector2(),
      srcSize: size,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    sprite.render(canvas);
  }
}
