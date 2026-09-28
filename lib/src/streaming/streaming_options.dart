/// How a map loads and unloads chunks as the camera moves.
///
/// ```dart
/// ProceduralMap(
///   streaming: StreamingOptions(loadMargin: 2, cacheSize: 256),
///   ...
/// );
/// ```
class StreamingOptions {
  /// Creates streaming options. The defaults suit most games.
  ///
  /// [unloadMargin] must be at least [loadMargin], so moving back and forth
  /// over a chunk border doesn't load and unload the same chunks every time.
  StreamingOptions({
    this.loadMargin = 1,
    this.unloadMargin = 2,
    this.cacheSize = 128,
    this.frameBudget = const Duration(milliseconds: 2),
  }) {
    if (loadMargin < 0) {
      throw ArgumentError.value(
        loadMargin,
        'loadMargin',
        'must not be negative',
      );
    }
    if (unloadMargin < loadMargin) {
      throw ArgumentError.value(
        unloadMargin,
        'unloadMargin',
        'must be at least loadMargin ($loadMargin)',
      );
    }
    if (cacheSize < 0) {
      throw ArgumentError.value(cacheSize, 'cacheSize', 'must not be negative');
    }
    if (frameBudget.isNegative) {
      throw ArgumentError.value(
        frameBudget,
        'frameBudget',
        'must not be negative',
      );
    }
  }

  /// Chunks loaded beyond the visible area, in every direction.
  final int loadMargin;

  /// Chunks kept beyond the visible area before they're unloaded.
  final int unloadMargin;

  /// Generated chunks kept in memory after they're unloaded, so they load
  /// again instantly.
  final int cacheSize;

  /// The time spent generating chunks per frame on the web, which has no
  /// isolates. At least one chunk is generated per frame, however long it
  /// takes. Other platforms generate on a worker isolate and ignore this.
  final Duration frameBudget;
}
