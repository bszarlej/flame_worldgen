import 'package:flame/game.dart';
import 'package:flame_procedural_generation/src/chunk.dart';

class ChunkManager {
  final Vector2 tileCount;
  final Vector2 tileSize;
  final int viewDistance;
  final int maxCachedChunks;
  Map<String, Chunk> loadedChunks = {};
  Map<String, Chunk> cachedChunks = {};
  final Vector2 chunkSize = Vector2.zero();

  ChunkManager({
    required this.tileCount,
    required this.tileSize,
    this.viewDistance = 4,
    this.maxCachedChunks = 1000,
  }) {
    chunkSize.setValues(tileCount.x * tileSize.x, tileCount.y * tileSize.y);
  }

  void update(Vector2 playerPosition) {
    final playerChunkX = playerPosition.x ~/ chunkSize.x;
    final playerChunkY = playerPosition.y ~/ chunkSize.y;

    final Set<String> chunksToKeep = {};

    for (int dx = -viewDistance; dx <= viewDistance; dx++) {
      for (int dy = -viewDistance; dy <= viewDistance; dy++) {
        final chunkX = playerChunkX + dx;
        final chunkY = playerChunkY + dy;

        final chunkKey = '$chunkX,$chunkY';
        chunksToKeep.add(chunkKey);

        if (!loadedChunks.containsKey(chunkKey)) {
          if (cachedChunks.containsKey(chunkKey)) {
            final chunk = cachedChunks.remove(chunkKey)!;
            loadedChunks[chunkKey] = chunk;
          } else {
            final chunk = Chunk(
              position: Vector2(chunkX.toDouble(), chunkY.toDouble()),
              tileCount: tileCount,
              tileSize: tileSize,
            );
            loadedChunks[chunkKey] = chunk;
          }
        }
      }
    }

    loadedChunks.removeWhere((key, value) {
      if (!chunksToKeep.contains(key)) {
        cachedChunks[key] = value;
        if (cachedChunks.length > maxCachedChunks) {
          cachedChunks.remove(cachedChunks.keys.first);
        }
        return true;
      }
      return false;
    });

    print(
      'Loaded Chunks: ${loadedChunks.length}, Cached Chunks: ${cachedChunks.length}',
    );
  }
}
