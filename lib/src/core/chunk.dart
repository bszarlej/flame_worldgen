import 'package:fast_noise/fast_noise.dart';
import 'package:flame/game.dart';

import '../math/vector2i.dart';

class Chunk {
  final Noise2 noise;
  final Vector2i chunkCoords;
  final Vector2i chunkSize;
  final Vector2i tileSize;

  final List<double> _heightMap;

  Chunk({
    required this.noise,
    required this.chunkCoords,
    required this.chunkSize,
    required this.tileSize,
  }) : _heightMap = List.filled(chunkSize.x * chunkSize.y, 0, growable: false) {
    _generateHeightMap();
  }

  Vector2i get chunkWorldSize =>
      Vector2i(chunkSize.x * tileSize.x, chunkSize.y * tileSize.y);

  List<double> get heightMap => _heightMap;

  Vector2i getGlobalTileCoords(int col, int row) {
    final worldPos = getTileWorldPosition(col, row);
    return Vector2i(
      (worldPos.x / tileSize.x).floor(),
      (worldPos.y / tileSize.y).floor(),
    );
  }

  double getNoise(int col, int row) {
    final index = row * chunkSize.x + col;
    return _heightMap[index];
  }

  Vector2 getTileWorldPosition(int col, int row) {
    return Vector2(
      (chunkCoords.x * chunkSize.x * tileSize.x + col * tileSize.x).toDouble(),
      (chunkCoords.y * chunkSize.y * tileSize.y + row * tileSize.y).toDouble(),
    );
  }

  void _generateHeightMap() {
    for (int col = 0; col < chunkSize.x; col++) {
      for (int row = 0; row < chunkSize.y; row++) {
        final globalPos = getTileWorldPosition(col, row);
        final index = row * chunkSize.x + col;
        _heightMap[index] = noise.getNoise2(
          globalPos.x.toDouble(),
          globalPos.y.toDouble(),
        );
      }
    }
  }
}
