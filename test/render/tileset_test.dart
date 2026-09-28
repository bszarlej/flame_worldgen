import 'package:flame/extensions.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/tile_palette.dart';
import 'package:flutter_test/flutter_test.dart';

const _water = TileType('water');
const _grass = TileType('grass');
const _sand = TileType('sand');

void main() {
  late Image image;

  setUpAll(() async {
    // 4 × 2 tiles of 16 × 8 pixels.
    image = await generateImage(64, 16);
  });

  Tileset tileset(Map<TileType, TileSprite> tiles) =>
      Tileset(image: image, tileSize: Vector2(16, 8), tiles: tiles);

  test('maps tile ids to parts of the image', () {
    final palette = TilePalette([_water, _grass]);
    final rects = tileset({
      _water: const TileSprite.at(0, 0),
      _grass: const TileSprite.at(3, 1),
    }).sourceRects(palette);
    expect(rects, [
      const Rect.fromLTWH(0, 0, 16, 8),
      const Rect.fromLTWH(48, 8, 16, 8),
    ]);
  });

  test('tile types without a sprite throw when resolved', () {
    final palette = TilePalette([_water, _sand]);
    expect(
      () => tileset({_water: const TileSprite.at(0, 0)}).sourceRects(palette),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains("Add it to the Tileset's tiles"),
        ),
      ),
    );
  });

  test('sprites outside the image throw', () {
    for (final sprite in const [
      TileSprite.at(4, 0),
      TileSprite.at(0, 2),
      TileSprite.at(-1, 0),
    ]) {
      expect(
        () => tileset({_water: sprite}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('4 × 2 tiles'),
          ),
        ),
      );
    }
  });

  test('tile size must be positive', () {
    expect(
      () => Tileset(image: image, tileSize: Vector2(0, 8), tiles: const {}),
      throwsArgumentError,
    );
  });

  test('keeps its own copy of the tile size', () {
    final size = Vector2.all(16);
    final set = Tileset(image: image, tileSize: size, tiles: const {});
    size.setValues(1, 1);
    expect(set.tileSize, Vector2.all(16));
  });

  test('tiles cannot be changed afterwards', () {
    final set = tileset({_water: const TileSprite.at(0, 0)});
    expect(
      () => set.tiles[_grass] = const TileSprite.at(1, 0),
      throwsUnsupportedError,
    );
  });
}
