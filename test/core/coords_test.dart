import 'package:flame_worldgen/src/core/coords.dart';
import 'package:test/test.dart';

void main() {
  group('TileCoord', () {
    test('compares by value', () {
      expect(const TileCoord(1, -2), const TileCoord(1, -2));
      expect({
        const TileCoord(1, -2),
        const TileCoord(0, 0).translate(1, -2),
      }, hasLength(1));
    });

    test('translate', () {
      expect(const TileCoord(1, 2).translate(-3, 4), const TileCoord(-2, 6));
    });
  });

  group('ChunkCoord', () {
    test('compares by value', () {
      expect(const ChunkCoord(-1, 0), const ChunkCoord(-1, 0));
    });

    test('translate', () {
      expect(const ChunkCoord(0, 0).translate(1, -1), const ChunkCoord(1, -1));
    });
  });

  group('ChunkGrid', () {
    final grid = ChunkGrid(32);

    test('rejects sizes that are not a power of two', () {
      for (final size in [0, -32, 3, 24, 33]) {
        expect(() => ChunkGrid(size), throwsArgumentError);
      }
      expect(() => ChunkGrid(1), returnsNormally);
    });

    test('area', () {
      expect(grid.area, 1024);
    });

    group('chunkOf uses floor division', () {
      const cases = {
        (0, 0): (0, 0),
        (31, 31): (0, 0),
        (32, 0): (1, 0),
        (-1, -1): (-1, -1),
        (-32, -32): (-1, -1),
        (-33, 64): (-2, 2),
        (-2147483648, 2147483647): (-67108864, 67108863),
      };

      for (final MapEntry(key: (x, y), value: (cx, cy)) in cases.entries) {
        test('tile ($x, $y) is in chunk ($cx, $cy)', () {
          expect(grid.chunkOf(TileCoord(x, y)), ChunkCoord(cx, cy));
        });
      }
    });

    test('origin', () {
      expect(grid.origin(const ChunkCoord(0, 0)), const TileCoord(0, 0));
      expect(grid.origin(const ChunkCoord(2, -1)), const TileCoord(64, -32));
      expect(grid.origin(const ChunkCoord(-2, -3)), const TileCoord(-64, -96));
    });

    test('localIndex is row-major', () {
      expect(grid.localIndex(const TileCoord(0, 0)), 0);
      expect(grid.localIndex(const TileCoord(1, 0)), 1);
      expect(grid.localIndex(const TileCoord(0, 1)), 32);
      expect(grid.localIndex(const TileCoord(-1, -1)), 1023);
      expect(grid.localIndex(const TileCoord(-32, -31)), 32);
    });

    test('tileAt reverses chunkOf and localIndex', () {
      for (var y = -70; y < 70; y += 3) {
        for (var x = -70; x < 70; x += 5) {
          final tile = TileCoord(x, y);
          final chunk = grid.chunkOf(tile);
          final index = grid.localIndex(tile);
          expect(index, inInclusiveRange(0, grid.area - 1));
          expect(grid.tileAt(chunk, index), tile);
        }
      }
    });
  });
}
