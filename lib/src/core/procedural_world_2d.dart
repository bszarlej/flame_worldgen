import 'package:flame/components.dart';

import '../../flame_procedural_generation.dart';

typedef TileFactory =
    List<PositionComponent>? Function(Vector2 position, double noiseValue);

class ProceduralWorld2D extends World {
  final ChunkManager chunkManager;
  final TileFactory tileFactory;

  final Map<int, List<PositionComponent>> _tiles = {};
  final Set<int> _visibleTiles = {};

  ProceduralWorld2D({required this.chunkManager, required this.tileFactory});

  void updateWorldView(Vector2 center) {
    chunkManager.updateVisibleChunks(center);
    _updateTiles();
  }

  void _updateTiles() {
    _visibleTiles.clear();

    for (final chunk in chunkManager.loadedChunks.values) {
      for (int x = 0; x < chunk.chunkSize.x; x++) {
        for (int y = 0; y < chunk.chunkSize.y; y++) {
          final globalCoords = chunk.getGlobalTileCoords(x, y);
          final key = packKey(globalCoords.x, globalCoords.y);
          _visibleTiles.add(key);

          if (!_tiles.containsKey(key)) {
            final noiseValue = chunk.getNoise(x, y);
            final tilePos = chunk.getTileWorldPosition(x, y);
            final tiles = tileFactory(
              Vector2(tilePos.x.toDouble(), tilePos.y.toDouble()),
              noiseValue,
            );
            if (tiles != null) {
              _tiles[key] = tiles;
              addAll(tiles);
            }
          }
        }
      }
    }

    final toRemove = _tiles.keys
        .where((key) => !_visibleTiles.contains(key))
        .toList();
    for (final key in toRemove) {
      final tiles = _tiles.remove(key);
      tiles?.forEach((tile) => tile.removeFromParent());
    }
  }
}
