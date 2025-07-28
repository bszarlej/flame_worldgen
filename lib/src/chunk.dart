import 'package:fast_noise/fast_noise.dart';
import 'package:flame/components.dart';

class Chunk {
  final Noise2 noise;
  final Vector2 chunkCoords;
  final Vector2 tileCount;
  final Vector2 tileSize;

  late final List<double> _noiseValues;

  Chunk({
    required this.noise,
    required this.chunkCoords,
    required this.tileCount,
    required this.tileSize,
  }) : _noiseValues = List.filled(
         (tileCount.x * tileCount.y).toInt(),
         0,
         growable: false,
       ) {
    _generateNoiseValues();
  }

  Vector2 getTileWorldPosition(int x, int y) {
    return Vector2(
      chunkCoords.x * tileCount.x * tileSize.x + x * tileSize.x,
      chunkCoords.y * tileCount.y * tileSize.y + y * tileSize.y,
    );
  }

  double getNoiseValue(int x, int y) {
    final index = y * tileCount.x.toInt() + x;
    return _noiseValues[index];
  }

  void _generateNoiseValues() {
    for (int x = 0; x < tileCount.x; x++) {
      for (int y = 0; y < tileCount.y; y++) {
        final globalPos = getTileWorldPosition(x, y);
        final index = y * tileCount.x.toInt() + x;
        _noiseValues[index] = noise.getNoise2(globalPos.x, globalPos.y);
      }
    }
  }
}
