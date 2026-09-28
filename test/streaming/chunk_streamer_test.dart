import 'package:flame_worldgen/src/core/chunk_data.dart';
import 'package:flame_worldgen/src/core/coords.dart';
import 'package:flame_worldgen/src/streaming/chunk_executor.dart';
import 'package:flame_worldgen/src/streaming/chunk_range.dart';
import 'package:flame_worldgen/src/streaming/chunk_streamer.dart';
import 'package:test/test.dart';

/// An executor whose chunks finish only when the test says so.
class _FakeExecutor implements ChunkExecutor {
  _FakeExecutor({this.capacity = 1000});

  final int capacity;
  final submitted = <ChunkCoord>[];
  final _running = <ChunkCoord>{};
  final _finished = <ChunkData>[];
  var disposed = false;

  @override
  bool get hasCapacity => _running.length < capacity;

  @override
  void submit(ChunkCoord coord) {
    submitted.add(coord);
    _running.add(coord);
  }

  /// Finishes [coords], or everything that's running.
  void finish([Iterable<ChunkCoord>? coords]) {
    for (final coord in (coords ?? _running).toList()) {
      expect(_running.remove(coord), isTrue, reason: '$coord is not running');
      _finished.add(ChunkData(coord, ChunkGrid(4)));
    }
  }

