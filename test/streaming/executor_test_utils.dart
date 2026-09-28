import 'package:flame_worldgen/src/core/chunk_data.dart';
import 'package:test/test.dart';

/// Expects [actual] to have the same tiles, biomes and scatter spots as
/// [expected].
void expectSameChunk(ChunkData actual, ChunkData expected) {
  expect(actual.coord, expected.coord);
  expect(actual.tiles, expected.tiles);
  expect(actual.biomes, expected.biomes);
  expect(
    actual.spots.map((s) => (s.ruleIndex, s.x, s.y, s.seed)),
    expected.spots.map((s) => (s.ruleIndex, s.x, s.y, s.seed)),
  );
}
