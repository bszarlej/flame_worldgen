import 'package:flame/extensions.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/tile_palette.dart';
import 'package:flutter_test/flutter_test.dart';

const _water = TileType('water');

// Atlas rects of the tiles in columns 0, 1 and 2 of row 0, for 16 × 8 tiles.
const _column0 = Rect.fromLTWH(1, 1, 16, 8);
const _column1 = Rect.fromLTWH(19, 1, 16, 8);
const _column2 = Rect.fromLTWH(37, 1, 16, 8);

void main() {
  late Image image;

  setUpAll(() async {
    // 4 × 2 tiles of 16 × 8 pixels.
    image = await generateImage(64, 16);
  });

  Tileset tileset(TileSprite water) => Tileset(
    image: image,
    tileSize: Vector2(16, 8),
    tiles: {_water: water},
  );

  test('shows each frame for stepTime seconds, then starts over', () {
    final sources = tileset(
      const TileSprite.animated([(0, 0), (1, 0), (2, 0)], stepTime: 0.25),
    ).sources(TilePalette([_water]), seed: 1);

    expect(sources.isAnimated(0), isTrue);
    expect(sources.animatedIds, [0]);
    for (final (time, rect) in [
      (0.0, _column0),
      (0.2, _column0),
      (0.25, _column1),
      (0.6, _column2),
      (0.75, _column0),
      (1000.1, _column1),
    ]) {
      expect(sources.rectAt(0, 3, 4, time), rect, reason: 'at $time s');
    }
    expect(sources.frameAt(0, 0.6), 2);
    expect(sources.frameRect(0, 2), _column2);
  });

  test('every tile shows the same frame', () {
    final sources = tileset(
      const TileSprite.animated([(0, 0), (1, 0)], stepTime: 1),
    ).sources(TilePalette([_water]), seed: 1);
    for (var x = -20; x < 20; x++) {
      expect(sources.rectAt(0, x, x * 3, 1.5), _column1);
    }
  });

  test('static tiles are not animated', () {
    final sources = tileset(
      const TileSprite.at(0, 0),
    ).sources(TilePalette([_water]), seed: 1);
    expect(sources.isAnimated(0), isFalse);
    expect(sources.animatedIds, isEmpty);
  });

  group('rejects', () {
    void expectRejected(TileSprite water, String message) {
      expect(
        () => tileset(water),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
    }

    test('no frames', () {
      expectRejected(
        const TileSprite.animated([], stepTime: 1),
        'at least one frame',
      );
    });

    test('a stepTime that is not positive', () {
      for (final stepTime in [0.0, -1.0, double.nan, double.infinity]) {
        expectRejected(
          TileSprite.animated(const [(0, 0)], stepTime: stepTime),
          'stepTime must be a positive number of seconds',
        );
      }
    });

    test('frames outside the image', () {
      expectRejected(
        const TileSprite.animated([(0, 0), (0, 2)], stepTime: 1),
        'is outside the image',
      );
    });

    test('animations as variants', () {
      expectRejected(
        const TileSprite.variants([
          TileSprite.animated([(0, 0)], stepTime: 1),
        ]),
        'variants must be TileSprite.at',
      );
    });
  });
}
