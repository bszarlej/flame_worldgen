import 'dart:async';

import 'package:fast_noise/fast_noise.dart';
import 'package:flame/components.dart';

import '../math/vector2i.dart';
import '../utils/utils.dart';
import 'chunk.dart';

class ChunkUpdateInfo {
  final List<Chunk> loadedChunks;
  final List<Chunk> unloadedChunks;

  const ChunkUpdateInfo({
    this.loadedChunks = const [],
    this.unloadedChunks = const [],
  });
}

class ChunkManager {
  final Noise2 noise;
  final Vector2i chunkSize;
  final Vector2i tileSize;
  final void Function(Chunk chunk)? onChunkLoaded;
  final void Function(Chunk chunk)? onChunkUnloaded;
  int chunkCacheSize;

  final Map<Vector2i, Chunk> _loadedChunks = {};
  final Map<Vector2i, Chunk> _cachedChunks = {};
  final _chunkUpdateController = StreamController<ChunkUpdateInfo>.broadcast();
  late List<Vector2i> _diskOffsets;
  int _viewDistance;
  Vector2i? _previousChunkPosition;

  ChunkManager({
    required this.noise,
    required this.chunkSize,
    required this.tileSize,
    this.chunkCacheSize = 100,
    int viewDistance = 4,
    this.onChunkLoaded,
    this.onChunkUnloaded,
  }) : _viewDistance = viewDistance {
    _diskOffsets = _generateDiskOffsets(_viewDistance);
  }

  int get viewDistance => _viewDistance;

  set viewDistance(int value) {
    _viewDistance = value.clamp(0, double.infinity).toInt();
    _diskOffsets = _generateDiskOffsets(_viewDistance);
    _previousChunkPosition = null;
  }

  Stream<ChunkUpdateInfo> get onChunkUpdate => _chunkUpdateController.stream;
  Vector2i get chunkWorldSize =>
      Vector2i(chunkSize.x * tileSize.x, chunkSize.y * tileSize.y);
  Map<Vector2i, Chunk> get loadedChunks => _loadedChunks;
  int get totalCached => _cachedChunks.length;

  Future<void> dispose() async {
    await _chunkUpdateController.close();
  }

  void updateVisibleChunks(Vector2 centerPosition) {
    final centerChunkPosition = Vector2i.fromVector2(
      worldToChunkPosition(centerPosition, chunkWorldSize),
    );

    if (_previousChunkPosition != centerChunkPosition) {
      final Set<Vector2i> chunksToKeep = _getChunksWithinLoadRadius(
        centerChunkPosition,
      );

      final List<Chunk> newChunks = [];
      final List<Chunk> oldChunks = [];

      // load new chunks
      for (final key in chunksToKeep) {
        if (!_loadedChunks.containsKey(key)) {
          Chunk chunk;
          if (_cachedChunks.containsKey(key)) {
            chunk = _cachedChunks.remove(key)!;
          } else {
            chunk = Chunk(
              noise: noise,
              chunkCoords: key,
              chunkSize: chunkSize,
              tileSize: tileSize,
            );
          }
          _loadedChunks[key] = chunk;
          onChunkLoaded?.call(chunk);
          newChunks.add(chunk);
        }
      }

      //unload and cache old chunks
      for (final key in _loadedChunks.keys.toList()) {
        if (!chunksToKeep.contains(key)) {
          final chunk = _loadedChunks.remove(key);
          if (chunk != null) {
            _cachedChunks[key] = chunk;
            if (_cachedChunks.length > chunkCacheSize) {
              _cachedChunks.remove(_cachedChunks.keys.first);
            }
            onChunkUnloaded?.call(chunk);
            oldChunks.add(chunk);
          }
        }
      }

      _chunkUpdateController.add(
        ChunkUpdateInfo(loadedChunks: newChunks, unloadedChunks: oldChunks),
      );

      _previousChunkPosition = centerChunkPosition;
    }
  }

  Set<Vector2i> _getChunksWithinLoadRadius(Vector2i centerChunk) {
    final Set<Vector2i> chunksToKeep = {};
    for (final offset in _diskOffsets) {
      final chunkX = centerChunk.x + offset.x;
      final chunkY = centerChunk.y + offset.y;
      final key = Vector2i(chunkX, chunkY);
      chunksToKeep.add(key);
    }
    return chunksToKeep;
  }

  List<Vector2i> _generateDiskOffsets(int radius) {
    final offsets = <Vector2i>[];
    for (int x = -radius; x <= radius; x++) {
      for (int y = -radius; y <= radius; y++) {
        if (x * x + y * y <= radius * radius) {
          offsets.add(Vector2i(x, y));
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
