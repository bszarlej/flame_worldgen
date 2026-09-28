import '../core/chunk_data.dart';
import '../core/coords.dart';

/// Generates chunks for a [ChunkStreamer], on another isolate or spread over
/// frames.
///
/// The streamer decides which chunk comes next. It only calls [submit] while
/// [hasCapacity] is true, so an executor should keep its own queue short:
/// every chunk it queues is one the streamer can no longer re-prioritize.
abstract interface class ChunkExecutor {
  /// Whether the executor can take another chunk right now.
  bool get hasCapacity;

  /// Starts generating the chunk at [coord].
  void submit(ChunkCoord coord);

  /// Returns the chunks finished since the last call.
  ///
  /// Called once per frame. Executors that generate on the main isolate do
  /// their work here.
  List<ChunkData> drain();

  /// Stops generating and releases resources, such as worker isolates.
  void dispose();
}
