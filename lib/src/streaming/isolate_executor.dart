import 'dart:async';
import 'dart:isolate';

import '../core/chunk_data.dart';
import '../core/coords.dart';
import '../core/generation/world_generator.dart';
import '../core/tile_type.dart';
import 'chunk_executor.dart';

/// Generates chunks on a long-lived worker isolate, so the game never waits
/// for them.
///
/// The worker gets the generator, seed and tile types once and keeps its own
/// `ChunkGenerator`. For each chunk only the coordinate goes there and the
/// finished `ChunkData` comes back.
class IsolateExecutor implements ChunkExecutor {
  IsolateExecutor._(this._isolate, this._port, this.maxInFlight) {
    _port.listen(_receive);
  }

  /// Starts a worker that generates chunks of [grid] with [generator] for the
  /// world with [seed], able to place [tiles].
  ///
  /// The generator is sent to the worker, so it must not reference anything
  /// that can't cross isolates, such as images. Throws if the worker can't
  /// set up its generator.
  static Future<IsolateExecutor> spawn(
    WorldGenerator generator, {
    required int seed,
    required ChunkGrid grid,
    Iterable<TileType> tiles = const [],
    int maxInFlight = 2,
  }) async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerMain,
      _WorkerSetup(port.sendPort, generator, seed, grid.size, List.of(tiles)),
      debugName: 'flame_worldgen chunk worker',
      errorsAreFatal: false,
    );
    final executor = IsolateExecutor._(isolate, port, maxInFlight);
    try {
      await executor._ready.future;
    } catch (_) {
      executor.dispose();
      rethrow;
    }
    return executor;
  }

  /// The number of chunks the worker can have at a time. Two keeps the
  /// worker busy while a result travels back.
  final int maxInFlight;

  final Isolate _isolate;
  final ReceivePort _port;
  final _ready = Completer<SendPort>();
  SendPort? _requests;
  final _finished = <ChunkData>[];
  Object? _error;
  var _inFlight = 0;
  var _disposed = false;

  @override
  bool get hasCapacity => !_disposed && _inFlight < maxInFlight;

  @override
  void submit(ChunkCoord coord) {
    _inFlight++;
    _requests!.send((coord.x, coord.y));
  }

  @override
  List<ChunkData> drain() {
    if (_error case final error?) {
      _error = null;
      throw error;
    }
    final chunks = List.of(_finished);
    _finished.clear();
    return chunks;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _requests?.send(null);
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _port.close();
  }

  void _receive(Object? message) {
    switch (message) {
      case SendPort():
        _requests = message;
        _ready.complete(message);
      case ChunkData():
        _inFlight--;
        _finished.add(message);
      case _WorkerError() when !_ready.isCompleted:
        _ready.completeError(message.toError());
      case _WorkerError():
        _inFlight--;
        _error = message.toError();
    }
  }
}

class _WorkerSetup {
  const _WorkerSetup(
    this.responses,
    this.generator,
    this.seed,
    this.chunkSize,
    this.tiles,
  );

  final SendPort responses;
  final WorldGenerator generator;
  final int seed;
  final int chunkSize;
  final List<TileType> tiles;
}

/// An error in the worker, sent as strings because the error object itself
/// may not be sendable.
class _WorkerError {
  const _WorkerError(this.message, this.stackTrace);

  final String message;
  final String stackTrace;

  StateError toError() => StateError(
    'Generating a chunk failed in the worker isolate: $message\n'
    '$stackTrace',
  );
}

void _workerMain(_WorkerSetup setup) {
  final ChunkGenerator chunks;
  try {
    chunks = ChunkGenerator(
      setup.generator,
      seed: setup.seed,
      grid: ChunkGrid(setup.chunkSize),
      tiles: setup.tiles,
    );
  } catch (error, stackTrace) {
    setup.responses.send(_WorkerError('$error', '$stackTrace'));
    return;
  }

  final requests = ReceivePort();
  setup.responses.send(requests.sendPort);
  requests.listen((message) {
    if (message == null) {
      requests.close();
      return;
    }
    final (x, y) = message as (int, int);
    try {
      setup.responses.send(chunks.generate(ChunkCoord(x, y)));
    } catch (error, stackTrace) {
      setup.responses.send(_WorkerError('$error', '$stackTrace'));
    }
  });
}
