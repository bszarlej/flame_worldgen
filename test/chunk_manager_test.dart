import 'package:flame/components.dart';
import 'package:flame_procedural_generation/flame_procedural_generation.dart';
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
      expect(worldPos, equals(const Vector2i(48, 48)));

      final global = chunk.getGlobalTileCoords(1, 1);
      expect(global, equals(const Vector2i(3, 3)));
    });
  });

  group('ChunkManager', () {
    final noise = PerlinNoise();
    final chunkSize = const Vector2i(2, 2);
    final tileSize = const Vector2i(16, 16);

    late ChunkManager manager;

    setUp(() {
      manager = ChunkManager(
        noise: noise,
        chunkSize: chunkSize,
        tileSize: tileSize,
        chunkCacheSize: 3,
        chunkLoadLimitPerFrame: 5,
        chunkUnloadLimitPerFrame: 5,
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

    test('chunk loading is queued and capped per frame', () {
      manager.chunkLoadLimitPerFrame = 1;
      manager.updateVisibleChunks(Vector2(0, 0));

      expect(manager.queuedLoads + manager.loadedChunks.length, greaterThan(1));
      expect(manager.loadedChunks.length, lessThanOrEqualTo(1));
    });

    test('chunksToLoad is cleared when out of radius', () {
      manager.updateVisibleChunks(Vector2(0, 0));
      final preQueued = manager.queuedLoads;

      // Move far out to unload queued
      manager.updateVisibleChunks(Vector2(5000, 5000));
      expect(manager.queuedLoads, lessThanOrEqualTo(preQueued));
    });
  });

  group('Utility', () {
    test('pack and unpack key round trip', () {
      final x = 1234;
      final y = -5678;
      final packed = packKey(x, y);
      final (ux, uy) = unpackKey(packed);
      expect(ux, equals(x));
      expect(uy, equals(y));
    });

    test('world <-> chunk conversion is reversible', () {
      final chunkSize = const Vector2i(32, 32);
      final worldPos = Vector2(160, 64);
      final chunkPos = worldToChunkPosition(worldPos, chunkSize);
      final result = chunkToWorldPosition(chunkPos, chunkSize);

      expect(result.x, closeTo(worldPos.x, 1e-6));
      expect(result.y, closeTo(worldPos.y, 1e-6));
    });
  });
}
