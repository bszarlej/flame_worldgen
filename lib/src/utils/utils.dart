import 'package:flame/game.dart';

import '../math/vector2i.dart';

/// Converts chunk coordinates to world-space position.
///
/// Each chunk coordinate is scaled by the full [chunkWorldSize].
///
/// Example:
/// ```dart
/// final worldPos = chunkToWorldPosition(Vector2(2, 3), Vector2i(32, 32));
/// // worldPos = (64, 96)
/// ```
Vector2 chunkToWorldPosition(Vector2 chunkCoords, Vector2i chunkWorldSize) {
  return Vector2(
    chunkCoords.x * chunkWorldSize.x,
    chunkCoords.y * chunkWorldSize.y,
  );
}

/// Converts world-space position into chunk coordinates.
///
/// Divides the world position by [chunkWorldSize] to determine
/// which chunk the position lies in.
///
/// Example:
/// ```dart
/// final chunkPos = worldToChunkPosition(Vector2(75, 40), Vector2i(32, 32));
/// // chunkPos = (2.34, 1.25)
/// ```
Vector2 worldToChunkPosition(Vector2 worldPosition, Vector2i chunkWorldSize) {
  return Vector2(
    worldPosition.x / chunkWorldSize.x,
    worldPosition.y / chunkWorldSize.y,
  );
}

/// Converts tile coordinates into world-space position.
///
/// Each tile coordinate is scaled by the size of a single tile [tileSize].
///
/// Example:
/// ```dart
/// final worldPos = tileToWorldPosition(Vector2(5, 10), Vector2i(16, 16));
/// // worldPos = (80, 160)
/// ```
Vector2 tileToWorldPosition(Vector2 tileCoords, Vector2i tileSize) {
  return Vector2(tileCoords.x * tileSize.x, tileCoords.y * tileSize.y);
}

/// Converts world-space position into tile coordinates.
///
/// Divides the world position by [tileSize] to determine
/// which tile the position lies in.
///
/// Example:
/// ```dart
/// final tilePos = worldToTilePosition(Vector2(48, 32), Vector2i(16, 16));
/// // tilePos = (3.0, 2.0)
/// ```
Vector2 worldToTilePosition(Vector2 worldPosition, Vector2i tileSize) {
  return Vector2(worldPosition.x / tileSize.x, worldPosition.y / tileSize.y);
}
