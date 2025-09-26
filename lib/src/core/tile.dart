import 'dart:math';

import 'package:flame/components.dart';

import '../math/vector2i.dart';

class Tile {
  final double noise;
  final Vector2i globalCoords;
  final Vector2i localCoords;
  final Vector2i size;
  final Vector2 position;

  Tile({
    required this.noise,
    required this.globalCoords,
    required this.localCoords,
    required this.size,
    required this.position,
  });

  Vector2 getRandomPosition([Random? rng]) {
    final r = rng ?? Random();
    return Vector2(
      r.nextDouble() * size.x + position.x,
      r.nextDouble() * size.y + position.y,
    );
  }
}
