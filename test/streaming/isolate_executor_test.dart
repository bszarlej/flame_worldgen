@TestOn('vm')
library;

import 'package:flame_worldgen/src/core/core.dart';
import 'package:flame_worldgen/src/streaming/isolate_executor.dart';
import 'package:test/test.dart';

import '../core/generation/golden_world.dart';
import 'executor_test_utils.dart';

/// Waits until [executor] has finished [count] chunks.
Future<List<ChunkData>> _collect(IsolateExecutor executor, int count) async {
  final chunks = <ChunkData>[];
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (chunks.length < count) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    chunks.addAll(executor.drain());
  }
  return chunks;
}

// Top-level finals are created again on every isolate, so the worker's
// `_finalGrass` is a different object than the one in the generator it got.
// ignore: prefer_const_constructors
final _finalGrass = TileType('final grass');
const _marker = TileType('marker');

/// Replaces the first tile with a marker if it's `_finalGrass`.
class _MarkPass extends GenerationPass {
  const _MarkPass();

  @override
  void apply(ChunkBuilder chunk) {
    final first = chunk.coords.first;
    if (chunk.tileAt(first) == _finalGrass) chunk.setTile(first, _marker);
  }
}

class _FailingPass extends GenerationPass {
  const _FailingPass();

  @override
  void apply(ChunkBuilder chunk) {
    if (chunk.coord == const ChunkCoord(1, 1)) {
      throw StateError('the road pass broke');
    }
  }
}

void main() {
  Future<IsolateExecutor> spawn({
    List<GenerationPass> passes = const [RoadPass()],
    List<TileType> tiles = const [dirt],
  }) => IsolateExecutor.spawn(
    WorldGenerator(
      fields: [elevation, moisture],
      biomes: goldenBiomes(scatter: true),
      passes: passes,
    ),
    seed: 42,
    grid: ChunkGrid(16),
    tiles: tiles,
  );

  test('generates the same chunks as the main isolate', () async {
    final executor = await spawn();
    addTearDown(executor.dispose);
    final direct = goldenChunks(passes: [const RoadPass()], scatter: true);

    final chunks = <ChunkData>[];
    for (var x = -2; x <= 2; x++) {
      while (!executor.hasCapacity) {
        chunks.addAll(await _collect(executor, 1));
      }
      executor.submit(ChunkCoord(x, -1));
    }
    chunks.addAll(await _collect(executor, 5 - chunks.length));

    expect(chunks.map((c) => c.coord.x).toSet(), {-2, -1, 0, 1, 2});
    for (final chunk in chunks) {
      expectSameChunk(chunk, direct.generate(chunk.coord));
    }
  });

  test('fields and tile types declared as top-level finals work', () async {
    final executor = await IsolateExecutor.spawn(
      WorldGenerator(
        fields: [elevation],
        biomes: [
          Biome('low', ground: _finalGrass, when: (s) => s[elevation] < 2),
          const Biome('never', ground: sand),
        ],
        passes: const [_MarkPass()],
      ),
      seed: 1,
      grid: ChunkGrid(4),
      tiles: const [_marker],
    );
    addTearDown(executor.dispose);
    executor.submit(const ChunkCoord(0, 0));

    final chunk = (await _collect(executor, 1)).single;
    // Palette: final grass 0, sand 1, marker 2.
    expect(chunk.tiles.first, 2);
    expect(chunk.tiles.skip(1).toSet(), {0});
  });

  test('keeps at most maxInFlight chunks', () async {
    final executor = await spawn();
    addTearDown(executor.dispose);
    expect(executor.maxInFlight, 2);

    executor
      ..submit(const ChunkCoord(0, 0))
      ..submit(const ChunkCoord(1, 0));
    expect(executor.hasCapacity, isFalse);

    await _collect(executor, 2);
    expect(executor.hasCapacity, isTrue);
  });

  test('errors in the worker are rethrown on the main isolate', () async {
    final executor = await spawn(passes: const [_FailingPass()]);
    addTearDown(executor.dispose);
    executor.submit(const ChunkCoord(1, 1));

    Object? error;
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (error == null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      try {
        executor.drain();
      } on StateError catch (e) {
        error = e;
      }
    }
    expect(error.toString(), contains('the road pass broke'));
    expect(executor.hasCapacity, isTrue);
  });

  test('spawn fails if the worker cannot set up the generator', () async {
    await expectLater(
      spawn(tiles: const [TileType('water')]),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Two different tile types are named "water"'),
        ),
      ),
    );
  });

  test('stops accepting chunks after dispose', () async {
    final executor = await spawn();
    executor.dispose();
    expect(executor.hasCapacity, isFalse);
    executor.dispose();
  });
}
