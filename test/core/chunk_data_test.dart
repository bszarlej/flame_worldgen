import 'dart:typed_data';

import 'package:flame_worldgen/src/core/chunk_data.dart';
import 'package:flame_worldgen/src/core/coords.dart';
import 'package:test/test.dart';

void main() {
  final grid = ChunkGrid(32);

  test('starts empty', () {
    final chunk = ChunkData(const ChunkCoord(0, 0), grid);
    expect(chunk.tiles, hasLength(1024));
    expect(chunk.biomes, hasLength(1024));
    expect(chunk.tiles.every((id) => id == 0), isTrue);
  });

  test('origin', () {
    final chunk = ChunkData(const ChunkCoord(-1, 2), grid);
    expect(chunk.origin, const TileCoord(-32, 64));
  });

  test('contains only its own tiles', () {
    final chunk = ChunkData(const ChunkCoord(-1, -1), grid);
    expect(chunk.contains(const TileCoord(-1, -1)), isTrue);
    expect(chunk.contains(const TileCoord(-32, -32)), isTrue);
    expect(chunk.contains(const TileCoord(0, -1)), isFalse);
    expect(chunk.contains(const TileCoord(-33, -1)), isFalse);
  });

  test('reads and writes tiles by world coordinate', () {
    final chunk = ChunkData(const ChunkCoord(-1, 0), grid);
    chunk.setTileId(const TileCoord(-1, 0), 7);
    chunk.setTileId(const TileCoord(-32, 31), 65535);
    expect(chunk.tileIdAt(const TileCoord(-1, 0)), 7);
    expect(chunk.tiles[31], 7);
    expect(chunk.tileIdAt(const TileCoord(-32, 31)), 65535);
    expect(chunk.tiles[31 * 32], 65535);
  });

  test('reads biomes by world coordinate', () {
    final biomes = Uint8List(1024)..[33] = 4;
    final chunk = ChunkData.from(
      const ChunkCoord(1, 1),
      grid,
      Uint16List(1024),
      biomes,
    );
    expect(chunk.biomeAt(const TileCoord(33, 33)), 4);
  });

  test('throws for tiles outside the chunk', () {
    final chunk = ChunkData(const ChunkCoord(0, 0), grid);
    expect(() => chunk.tileIdAt(const TileCoord(32, 0)), throwsArgumentError);
    expect(
      () => chunk.setTileId(const TileCoord(-1, 0), 1),
      throwsArgumentError,
    );
    expect(() => chunk.biomeAt(const TileCoord(0, 32)), throwsArgumentError);
  });

  test('from checks list lengths', () {
    expect(
      () => ChunkData.from(
        const ChunkCoord(0, 0),
        grid,
        Uint16List(10),
        Uint8List(1024),
      ),
      throwsArgumentError,
    );
    expect(
      () => ChunkData.from(
        const ChunkCoord(0, 0),
        grid,
        Uint16List(1024),
        Uint8List(10),
      ),
      throwsArgumentError,
    );
  });

  test('coords lists every tile once, row by row', () {
    final chunk = ChunkData(const ChunkCoord(-2, 1), ChunkGrid(4));
    final coords = chunk.coords.toList();
    expect(coords, hasLength(16));
    expect(coords.toSet(), hasLength(16));
    expect(coords.first, const TileCoord(-8, 4));
    expect(coords[1], const TileCoord(-7, 4));
    expect(coords.last, const TileCoord(-5, 7));
    expect(coords.every(chunk.contains), isTrue);
  });
}
