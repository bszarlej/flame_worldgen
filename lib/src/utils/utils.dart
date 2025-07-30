import 'package:flame/game.dart';

typedef Point = ({int x, int y});

Vector2 chunkToWorldPosition(Vector2 chunkCoords, Point chunkWorldSize) {
  return Vector2(
    chunkCoords.x * chunkWorldSize.x,
    chunkCoords.y * chunkWorldSize.y,
  );
}

Vector2 worldToChunkPosition(Vector2 worldPosition, Point chunkWorldSize) {
  return Vector2(
    worldPosition.x / chunkWorldSize.x,
    worldPosition.y / chunkWorldSize.y,
  );
}

Vector2 tileToWorldPosition(Vector2 tileCoords, Point tileSize) {
  return Vector2(tileCoords.x * tileSize.x, tileCoords.y * tileSize.y);
}

Vector2 worldToTilePosition(Vector2 worldPosition, Point tileSize) {
  return Vector2(worldPosition.x / tileSize.x, worldPosition.y / tileSize.y);
}

int packKey(int x, int y) {
  return (x << 32) | (y & 0xFFFFFFFF);
}

Point unpackKey(int key) {
  final x = key >> 32;
  final y = key & 0xFFFFFFFF;
  return (x: x, y: y >= 0x80000000 ? y - 0x100000000 : y);
}