  @override
  List<ChunkData> drain() {
    final chunks = List.of(_finished);
    _finished.clear();
    return chunks;
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  late _FakeExecutor executor;
  late List<String> events;

  ChunkStreamer streamer({
    int capacity = 1000,
    int loadMargin = 1,
    int unloadMargin = 2,
    int cacheSize = 128,
  }) {
    executor = _FakeExecutor(capacity: capacity);
    events = [];
    return ChunkStreamer(
      executor: executor,
      loadMargin: loadMargin,
      unloadMargin: unloadMargin,
      cacheSize: cacheSize,
      onLoaded: (chunk) => events.add('+${chunk.coord.x},${chunk.coord.y}'),
      onUnloaded: (chunk) => events.add('-${chunk.coord.x},${chunk.coord.y}'),
    );
  }

  const origin = ChunkRange(0, 0, 0, 0);

  test('requests the visible chunks plus the load margin', () {
    final chunks = streamer()..update(origin);
    expect(executor.submitted.toSet(), {
      for (var y = -1; y <= 1; y++)
        for (var x = -1; x <= 1; x++) ChunkCoord(x, y),
    });
    expect(chunks.inFlight, 9);
    expect(chunks.loaded, isEmpty);
  });

  test('requests the nearest chunks first', () {
    streamer(capacity: 3, loadMargin: 2).update(origin);
    expect(executor.submitted.first, const ChunkCoord(0, 0));
    for (final coord in executor.submitted.skip(1)) {
      expect(coord.x.abs() + coord.y.abs(), 1);
    }
  });

  test('loads chunks when they finish, during update', () {
    final chunks = streamer()..update(origin);
    executor.finish([const ChunkCoord(0, 0)]);
    expect(events, isEmpty, reason: 'nothing happens between updates');

    chunks.update(origin);
    expect(events, ['+0,0']);
    expect(chunks.loaded.keys, [const ChunkCoord(0, 0)]);
  });

  test('never requests a chunk twice while it is being generated', () {
    final chunks = streamer()..update(origin);
    final first = executor.submitted.length;
    chunks.update(origin);
    chunks.update(origin);
    expect(executor.submitted, hasLength(first));
  });

  test('only submits while the executor has capacity', () {
    final chunks = streamer(capacity: 2)..update(origin);
    expect(executor.submitted, hasLength(2));

    executor.finish();
    chunks.update(origin);
    expect(executor.submitted, hasLength(4));
  });

  test('re-prioritizes the queue when the view moves', () {
    final chunks = streamer(capacity: 1)..update(origin);
    expect(executor.submitted.last, const ChunkCoord(0, 0));

    // Before anything else is sent, the view jumps far away.
    executor.finish();
    chunks.update(const ChunkRange(50, 50, 50, 50));
    expect(executor.submitted.last, const ChunkCoord(50, 50));
  });

  test('unloads chunks beyond the unload margin, not before', () {
    final chunks = streamer()..update(origin);
    executor.finish();
    chunks.update(origin);
    events.clear();

    // Chunk -1 is now 2 chunks from the view: within the unload margin.
    chunks.update(const ChunkRange(1, 0, 1, 0));
    expect(events.where((e) => e.startsWith('-')), isEmpty);

    // Now it's 3 chunks away.
    chunks.update(const ChunkRange(2, 0, 2, 0));
    expect(events, containsAll(['--1,-1', '--1,0', '--1,1']));
    expect(chunks.loaded.keys.where((c) => c.x == -1), isEmpty);
  });

  test('loads unloaded chunks from the cache without generating them', () {
    final chunks = streamer()..update(origin);
    executor.finish();
    chunks.update(origin);
    chunks.update(const ChunkRange(10, 0, 10, 0));
    executor.finish();
    chunks.update(const ChunkRange(10, 0, 10, 0));
    final submitted = executor.submitted.length;
    events.clear();

    chunks.update(origin);
    expect(executor.submitted, hasLength(submitted));
    expect(events, contains('+0,0'));
    expect(chunks.loaded, contains(const ChunkCoord(0, 0)));
  });

  test('chunks that are no longer wanted when they finish go to the cache', () {
    final chunks = streamer()..update(origin);
    chunks.update(const ChunkRange(10, 0, 10, 0));
    executor.finish([const ChunkCoord(0, 0)]);
    chunks.update(const ChunkRange(10, 0, 10, 0));
    expect(events, isNot(contains('+0,0')));
    expect(chunks.cached, 1);

    final submitted = executor.submitted.length;
    chunks.update(origin);
    expect(events, contains('+0,0'));
    expect(
      executor.submitted.skip(submitted),
      isNot(contains(const ChunkCoord(0, 0))),
    );
  });

  test('the cache drops the least recently used chunks', () {
    final chunks = streamer(loadMargin: 0, unloadMargin: 0, cacheSize: 2);
    for (var x = 0; x < 4; x++) {
      chunks.update(ChunkRange(x, 0, x, 0));
      executor.finish();
      chunks.update(ChunkRange(x, 0, x, 0));
    }
    // Chunks 0, 1 and 2 were unloaded, in that order. The cache keeps the
    // last two.
    chunks.update(const ChunkRange(100, 0, 100, 0));
    expect(chunks.cached, 2);

    final submitted = executor.submitted.length;
    chunks.update(const ChunkRange(0, 0, 0, 0));
    expect(executor.submitted.skip(submitted), [const ChunkCoord(0, 0)]);
  });

  test('a cache size of 0 keeps nothing', () {
    final chunks = streamer(cacheSize: 0)..update(origin);
    executor.finish();
    chunks.update(const ChunkRange(10, 0, 10, 0));
    expect(chunks.cached, 0);
  });

  test('dispose unloads everything and stops the executor', () {
    final chunks = streamer()..update(origin);
    executor.finish();
    chunks.update(origin);
    events.clear();

    chunks.dispose();
    expect(events, hasLength(9));
    expect(chunks.loaded, isEmpty);
    expect(executor.disposed, isTrue);
  });

  test('rejects invalid margins and cache sizes', () {
    final executor = _FakeExecutor();
    void noop(ChunkData _) {}
    expect(
      () => ChunkStreamer(
        executor: executor,
        onLoaded: noop,
        onUnloaded: noop,
        loadMargin: 2,
        unloadMargin: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => ChunkStreamer(
        executor: executor,
        onLoaded: noop,
        onUnloaded: noop,
        loadMargin: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => ChunkStreamer(
        executor: executor,
        onLoaded: noop,
        onUnloaded: noop,
        cacheSize: -1,
      ),
      throwsArgumentError,
    );
  });

  group('ChunkRange', () {
    const range = ChunkRange(-1, 2, 1, 3);

    test('contains and coords', () {
      expect(range.coords, hasLength(6));
      expect(range.coords.every(range.contains), isTrue);
      expect(range.contains(const ChunkCoord(2, 2)), isFalse);
    });

    test('expand', () {
      expect(range.expand(1), const ChunkRange(-2, 1, 2, 4));
    });

    test('distance from the centre', () {
      expect(range.distanceSquaredTo(const ChunkCoord(0, 2)), 0.25);
      expect(range.distanceSquaredTo(const ChunkCoord(3, 2)), 9.25);
    });
  });
}
