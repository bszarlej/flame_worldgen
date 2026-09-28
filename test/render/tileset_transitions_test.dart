import 'package:flame/extensions.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/tile_palette.dart';
import 'package:flutter_test/flutter_test.dart';

const _water = TileType('water');
const _sand = TileType('sand');
const _grass = TileType('grass');
const _road = TileType('road');

void main() {
  late Image image;

  setUpAll(() async {
    // 8 × 4 tiles of 16 × 16 pixels.
    image = await generateImage(128, 64);
  });

  Tileset tileset(List<Autotile> transitions, {double tileSize = 16}) =>
      Tileset(
        image: image,
        tileSize: Vector2.all(tileSize),
        tiles: {
          _water: const TileSprite.at(0, 0),
          _sand: const TileSprite.at(1, 0),
          _grass: const TileSprite.at(2, 0),
          _road: const TileSprite.at(3, 0),
        },
        transitions: transitions,
      );

  final palette = TilePalette([_water, _sand, _grass, _road]);

  test('without transitions, there is no dual grid', () {
    expect(tileset([]).dualGrid(palette), isNull);
  });

  test('ranks terrains and finds the transition tiles', () {
    final dualGrid = tileset(const [
      Autotile.dualGrid(upper: _grass, lower: _sand, at: (4, 0)),
      Autotile.dualGrid(upper: _sand, lower: _water, at: (0, 0)),
    ]).dualGrid(palette)!;

    expect([for (var id = 0; id < 4; id++) dualGrid.rank(id)], [0, 1, 2, -1]);
    expect(dualGrid.name(3), 'road');

    // Each tile takes 18 × 18 pixels in the atlas.
    final sandOverWater = dualGrid.transition(1, 0)!;
    expect(sandOverWater, hasLength(16));
    // The empty tile is at column 0, row 3, the full one at column 2, row 1.
    expect(sandOverWater[0], const Rect.fromLTWH(1, 55, 16, 16));
    expect(sandOverWater[15], const Rect.fromLTWH(37, 19, 16, 16));
    // Bottom left only is the block's first tile.
    expect(dualGrid.transition(2, 1)![2], const Rect.fromLTWH(73, 1, 16, 16));

    expect(dualGrid.transition(0, 1), isNull);
    expect(dualGrid.transition(2, 0), isNull);
  });

  group('rejects', () {
    void expectRejected(List<Autotile> transitions, String message) {
      expect(
        () => tileset(transitions),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
    }

    test('a transition from a terrain to itself', () {
      expectRejected(const [
        Autotile.dualGrid(upper: _sand, lower: _sand, at: (0, 0)),
      ], 'two different terrains');
    });

    test('terrains without a sprite', () {
      expectRejected(const [
        Autotile.dualGrid(upper: TileType('lava'), lower: _sand, at: (0, 0)),
      ], "lava has no sprite. Add it to the Tileset's tiles");
    });

    test('two transitions between the same terrains', () {
      for (final second in const [
        Autotile.dualGrid(upper: _sand, lower: _water, at: (4, 0)),
        Autotile.dualGrid(upper: _water, lower: _sand, at: (4, 0)),
      ]) {
        expectRejected([
          const Autotile.dualGrid(upper: _sand, lower: _water, at: (0, 0)),
          second,
        ], 'two transitions between');
      }
    });

    test('blocks outside the image', () {
      for (final at in const [(5, 0), (0, 1), (-1, 0)]) {
        expectRejected([
          Autotile.dualGrid(upper: _sand, lower: _water, at: at),
        ], 'is outside the image, which has 8 × 4 tiles');
      }
    });

    test('transitions that contradict each other', () {
      expectRejected(const [
        Autotile.dualGrid(upper: _sand, lower: _water, at: (0, 0)),
        Autotile.dualGrid(upper: _water, lower: _grass, at: (4, 0)),
        Autotile.dualGrid(upper: _grass, lower: _sand, at: (4, 0)),
      ], 'contradict each other');
    });

    test('an odd tile size', () {
      expect(
        () => tileset(const [
          Autotile.dualGrid(upper: _sand, lower: _water, at: (0, 0)),
        ], tileSize: 15),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('even number of pixels'),
          ),
        ),
      );
    });
  });
}
