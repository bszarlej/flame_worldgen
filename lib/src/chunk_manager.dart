import 'package:fast_noise/fast_noise.dart';
import 'package:flame/game.dart';

import 'chunk.dart';
import 'utils/utils.dart';

class ChunkManager {
  final Noise2 noise;
  final Vector2 chunkSize;
  late final Vector2 chunkWorldSize;
  final Vector2 tileSize;
  final int loadDistance;
  final int maxCachedChunks;
  final int maxChunksPerFrame;

  late final List<Vector2> _diskOffsets;
  final Map<int, Chunk> _loadedChunks = {};
  final Map<int, Chunk> _cachedChunks = {};
  final List<int> _chunksToLoad = [];

  ChunkManager({
    required this.noise,
    required this.chunkSize,
    required this.tileSize,
    this.loadDistance = 4,
    this.maxCachedChunks = 100,
    this.maxChunksPerFrame = 10,
  }) {
    chunkWorldSize = Vector2(
      chunkSize.x * tileSize.x,
      chunkSize.y * tileSize.y,
    );
    _diskOffsets = _generateDiskOffsets(loadDistance);
  }

  Map<int, Chunk> get loadedChunks => _loadedChunks;

  void updateVisibleChunks(Vector2 centerPosition) {
    final centerChunkPos = worldToChunkPosition(
      centerPosition,
      chunkSize,
      tileSize,
    );

    final List<int> chunksToKeep = [];

    for (final offset in _diskOffsets) {
      final chunkX = (centerChunkPos.x + offset.x).toInt();
      final chunkY = (centerChunkPos.y + offset.y).toInt();

      final key = _packKey(chunkX, chunkY);
      chunksToKeep.add(key);

      if (!_loadedChunks.containsKey(key) && !_chunksToLoad.contains(key)) {
        _chunksToLoad.add(key);
      }
    }

    int loadedCount = 0;
    while (_chunksToLoad.isNotEmpty && loadedCount < maxChunksPerFrame) {
      final key = _chunksToLoad.removeAt(0);
      if (_cachedChunks.containsKey(key)) {
        _loadedChunks[key] = _cachedChunks.remove(key)!;
      } else {
        final (chunkX, chunkY) = _unpackKey(key);
        final chunk = Chunk(
          noise: noise,
          chunkCoords: Vector2(chunkX.toDouble(), chunkY.toDouble()),
          tileCount: chunkSize,
          tileSize: tileSize,
        );
        _loadedChunks[key] = chunk;
      }
      loadedCount++;
    }

    _loadedChunks.removeWhere((key, chunk) {
      if (!chunksToKeep.contains(key)) {
        _cachedChunks[key] = chunk;
        if (_cachedChunks.length > maxCachedChunks) {
          _cachedChunks.remove(_cachedChunks.keys.first);
        }
        return true;
      }
      return false;
    });
  }

  // Packs chunk coordinates into a single integer key
  int _packKey(int x, int y) {
    return (x << 32) | (y & 0xFFFFFFFF);
  }

  // Unpacks the integer key back into chunk coordinates
  (int, int) _unpackKey(int key) {
    final x = key >> 32;
    final y = key & 0xFFFFFFFF;
    return (x, y >= 0x80000000 ? y - 0x100000000 : y);
  }

  /// Generates a list of offsets for a disk shape with the given radius.
  List<Vector2> _generateDiskOffsets(int radius) {
    final offsets = <Vector2>[];
    for (int x = -radius; x <= radius; x++) {
      for (int y = -radius; y <= radius; y++) {
        if (x * x + y * y <= radius * radius) {
          offsets.add(Vector2(x.toDouble(), y.toDouble()));
        }
      }
    }
    offsets.sort((a, b) {
      final da = a.x * a.x + a.y * a.y;
      final db = b.x * b.x + b.y * b.y;
      return da.compareTo(db);
    });
    return offsets;
  }
}
