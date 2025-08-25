import 'package:fast_noise/fast_noise.dart';

import '../utils/utils.dart';

class Chunk {
  final Noise2 noise;
  final Point chunkCoords;
  final Point chunkSize;
  final Point tileSize;

  final List<double> _heightMap;

  Chunk({
    required this.noise,
    required this.chunkCoords,
    required this.chunkSize,
    required this.tileSize,
  }) : _heightMap = List.filled(chunkSize.x * chunkSize.y, 0, growable: false) {
    _generateHeightMap();
  }

  Point get chunkWorldSize =>
      (x: chunkSize.x * tileSize.x, y: chunkSize.y * tileSize.y);

  List<double> get heightMap => _heightMap;

  Point getGlobalTileCoords(int col, int row) {
    final worldPos = getTileWorldPosition(col, row);
    return (
      x: (worldPos.x / tileSize.x).floor(),
      y: (worldPos.y / tileSize.y).floor(),
    );
  }

  double getNoise(int col, int row) {
    final index = row * chunkSize.x + col;
    return _heightMap[index];
  }

  Point getTileWorldPosition(int col, int row) {
    return (
      x: (chunkCoords.x * chunkSize.x * tileSize.x + col * tileSize.x),
      y: (chunkCoords.y * chunkSize.y * tileSize.y + row * tileSize.y),
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
