import 'package:flame/components.dart';

import 'chunk_manager.dart';

typedef TileFactory =
    PositionComponent Function(Vector2 position, double noiseValue);

class ProceduralWorld2D extends World {
  final ChunkManager chunkManager;
  final TileFactory tileFactory;

  final Map<int, PositionComponent> _tiles = {};
  final Set<int> _visibleTiles = {};

  ProceduralWorld2D({required this.chunkManager, required this.tileFactory});

  void updateWorldView(Vector2 centerPosition) {
    chunkManager.updateVisibleChunks(centerPosition);
    _updateTiles();
  }

  void _updateTiles() {
    _visibleTiles.clear();

    for (final chunk in chunkManager.loadedChunks.values) {
      for (int x = 0; x < chunk.chunkSize.x; x++) {
        for (int y = 0; y < chunk.chunkSize.y; y++) {
          final tilePos = chunk.getTileWorldPosition(x, y);
          final globalCoords = chunk.getGlobalTileCoords(x, y);
          final key = globalCoords.toPackedKey();
          _visibleTiles.add(key);

          if (!_tiles.containsKey(key)) {
            final noiseValue = chunk.getNoise(x, y);
            final tile = tileFactory(tilePos.toVector2(), noiseValue);
            _tiles[key] = tile;
            add(tile);
          }
        }
      }
    }

    final toRemove = _tiles.keys
        .where((key) => !_visibleTiles.contains(key))
        .toList();
    for (final key in toRemove) {
      final tile = _tiles.remove(key);
      tile?.removeFromParent();
    }
  }
}
