import 'package:flame/components.dart';

class Chunk {
  final Vector2 position;
  final Vector2 tileCount;
  final Vector2 tileSize;

  Chunk({
    required this.position,
    required this.tileCount,
    required this.tileSize,
  });

  Vector2 getGlobalTilePosition(int x, int y) {
    return Vector2(
      position.x * tileCount.x * tileSize.x + x * tileSize.x,
      position.y * tileCount.y * tileSize.y + y * tileSize.y,
    );
  }

  @override
  String toString() {
    return 'Chunk at position: $position';
  }
}
