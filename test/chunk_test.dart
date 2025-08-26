import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:test/test.dart';

void main() {
  group('Chunk', () {
    final noise = PerlinNoise();

    test('generates consistent height map', () {
      final chunk = Chunk(
        noise: noise,
        chunkCoords: const Vector2i(0, 0),
        chunkSize: const Vector2i(4, 4),
        tileSize: const Vector2i(1, 1),
      );

      expect(chunk.heightMap.length, equals(16));
      final value = chunk.getNoise(2, 3);
      expect(value, isA<double>());
    });

    test('returns correct world and global tile coordinates', () {
      final chunk = Chunk(
        noise: noise,
        chunkCoords: const Vector2i(1, 1),
        chunkSize: const Vector2i(2, 2),
        tileSize: const Vector2i(16, 16),
      );

      final worldPos = chunk.getTileWorldPosition(1, 1);
      expect(worldPos, equals(const (x: 48, y: 48)));

      final global = chunk.getGlobalTileCoords(1, 1);
      expect(global, equals(const (x: 3, y: 3)));
    });
  });
}
