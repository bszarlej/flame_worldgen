import 'package:flame/extensions.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/tile_palette.dart';
import 'package:flame_worldgen/src/render/tile_sources.dart';
import 'package:flutter_test/flutter_test.dart';

const _water = TileType('water');
const _grass = TileType('grass');

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

  Tileset tileset(TileSprite grass) => Tileset(
    image: image,
    tileSize: Vector2(16, 8),
    tiles: {_water: const TileSprite.at(3, 1), _grass: grass},
  );

  final palette = TilePalette([_water, _grass]);
  const grassId = 1;

  /// How often each rect is drawn for grass in a 100 × 100 tile area.
  Map<Rect, int> counts(TileSources sources) {
    final counts = <Rect, int>{};
    for (var y = -50; y < 50; y++) {
      for (var x = -50; x < 50; x++) {
        final rect = sources.rectAt(grassId, x, y, 0);
        counts[rect] = (counts[rect] ?? 0) + 1;
      }
    }
    return counts;
  }

  test('picks variants in proportion to their weights', () {
    final sources = tileset(
      const TileSprite.variants(
        [TileSprite.at(0, 0), TileSprite.at(1, 0), TileSprite.at(2, 0)],
        weights: [6, 3, 1],
      ),
    ).sources(palette, seed: 42);

    final result = counts(sources);
    expect(result.keys.toSet(), {_column0, _column1, _column2});
    expect(result[_column0]! / 10000, closeTo(0.6, 0.02));
    expect(result[_column1]! / 10000, closeTo(0.3, 0.02));
    expect(result[_column2]! / 10000, closeTo(0.1, 0.02));
  });

  test('without weights, every variant is equally likely', () {
    final sources = tileset(
      const TileSprite.variants([TileSprite.at(0, 0), TileSprite.at(1, 0)]),
    ).sources(palette, seed: 42);

    final result = counts(sources);
    expect(result[_column0]! / 10000, closeTo(0.5, 0.02));
    expect(result[_column1]! / 10000, closeTo(0.5, 0.02));
  });

  test('the choice depends only on the tile and the world seed', () {
    const grass = TileSprite.variants([
      TileSprite.at(0, 0),
      TileSprite.at(1, 0),
    ]);
    List<Rect> pattern(int seed) => [
      for (var x = 0; x < 64; x++)
        tileset(grass).sources(palette, seed: seed).rectAt(grassId, x, 7, 0),
    ];

    expect(pattern(42), pattern(42));
    expect(pattern(42), isNot(pattern(43)));
  });

  test('a single variant is always picked', () {
    final sources = tileset(
      const TileSprite.variants([TileSprite.at(2, 0)], weights: [5]),
    ).sources(palette, seed: 1);
    expect(counts(sources).keys, [_column2]);
  });

  test('pickVariant covers the whole range of hashes', () {
    // Weights 1, 1 and 2.
    const cumulative = [1.0, 2.0, 4.0];
    expect(pickVariant(cumulative, 0), 0);
    expect(pickVariant(cumulative, 0xFFFFFFFF), 2);
    // Just below and at a quarter of the hash range.
    expect(pickVariant(cumulative, 0x3FFFFFFF), 0);
    expect(pickVariant(cumulative, 0x40000000), 1);
  });

  group('rejects', () {
    void expectRejected(TileSprite grass, String message) {
      expect(
        () => tileset(grass),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
    }

    test('no variants', () {
      expectRejected(const TileSprite.variants([]), 'at least one variant');
    });

    test('a weight per variant', () {
      expectRejected(
        const TileSprite.variants(
          [TileSprite.at(0, 0), TileSprite.at(1, 0)],
          weights: [1],
        ),
        '2 variants but 1 weights',
      );
    });

    test('weights that are not positive', () {
      for (final weight in [0.0, -1.0, double.nan, double.infinity]) {
        expectRejected(
          TileSprite.variants(const [TileSprite.at(0, 0)], weights: [weight]),
          'weights must be positive',
        );
      }
    });

    test('variants of variants', () {
      expectRejected(
        const TileSprite.variants([
          TileSprite.variants([TileSprite.at(0, 0)]),
        ]),
        'variants must be TileSprite.at',
      );
    });

    test('variants outside the image', () {
      expectRejected(
        const TileSprite.variants([TileSprite.at(0, 0), TileSprite.at(9, 0)]),
        'is outside the image',
      );
    });
  });
}
