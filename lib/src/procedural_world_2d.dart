import 'package:flame/components.dart';

import 'chunk_manager.dart';

typedef TileFactory =
    PositionComponent Function(Vector2 position, double noiseValue);

class ProceduralWorld2D extends World {
  final ChunkManager chunkManager;
  final TileFactory tileFactory;

  final Map<String, PositionComponent> _tiles = {};
  final Set<String> _visibleTiles = {};

  final List<PositionComponent> _objectComponents = [];

  ProceduralWorld2D({required this.chunkManager, required this.tileFactory});

  void updateWorldView(Vector2 centerPosition) {
    chunkManager.updateVisibleChunks(centerPosition);
    _updateTiles();
  }

  void _updateTiles() {
    _visibleTiles.clear();

    for (final chunk in chunkManager.loadedChunks.values) {
      for (int x = 0; x < chunk.tileCount.x; x++) {
        for (int y = 0; y < chunk.tileCount.y; y++) {
          final tilePos = chunk.getTileWorldPosition(x, y);
          final key = '${tilePos.x.toInt()},${tilePos.y.toInt()}';
          _visibleTiles.add(key);

          if (!_tiles.containsKey(key)) {
            final noiseValue = chunk.getNoiseValue(x, y);
            final tile = tileFactory(tilePos, noiseValue);
            _tiles[key] = tile;
            add(tile);
          }
        }
      }
    }

    // Remove tiles that are no longer visible
    final toRemove = _tiles.keys
        .where((key) => !_visibleTiles.contains(key))
        .toList();
    for (final key in toRemove) {
      final tile = _tiles.remove(key);
      tile?.removeFromParent();
    }
  }

  void addObject(PositionComponent object) {
    _objectComponents.add(object);
    add(object); // Also add to component tree
  }

  void removeObject(PositionComponent object) {
    _objectComponents.remove(object);
    object.removeFromParent();
  }
}
