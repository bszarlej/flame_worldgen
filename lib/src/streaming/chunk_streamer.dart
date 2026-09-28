import 'dart:collection';

import '../core/chunk_data.dart';
import '../core/coords.dart';
import 'chunk_executor.dart';
import 'chunk_range.dart';
import 'streaming_options.dart';

/// Decides which chunks are loaded as the view moves.
///
/// Each frame, [update] receives the chunks the camera can see. The streamer
/// then:
///
/// 1. takes finished chunks from the [executor]. Chunks that are still
///    wanted are loaded; the others go to the cache.
/// 2. unloads chunks more than `unloadMargin` chunks outside the view and
///    moves them to the cache.
/// 3. loads missing chunks within `loadMargin`: straight from the cache if
///    possible, otherwise nearest first through the [executor].
///
/// [onLoaded] and [onUnloaded] are called synchronously during [update].
class ChunkStreamer {
  /// Creates a streamer that generates chunks with [executor].
  ChunkStreamer({
    required this.executor,
    required this.onLoaded,
    required this.onUnloaded,
    StreamingOptions? options,
  }) : options = options ?? StreamingOptions();

  /// Generates the chunks.
  final ChunkExecutor executor;

  /// Called when a chunk is loaded, before it's first drawn.
  final void Function(ChunkData chunk) onLoaded;

  /// Called when a chunk is unloaded.
  final void Function(ChunkData chunk) onUnloaded;

  /// The margins and cache size.
  final StreamingOptions options;

  final _loaded = <ChunkCoord, ChunkData>{};
  final _inFlight = <ChunkCoord>{};

  // Map literals keep insertion order: the first entry is the least recently
  // used.
  final _cache = <ChunkCoord, ChunkData>{};

  /// The loaded chunks.
  Map<ChunkCoord, ChunkData> get loaded => UnmodifiableMapView(_loaded);

  /// The number of chunks the executor is generating.
  int get inFlight => _inFlight.length;

  /// The number of chunks in the cache.
  int get cached => _cache.length;

  /// Loads and unloads chunks for a view that shows [visible].
  void update(ChunkRange visible) {
    final wanted = visible.expand(options.loadMargin);
    final kept = visible.expand(options.unloadMargin);

    for (final chunk in executor.drain()) {
      _inFlight.remove(chunk.coord);
      if (wanted.contains(chunk.coord) && !_loaded.containsKey(chunk.coord)) {
        _load(chunk);
      } else {
        _store(chunk);
      }
    }

    final unload = [
      for (final coord in _loaded.keys)
        if (!kept.contains(coord)) coord,
    ];
    for (final coord in unload) {
      final chunk = _loaded.remove(coord)!;
      onUnloaded(chunk);
      _store(chunk);
    }

    final missing = <ChunkCoord>[];
    for (final coord in wanted.coords) {
      if (_loaded.containsKey(coord) || _inFlight.contains(coord)) continue;
      final cached = _cache.remove(coord);
      if (cached != null) {
        _load(cached);
      } else {
        missing.add(coord);
      }
    }

    missing.sort(
      (a, b) =>
          visible.distanceSquaredTo(a).compareTo(visible.distanceSquaredTo(b)),
    );
    for (final coord in missing) {
      if (!executor.hasCapacity) break;
      _inFlight.add(coord);
      executor.submit(coord);
    }
  }

  /// Unloads every chunk and stops the executor.
  void dispose() {
    for (final chunk in _loaded.values) {
      onUnloaded(chunk);
    }
    _loaded.clear();
    _cache.clear();
    _inFlight.clear();
    executor.dispose();
  }

  void _load(ChunkData chunk) {
    _loaded[chunk.coord] = chunk;
    onLoaded(chunk);
  }

  void _store(ChunkData chunk) {
    if (options.cacheSize == 0) return;
    _cache.remove(chunk.coord);
    _cache[chunk.coord] = chunk;
    while (_cache.length > options.cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }
}
