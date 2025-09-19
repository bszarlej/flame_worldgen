import 'dart:async';

import 'package:fast_noise/fast_noise.dart';
import 'package:flame/components.dart';

import '../math/vector2i.dart';
import '../utils/utils.dart';
import 'chunk.dart';

/// Contains information about chunks that have been loaded or unloaded
/// during a single update.
class ChunkUpdateInfo {
  /// List of chunks that were loaded in this update.
  final List<Chunk> loadedChunks;

  /// List of chunks that were unloaded in this update.
  final List<Chunk> unloadedChunks;

  /// Creates a [ChunkUpdateInfo] instance.
  ///
  /// Both [loadedChunks] and [unloadedChunks] default to empty lists.
  const ChunkUpdateInfo({
    this.loadedChunks = const [],
    this.unloadedChunks = const [],
  });
}

/// Manages the loading, unloading, and caching of chunks for a procedural world.
///
/// Keeps track of which chunks are currently visible based on a "view distance"
/// and can provide notifications when chunks are loaded or unloaded.
class ChunkManager {
  /// The noise generator used to create chunk height maps.
  final Noise2 noise;

  /// The size of each chunk in tiles (width x height).
  final Vector2i chunkSize;

  /// The size of each tile in pixels (width x height).
  final Vector2i tileSize;

  /// Optional callback when a chunk is loaded.
  final void Function(Chunk chunk)? onChunkLoaded;

  /// Optional callback when a chunk is unloaded.
  final void Function(Chunk chunk)? onChunkUnloaded;

  /// Maximum number of chunks to cache in memory.
  int chunkCacheSize;

  /// Currently loaded chunks mapped by their chunk coordinates.
  final Map<Vector2i, Chunk> _loadedChunks = {};

  /// Cached chunks that are not currently loaded.
  final Map<Vector2i, Chunk> _cachedChunks = {};

  /// Stream controller broadcasting chunk updates.
  final _chunkUpdateController = StreamController<ChunkUpdateInfo>.broadcast();

  /// Precomputed offsets for determining which chunks fall within the view distance.
  late List<Vector2i> _diskOffsets;

  int _viewDistance;
  Vector2i? _previousChunkPosition;

  /// Creates a new [ChunkManager].
  ///
  /// [chunkCacheSize] controls how many unloaded chunks are kept in memory.
  /// [viewDistance] determines how far (in chunks) to load chunks around a center position.
  ChunkManager({
    required this.noise,
    required this.chunkSize,
    required this.tileSize,
    this.chunkCacheSize = 100,
    int viewDistance = 4,
    this.onChunkLoaded,
    this.onChunkUnloaded,
  }) : assert(
         chunkSize.x > 0 && chunkSize.y > 0,
         'Chunk size must be positive',
       ),
       assert(tileSize.x > 0 && tileSize.y > 0, 'Tile size must be positive'),
       _viewDistance = viewDistance {
    _diskOffsets = _generateDiskOffsets(_viewDistance);
  }

  /// The current view distance in chunks.
  int get viewDistance => _viewDistance;

  /// Sets the view distance and updates internal offsets.
  set viewDistance(int value) {
    _viewDistance = value.clamp(0, double.infinity).toInt();
    _diskOffsets = _generateDiskOffsets(_viewDistance);
    _previousChunkPosition = null;
  }

  /// Stream of chunk updates for listeners.
  Stream<ChunkUpdateInfo> get onChunkUpdate => _chunkUpdateController.stream;

  /// The size of a chunk in world coordinates (pixels).
  Vector2i get chunkWorldSize =>
      Vector2i(chunkSize.x * tileSize.x, chunkSize.y * tileSize.y);

  /// Currently loaded chunks mapped by chunk coordinates.
  Map<Vector2i, Chunk> get loadedChunks => _loadedChunks;

  /// Number of chunks currently cached in memory but not loaded.
  int get totalCached => _cachedChunks.length;

  /// Closes internal streams and cleans up resources.
  Future<void> dispose() async {
    await _chunkUpdateController.close();
  }

  /// Updates which chunks are visible based on [centerPosition] in world space.
  ///
  /// Loads new chunks, caches old ones outside the view distance, and emits
  /// a [ChunkUpdateInfo] with the changes.
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

      // Load new chunks
      for (final key in chunksToKeep) {
        if (!_loadedChunks.containsKey(key)) {
          Chunk chunk;
          if (_cachedChunks.containsKey(key)) {
            chunk = _cachedChunks.remove(key)!;
          } else {
            chunk = Chunk(
              noise: noise,
              coords: key,
              size: chunkSize,
              tileSize: tileSize,
            );
          }
          _loadedChunks[key] = chunk;
          onChunkLoaded?.call(chunk);
          newChunks.add(chunk);
        }
      }

      // Unload and cache old chunks
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

  /// Returns all chunk coordinates within the load radius from [centerChunk].
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

  /// Generates a sorted list of offsets representing a circular area of radius [radius].
  ///
  /// The offsets are sorted by distance from the origin (0,0).
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
