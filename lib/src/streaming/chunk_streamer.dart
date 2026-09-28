import 'dart:collection';

import '../core/chunk_data.dart';
import '../core/coords.dart';
import 'chunk_cache.dart';
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
  ///
  /// Chunks that aren't loaded are kept in [cache], which defaults to one of
  /// `options.cacheSize` chunks. Pass your own to share it, for example with
  /// code that generates chunks outside the streamer.
  ChunkStreamer({
    required this.executor,
    required this.onLoaded,
    required this.onUnloaded,
    StreamingOptions? options,
    ChunkCache? cache,
  }) : options = options ??= StreamingOptions(),
       cache = cache ?? ChunkCache(options.cacheSize);

  /// Generates the chunks.
  final ChunkExecutor executor;

  /// Called when a chunk is loaded, before it's first drawn.
  final void Function(ChunkData chunk) onLoaded;

  /// Called when a chunk is unloaded.
  final void Function(ChunkData chunk) onUnloaded;

  /// The margins.
  final StreamingOptions options;

  /// Chunks that were generated but aren't loaded.
  final ChunkCache cache;

  final _loaded = <ChunkCoord, ChunkData>{};
  final _inFlight = <ChunkCoord>{};

  /// The loaded chunks.
  Map<ChunkCoord, ChunkData> get loaded => UnmodifiableMapView(_loaded);

  /// The number of chunks the executor is generating.
  int get inFlight => _inFlight.length;

  /// The number of chunks in the cache.
  int get cached => cache.length;

  /// Loads and unloads chunks for a view that shows [visible].
  void update(ChunkRange visible) {
    final wanted = visible.expand(options.loadMargin);
    final kept = visible.expand(options.unloadMargin);

    for (final chunk in executor.drain()) {
      _inFlight.remove(chunk.coord);
      if (wanted.contains(chunk.coord) && !_loaded.containsKey(chunk.coord)) {
        _load(chunk);
      } else {
        cache.put(chunk);
      }
    }

    final unload = [
      for (final coord in _loaded.keys)
        if (!kept.contains(coord)) coord,
    ];
    for (final coord in unload) {
      final chunk = _loaded.remove(coord)!;
      onUnloaded(chunk);
      cache.put(chunk);
    }

    final missing = <ChunkCoord>[];
    for (final coord in wanted.coords) {
      if (_loaded.containsKey(coord) || _inFlight.contains(coord)) continue;
      final cached = cache.take(coord);
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
    cache.clear();
    _inFlight.clear();
    executor.dispose();
  }

  void _load(ChunkData chunk) {
    _loaded[chunk.coord] = chunk;
    onLoaded(chunk);
  }
}
