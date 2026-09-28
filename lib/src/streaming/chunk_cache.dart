import '../core/chunk_data.dart';
import '../core/coords.dart';

/// Keeps up to [capacity] chunks that aren't loaded, so they don't have to
/// be generated again, and drops the least recently used first.
class ChunkCache {
  /// Creates a cache that holds at most [capacity] chunks.
  ChunkCache(this.capacity) {
    RangeError.checkNotNegative(capacity, 'capacity');
  }

  /// The most chunks the cache holds.
  final int capacity;

  // Map literals keep insertion order: the first entry is the least recently
  // used.
  final _chunks = <ChunkCoord, ChunkData>{};

  /// The number of chunks in the cache.
  int get length => _chunks.length;

  /// Returns the chunk at [coord] and marks it as recently used, or returns
  /// null if it isn't cached.
  ChunkData? get(ChunkCoord coord) {
    final chunk = _chunks.remove(coord);
    if (chunk != null) _chunks[coord] = chunk;
    return chunk;
  }

  /// Removes the chunk at [coord] and returns it, or returns null if it isn't
  /// cached.
  ChunkData? take(ChunkCoord coord) => _chunks.remove(coord);

  /// Adds [chunk], replacing any cached chunk at the same coord, and drops
  /// the least recently used chunks beyond [capacity].
  void put(ChunkData chunk) {
    if (capacity == 0) return;
    _chunks.remove(chunk.coord);
    _chunks[chunk.coord] = chunk;
    while (_chunks.length > capacity) {
      _chunks.remove(_chunks.keys.first);
    }
  }

  /// Removes every chunk.
  void clear() => _chunks.clear();
}
