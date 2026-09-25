@TestOn('vm')
library;

import 'dart:isolate';

import 'package:flame_worldgen/src/core/chunk_data.dart';
import 'package:flame_worldgen/src/core/coords.dart';
import 'package:test/test.dart';

void main() {
  test('ChunkData can be generated in another isolate', () async {
    final chunk = await Isolate.run(() {
      final chunk = ChunkData(const ChunkCoord(-3, 5), ChunkGrid(16));
      chunk.setTileId(const TileCoord(-48, 80), 42);
      chunk.biomes[255] = 9;
      return chunk;
    });

    expect(chunk.coord, const ChunkCoord(-3, 5));
    expect(chunk.grid.size, 16);
    expect(chunk.tileIdAt(const TileCoord(-48, 80)), 42);
    expect(chunk.biomes[255], 9);
  });
}
