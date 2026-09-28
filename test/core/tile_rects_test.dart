import 'package:flame_worldgen/src/core/chunk_data.dart';
import 'package:flame_worldgen/src/core/coords.dart';
import 'package:flame_worldgen/src/core/hash.dart';
import 'package:flame_worldgen/src/core/tile_rects.dart';
import 'package:test/test.dart';

/// A chunk from rows of digits, each digit a tile id.
ChunkData _chunk(List<String> rows) {
  final chunk = ChunkData(const ChunkCoord(0, 0), ChunkGrid(rows.length));
  for (final (y, row) in rows.indexed) {
    for (var x = 0; x < row.length; x++) {
      chunk.tiles[y * rows.length + x] = int.parse(row[x]);
    }
  }
  return chunk;
}

bool _notZero(int id) => id != 0;

void main() {
  test('no included tiles, no rectangles', () {
    expect(mergeTiles(_chunk(['00', '00']), _notZero), isEmpty);
  });

  test('a full chunk is one rectangle', () {
    expect(mergeTiles(_chunk(['1111', '1111', '1111', '1111']), _notZero), {
      1: [(x: 0, y: 0, width: 4, height: 4)],
    });
  });

  test('grows right first, then down', () {
    expect(mergeTiles(_chunk(['1100', '1110', '0000', '0001']), _notZero), {
      1: [
        (x: 0, y: 0, width: 2, height: 2),
        (x: 2, y: 1, width: 1, height: 1),
        (x: 3, y: 3, width: 1, height: 1),
      ],
    });
  });

  test('keeps tile ids apart', () {
    expect(mergeTiles(_chunk(['1122', '1122', '0000', '0000']), _notZero), {
      1: [(x: 0, y: 0, width: 2, height: 2)],
      2: [(x: 2, y: 0, width: 2, height: 2)],
    });
  });

  test('skips tiles that are not included', () {
    expect(mergeTiles(_chunk(['12', '12']), (id) => id == 2), {
      2: [(x: 1, y: 0, width: 1, height: 2)],
    });
  });

  test('covers every included tile exactly once', () {
    for (var seed = 0; seed < 20; seed++) {
      final chunk = ChunkData(const ChunkCoord(0, 0), ChunkGrid(32));
      for (var i = 0; i < chunk.tiles.length; i++) {
        // Blobs rather than noise, so rectangles actually grow.
        chunk.tiles[i] = hash2(i % 32 ~/ 4, i ~/ 32 ~/ 3, seed) % 3;
      }
      final covered = List.filled(chunk.tiles.length, 0);
      final rects = mergeTiles(chunk, _notZero);
      for (final MapEntry(key: id, value: list) in rects.entries) {
        for (final rect in list) {
          for (var y = rect.y; y < rect.y + rect.height; y++) {
            for (var x = rect.x; x < rect.x + rect.width; x++) {
              expect(chunk.tiles[y * 32 + x], id, reason: 'seed $seed');
              covered[y * 32 + x]++;
            }
          }
        }
      }
      for (var i = 0; i < chunk.tiles.length; i++) {
        expect(covered[i], chunk.tiles[i] == 0 ? 0 : 1, reason: 'seed $seed');
      }
      final count = rects.values.fold(0, (sum, list) => sum + list.length);
      final solid = chunk.tiles.where(_notZero).length;
      expect(count, lessThan(solid / 4), reason: 'seed $seed');
    }
  });
}
