import 'package:flame_procedural_generation/flame_procedural_generation.dart';
import 'package:test/test.dart';

void main() {
  group('Chunk', () {
    final noise = PerlinNoise();

    test('generates consistent height map', () {
      final chunk = Chunk(
        noise: noise,
        chunkCoords: const (x: 0, y: 0),
        chunkSize: const (x: 4, y: 4),
        tileSize: const (x: 1, y: 1),
      );

      expect(chunk.heightMap.length, equals(16));
      final value = chunk.getNoise(2, 3);
      expect(value, isA<double>());
    });

    test('returns correct world and global tile coordinates', () {
      final chunk = Chunk(
        noise: noise,
        chunkCoords: const (x: 1, y: 1),
        chunkSize: const (x: 2, y: 2),
        tileSize: const (x: 16, y: 16),
      );

      final worldPos = chunk.getTileWorldPosition(1, 1);
      expect(worldPos, equals(const (x: 48, y: 48)));

      final global = chunk.getGlobalTileCoords(1, 1);
      expect(global, equals(const (x: 3, y: 3)));
    });
  });
}
