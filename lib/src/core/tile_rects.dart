import 'dart:typed_data';

import 'chunk_data.dart';

/// A rectangle of tiles, in tiles from a chunk's top-left corner.
typedef TileRect = ({int x, int y, int width, int height});

/// Merges the tiles of [chunk] that [include] accepts into rectangles of one
/// tile id each, and returns them by tile id.
///
/// Greedy meshing: from the top left, each rectangle grows right as far as
/// the tile id repeats, then down as long as the whole row below matches.
/// That's not always the fewest rectangles possible, but close, and fast.
Map<int, List<TileRect>> mergeTiles(
  ChunkData chunk,
  bool Function(int id) include,
) {
  final size = chunk.grid.size;
  final tiles = chunk.tiles;
  final used = Uint8List(tiles.length);
  final rects = <int, List<TileRect>>{};

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final start = y * size + x;
      if (used[start] != 0) continue;
      final id = tiles[start];
      if (!include(id)) continue;

      var width = 1;
      while (x + width < size &&
          used[start + width] == 0 &&
          tiles[start + width] == id) {
        width++;
      }

      var height = 1;
      rows:
      while (y + height < size) {
        final row = start + height * size;
        for (var i = row; i < row + width; i++) {
          if (used[i] != 0 || tiles[i] != id) break rows;
        }
        height++;
      }

      for (var row = 0; row < height; row++) {
        final first = start + row * size;
        used.fillRange(first, first + width, 1);
      }
      (rects[id] ??= []).add((x: x, y: y, width: width, height: height));
    }
  }
  return rects;
}
