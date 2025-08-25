import 'dart:collection';

import 'package:fast_noise/fast_noise.dart';
import 'package:flame/components.dart';

import '../utils/utils.dart';
import 'chunk.dart';

class ChunkManager {
  final Noise2 noise;
  final Point chunkSize;
  final Point tileSize;
  int chunkCacheSize;
  int chunkLoadLimitPerFrame;
  int chunkUnloadLimitPerFrame;
  final void Function(Chunk chunk)? onChunkLoaded;
  final void Function(Chunk chunk)? onChunkUnloaded;

  int _loadDistance;
  late List<Point> _diskOffsets;
  final Map<int, Chunk> _loadedChunks = {};
  final LinkedHashMap<int, Chunk> _cachedChunks = LinkedHashMap();
  final Queue<int> _chunksToLoad = Queue();
  final Queue<int> _chunksToUnload = Queue();
  final Set<int> _loadingSet = {};
  final Set<int> _unloadingSet = {};

  ChunkManager({
    required this.noise,
    required this.chunkSize,
    required this.tileSize,
    this.chunkCacheSize = 100,
    this.chunkLoadLimitPerFrame = 10,
    this.chunkUnloadLimitPerFrame = 10,
    int loadDistance = 4,
    this.onChunkLoaded,
    this.onChunkUnloaded,
  }) : _loadDistance = loadDistance {
    _diskOffsets = _generateDiskOffsets(_loadDistance);
  }

  int get loadDistance => _loadDistance;

  set loadDistance(int value) {
    _loadDistance = value;
    _diskOffsets = _generateDiskOffsets(_loadDistance);
  }

  Point get chunkWorldSize =>
      (x: chunkSize.x * tileSize.x, y: chunkSize.y * tileSize.y);
  Map<int, Chunk> get loadedChunks => _loadedChunks;
  int get queuedLoads => _chunksToLoad.length;
  int get queuedUnloads => _chunksToUnload.length;
  int get totalCached => _cachedChunks.length;

  void updateVisibleChunks(Vector2 centerPosition) {
    final centerChunkPosition = worldToChunkPosition(
      centerPosition,
      chunkWorldSize,
    );

    final Set<int> chunksToKeep = _getChunksWithinLoadRadius(
      centerChunkPosition.x.floor(),
      centerChunkPosition.y.floor(),
    );

    _scheduleChunksToLoad(chunksToKeep);
    _scheduleChunksForUnload(chunksToKeep);

    _processChunkLoadQueue();
    _processChunkUnloadQueue();
  }

  Set<int> _getChunksWithinLoadRadius(int centerChunkX, int centerChunkY) {
    final Set<int> chunksToKeep = {};
    for (final offset in _diskOffsets) {
      final chunkX = centerChunkX + offset.x;
      final chunkY = centerChunkY + offset.y;
      final key = packKey(chunkX, chunkY);
      chunksToKeep.add(key);
    }
    return chunksToKeep;
  }

  void _scheduleChunksToLoad(Set<int> chunksToKeep) {
    for (final key in chunksToKeep) {
      if (!_loadedChunks.containsKey(key) && !_loadingSet.contains(key)) {
        _chunksToLoad.addLast(key);
        _loadingSet.add(key);
      }
    }
  }

  void _processChunkLoadQueue() {
    int loadedCount = 0;
    while (_chunksToLoad.isNotEmpty && loadedCount < chunkLoadLimitPerFrame) {
      final key = _chunksToLoad.removeFirst();
      _loadingSet.remove(key);

      Chunk chunk;
      if (_cachedChunks.containsKey(key)) {
        chunk = _cachedChunks.remove(key)!;
      } else {
        final chunkCoords = unpackKey(key);
        chunk = Chunk(
          noise: noise,
          chunkCoords: chunkCoords,
          chunkSize: chunkSize,
          tileSize: tileSize,
        );
      }
      _loadedChunks[key] = chunk;
      onChunkLoaded?.call(chunk);
      loadedCount++;
    }
  }

  void _scheduleChunksForUnload(Set<int> chunksToKeep) {
    for (final key in _loadedChunks.keys) {
      if (!chunksToKeep.contains(key) && !_unloadingSet.contains(key)) {
        _chunksToUnload.addLast(key);
        _unloadingSet.add(key);
      }
    }

    _chunksToLoad.removeWhere((key) {
      final shouldRemove = !chunksToKeep.contains(key);
      if (shouldRemove) _loadingSet.remove(key);
      return shouldRemove;
    });
  }

  void _processChunkUnloadQueue() {
    int unloadedCount = 0;
    while (_chunksToUnload.isNotEmpty &&
        unloadedCount < chunkUnloadLimitPerFrame) {
      final key = _chunksToUnload.removeFirst();
      final chunk = _loadedChunks.remove(key);
      _unloadingSet.remove(key);
      if (chunk != null) {
        _cachedChunks[key] = chunk;
        if (_cachedChunks.length > chunkCacheSize) {
          _cachedChunks.remove(_cachedChunks.keys.first);
        }
        onChunkUnloaded?.call(chunk);
        unloadedCount++;
      }
    }
  }

  List<Point> _generateDiskOffsets(int radius) {
    final offsets = <Point>[];
    for (int x = -radius; x <= radius; x++) {
      for (int y = -radius; y <= radius; y++) {
        if (x * x + y * y <= radius * radius) {
          offsets.add((x: x, y: y));
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
