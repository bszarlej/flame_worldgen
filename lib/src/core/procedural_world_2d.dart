import 'package:flame/components.dart';

import '../math/vector2i.dart';
import 'chunk.dart';
import 'chunk_manager.dart';

typedef TileFactory =
    List<PositionComponent>? Function(Vector2 position, double noiseValue);

class ProceduralWorld2D extends World with HasGameReference {
  ChunkManager? chunkManager;
  TileFactory? tileFactory;

  final Map<Vector2i, List<PositionComponent>> _tiles = {};
  final Set<Vector2i> _visibleTiles = {};

  ProceduralWorld2D({this.chunkManager, this.tileFactory});

  @override
  void update(double dt) {
    super.update(dt);
    chunkManager?.updateVisibleChunks(game.camera.viewfinder.position);
    _updateTiles();
  }

  void _updateTiles() {
    _visibleTiles.clear();

    for (final chunk in chunkManager?.loadedChunks.values ?? <Chunk>[]) {
      for (int x = 0; x < chunk.chunkSize.x; x++) {
        for (int y = 0; y < chunk.chunkSize.y; y++) {
          final key = chunk.getGlobalTileCoords(x, y);
          _visibleTiles.add(key);

          if (!_tiles.containsKey(key)) {
            final noiseValue = chunk.getNoise(x, y);
            final tilePos = chunk.getTileWorldPosition(x, y);
            final tiles = tileFactory?.call(
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
