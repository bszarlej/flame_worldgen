import 'package:flame/components.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:test/test.dart';

void main() {
  group('ChunkManager', () {
    final noise = PerlinNoise();
    const chunkSize = Vector2i(2, 2);
    const tileSize = Vector2i(16, 16);

    late ChunkManager manager;

    setUp(() {
      manager = ChunkManager(
        noise: noise,
        chunkSize: chunkSize,
        tileSize: tileSize,
        chunkCacheSize: 3,
      );
    });

    test('loads and unloads chunks correctly', () {
      final center = Vector2(0, 0);
      manager.updateVisibleChunks(center);

      final loaded = manager.loadedChunks;
      expect(loaded.length, greaterThan(0));

      final previousKeys = Set.of(loaded.keys);

      // Move far to force unload and load
      manager.updateVisibleChunks(Vector2(1000, 1000));

      // Some of the previous chunks should be unloaded now
      final newKeys = manager.loadedChunks.keys.toSet();
      expect(
        previousKeys.intersection(newKeys).length,
        lessThan(previousKeys.length),
      );
    });

    test('respects chunk cache size', () {
      for (int i = 0; i < 10; i++) {
        manager.updateVisibleChunks(Vector2(i * 100.0, 0));
      }

      expect(manager.totalCached, lessThanOrEqualTo(manager.chunkCacheSize));
    });
  });
}
