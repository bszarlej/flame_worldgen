import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/tile_palette.dart';
import 'package:flutter_test/flutter_test.dart';

const _water = TileType('water');
const _grass = TileType('grass');
const _sand = TileType('sand');

/// A 2 × 1 sheet of 3 × 2 pixel tiles. Every pixel has its own colour, so
/// the test can tell exactly which one was copied where.
Future<Image> _numberedSheet() async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  for (var y = 0; y < 2; y++) {
    for (var x = 0; x < 6; x++) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
        Paint()..color = Color.fromARGB(255, x * 40, y * 100, 7),
      );
    }
  }
  return recorder.endRecording().toImage(6, 2);
}

void main() {
  late Image image;

  setUpAll(() async {
    // 4 × 2 tiles of 16 × 8 pixels.
    image = await generateImage(64, 16);
  });

  Tileset tileset(Map<TileType, TileSprite> tiles) =>
      Tileset(image: image, tileSize: Vector2(16, 8), tiles: tiles);

  test('maps tile ids to tiles in the padded atlas', () {
    final palette = TilePalette([_water, _grass]);
    final rects = tileset({
      _water: const TileSprite.at(0, 0),
      _grass: const TileSprite.at(3, 1),
    }).sourceRects(palette);
    // Each tile takes 18 × 10 pixels in the atlas: itself plus a 1-pixel
    // border.
    expect(rects, [
      const Rect.fromLTWH(1, 1, 16, 8),
      const Rect.fromLTWH(55, 11, 16, 8),
    ]);
  });

  test('the atlas surrounds each tile with a copy of its own edge', () async {
    final set = Tileset(
      image: await _numberedSheet(),
      tileSize: Vector2(3, 2),
      tiles: const <TileType, TileSprite>{},
    );
    final atlas = set.atlas;
    expect((atlas.width, atlas.height), (10, 4));

    final bytes = (await atlas.toByteData())!;
    final sheet = (await set.image.toByteData())!;
    int atlasPixel(int x, int y) => bytes.getUint32((y * 10 + x) * 4);
    int sheetPixel(int x, int y) => sheet.getUint32((y * 6 + x) * 4);

    // Every atlas pixel shows the nearest pixel of its own tile.
    for (var tile = 0; tile < 2; tile++) {
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 5; x++) {
          final sourceX = tile * 3 + (x - 1).clamp(0, 2);
          final sourceY = (y - 1).clamp(0, 1);
          expect(
            atlasPixel(tile * 5 + x, y),
            sheetPixel(sourceX, sourceY),
            reason: 'tile $tile, atlas pixel ($x, $y)',
          );
        }
      }
    }
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

  test('tile size must be a positive whole number of pixels', () {
    for (final size in [Vector2(0, 8), Vector2(16, -8), Vector2(16.5, 8)]) {
      expect(
        () => Tileset(
          image: image,
          tileSize: size,
          tiles: const <TileType, TileSprite>{},
        ),
        throwsArgumentError,
      );
    }
  });

  test('keeps its own copy of the tile size', () {
    final size = Vector2.all(16);
    final set = Tileset(
      image: image,
      tileSize: size,
      tiles: const <TileType, TileSprite>{},
    );
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
