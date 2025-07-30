import 'package:fast_noise/fast_noise.dart';

import '../utils/utils.dart';

class Chunk {
  final Noise2 noise;
  final Point chunkCoords;
  final Point chunkSize;
  final Point tileSize;

  late final List<double> _heightMap;

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

  Point getGlobalTileCoords(int x, int y) {
    final worldPos = getTileWorldPosition(x, y);
    return (
      x: (worldPos.x / tileSize.x).floor(),
      y: (worldPos.y / tileSize.y).floor(),
    );
  }

  double getNoise(int x, int y) {
    final index = y * chunkSize.x + x;
    return _heightMap[index];
  }

  Point getTileWorldPosition(int x, int y) {
    return (
      x: (chunkCoords.x * chunkSize.x * tileSize.x + x * tileSize.x),
      y: (chunkCoords.y * chunkSize.y * tileSize.y + y * tileSize.y),
    );
  }

  void _generateHeightMap() {
    for (int x = 0; x < chunkSize.x; x++) {
      for (int y = 0; y < chunkSize.y; y++) {
        final globalPos = getTileWorldPosition(x, y);
        final index = y * chunkSize.x + x;
        _heightMap[index] = noise.getNoise2(
          globalPos.x.toDouble(),
          globalPos.y.toDouble(),
        );
      }
    }
  }
}
