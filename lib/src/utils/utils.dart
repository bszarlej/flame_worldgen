import 'package:flame/game.dart';

Vector2 chunkToWorldPosition(
  Vector2 chunkCoords,
  Vector2 tileCount,
  Vector2 tileSize,
) {
  return Vector2(
    chunkCoords.x * tileCount.x * tileSize.x,
    chunkCoords.y * tileCount.y * tileSize.y,
  );
}

Vector2 worldToChunkPosition(
  Vector2 worldPosition,
  Vector2 tileCount,
  Vector2 tileSize,
) {
  return Vector2(
    (worldPosition.x / (tileCount.x * tileSize.x)).floorToDouble(),
    (worldPosition.y / (tileCount.y * tileSize.y)).floorToDouble(),
  );
}
