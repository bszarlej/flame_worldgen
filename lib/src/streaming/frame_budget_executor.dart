import 'dart:collection';

import '../core/chunk_data.dart';
import '../core/coords.dart';
import '../core/generation/world_generator.dart';
import 'chunk_executor.dart';

/// Generates chunks on the main isolate, spending at most [budget] per frame.
///
/// Used on the web, which has no isolates. Each [drain] generates queued
/// chunks until [budget] is used up, but always at least one, so loading
/// never stalls.
class FrameBudgetExecutor implements ChunkExecutor {
  /// Creates an executor that generates with [generator].
  ///
  /// At most [queueLimit] chunks wait at a time, so the streamer can still
  /// reorder the rest when the view moves.
  FrameBudgetExecutor(
    this.generator, {
    this.budget = const Duration(milliseconds: 4),
    this.queueLimit = 4,
  });

  /// Generates the chunks.
  final ChunkGenerator generator;

  /// The time to spend generating per frame.
  final Duration budget;

  /// The number of chunks that can wait at a time.
  final int queueLimit;

  final _queue = Queue<ChunkCoord>();
  final _stopwatch = Stopwatch();

  @override
  bool get hasCapacity => _queue.length < queueLimit;

  @override
  void submit(ChunkCoord coord) => _queue.add(coord);

  @override
  List<ChunkData> drain() {
    final finished = <ChunkData>[];
    _stopwatch
      ..reset()
      ..start();
    while (_queue.isNotEmpty &&
        (finished.isEmpty || _stopwatch.elapsed < budget)) {
      finished.add(generator.generate(_queue.removeFirst()));
    }
    _stopwatch.stop();
    return finished;
  }

  @override
  void dispose() => _queue.clear();
}
