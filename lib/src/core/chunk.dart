import 'package:fast_noise/fast_noise.dart';

import '../math/vector2i.dart';

class Chunk {
  final Noise2 noise;
  final Vector2i chunkCoords;
  final Vector2i chunkSize;
  final Vector2i tileSize;

  late final List<double> _heightMap;

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

  Vector2i getGlobalTileCoords(int x, int y) {
    final worldPos = getTileWorldPosition(x, y);
    return Vector2i(
      (worldPos.x / tileSize.x).floor(),
      (worldPos.y / tileSize.y).floor(),
    );
  }

  double getNoise(int x, int y) {
    final index = y * chunkSize.x + x;
    return _heightMap[index];
  }

  Vector2i getTileWorldPosition(int x, int y) {
    return Vector2i(
      (chunkCoords.x * chunkSize.x * tileSize.x + x * tileSize.x),
      (chunkCoords.y * chunkSize.y * tileSize.y + y * tileSize.y),
    );
  }

  void _generateHeightMap() {
    for (int x = 0; x < chunkSize.x; x++) {
      for (int y = 0; y < chunkSize.y; y++) {
        final globalPos = getTileWorldPosition(x, y).toVector2();
        final index = y * chunkSize.x + x;
        _heightMap[index] = noise.getNoise2(globalPos.x, globalPos.y);
      }
    }
  }
}
