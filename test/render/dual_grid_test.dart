import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/render/dual_grid.dart';
import 'package:flutter_test/flutter_test.dart';

const _water = TileType('water');
const _sand = TileType('sand');
const _grass = TileType('grass');
const _stone = TileType('stone');
const _snow = TileType('snow');

/// Whether corner [corner] (0 top left to 3 bottom right) is set in [mask].
bool _has(int mask, int corner) => mask & (8 >> corner) != 0;

void main() {
  group('dualGridLayout', () {
    test('has a tile for every mask', () {
      expect(dualGridLayout.toSet(), {for (var i = 0; i < 16; i++) i});
    });

    test('matches the reference layout', () {
      // From jess::codes' DualGridTilemap.cs.
      expect(dualGridLayout[0], 12); // empty
      expect(dualGridLayout[15], 6); // full
      expect(dualGridLayout[2], 0); // bottom left only
      expect(dualGridLayout[1], 13); // bottom right only
      expect(dualGridLayout[4], 8); // top right only
      expect(dualGridLayout[8], 15); // top left only
      expect(dualGridLayout[9], 4); // top left and bottom right
    });

    test('neighbouring tiles in the block match along their edges', () {
      final maskAt = {
        for (var mask = 0; mask < 16; mask++) dualGridLayout[mask]: mask,
      };
      for (var row = 0; row < 4; row++) {
        for (var column = 0; column < 4; column++) {
          final mask = maskAt[row * 4 + column]!;
          if (column < 3) {
            final right = maskAt[row * 4 + column + 1]!;
            expect(_has(mask, 1), _has(right, 0), reason: '($column, $row)');
            expect(_has(mask, 3), _has(right, 2), reason: '($column, $row)');
          }
          if (row < 3) {
            final below = maskAt[(row + 1) * 4 + column]!;
            expect(_has(mask, 2), _has(below, 0), reason: '($column, $row)');
            expect(_has(mask, 3), _has(below, 1), reason: '($column, $row)');
          }
        }
      }
    });
  });

  group('orderTerrains', () {
    test('puts every upper terrain above its lower one', () {
      expect(orderTerrains([(_grass, _sand), (_sand, _water)]), [
        _water,
        _sand,
        _grass,
      ]);
    });

    test('keeps unrelated terrains in the order they appear', () {
      expect(orderTerrains([(_sand, _water), (_snow, _stone)]), [
        _water,
        _sand,
        _stone,
        _snow,
      ]);
    });

    test('accepts a terrain over several others', () {
      expect(
        orderTerrains([(_grass, _water), (_grass, _sand), (_sand, _water)]),
        [_water, _sand, _grass],
      );
    });

    test('rejects transitions that contradict each other', () {
      expect(
        () =>
            orderTerrains([(_sand, _water), (_grass, _sand), (_water, _grass)]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('contradict each other'),
          ),
        ),
      );
    });
  });
}
