import 'package:flame_worldgen/src/core/coords.dart';
import 'package:flame_worldgen/src/streaming/frame_budget_executor.dart';
import 'package:test/test.dart';

import '../core/generation/golden_world.dart';
import 'executor_test_utils.dart';

void main() {
  const coords = [
    ChunkCoord(0, 0),
    ChunkCoord(-1, 0),
    ChunkCoord(0, -1),
    ChunkCoord(3, 3),
  ];

  test('generates the same chunks as generating directly', () {
    final executor = FrameBudgetExecutor(
      goldenChunks(passes: [const RoadPass()], scatter: true),
      budget: const Duration(seconds: 10),
    );
    coords.forEach(executor.submit);
    final chunks = executor.drain();

    final direct = goldenChunks(passes: [const RoadPass()], scatter: true);
    expect(chunks, hasLength(coords.length));
    for (final chunk in chunks) {
      expectSameChunk(chunk, direct.generate(chunk.coord));
    }
  });

  test('generates at least one chunk per frame, even without budget', () {
    final executor = FrameBudgetExecutor(goldenChunks(), budget: Duration.zero);
    coords.forEach(executor.submit);
    for (final coord in coords) {
      expect(executor.drain().single.coord, coord);
    }
    expect(executor.drain(), isEmpty);
  });

  test('keeps its queue short', () {
    final executor = FrameBudgetExecutor(goldenChunks(), queueLimit: 2);
    expect(executor.hasCapacity, isTrue);
    executor
      ..submit(coords[0])
      ..submit(coords[1]);
    expect(executor.hasCapacity, isFalse);
    executor.drain();
    expect(executor.hasCapacity, isTrue);
  });

  test('dispose drops queued chunks', () {
    final executor = FrameBudgetExecutor(goldenChunks())
      ..submit(coords[0])
      ..dispose();
    expect(executor.drain(), isEmpty);
  });
}
