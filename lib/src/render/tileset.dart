import 'package:flame/extensions.dart';

import '../core/tile_palette.dart';
import '../core/tile_type.dart';
import 'tile_sprite.dart';

/// Decides how each [TileType] is drawn, using tiles from one image.
///
/// ```dart
/// Tileset(
///   image: await images.load('terrain.png'),
///   tileSize: Vector2.all(16),
///   tiles: {
///     water: TileSprite.at(0, 0),
///     grass: TileSprite.at(1, 0),
///   },
/// )
/// ```
///
/// Every tile type the world can contain needs an entry: the biomes' ground
/// tiles and anything that passes or the player place. Only tile types in
/// [tiles] can be placed.
class Tileset {
  /// Creates a tileset that cuts [image] into tiles of [tileSize] pixels.
  ///
  /// Throws if [tileSize] isn't positive or if a sprite lies outside the
  /// image.
  Tileset({
    required this.image,
    required Vector2 tileSize,
    required Map<TileType, TileSprite> tiles,
  }) : tileSize = tileSize.clone(),
       tiles = Map.unmodifiable(tiles) {
    if (tileSize.x <= 0 || tileSize.y <= 0) {
      throw ArgumentError.value(tileSize, 'tileSize', 'must be positive');
    }
    final columns = image.width ~/ tileSize.x;
    final rows = image.height ~/ tileSize.y;
    for (final MapEntry(key: type, value: sprite) in tiles.entries) {
      switch (sprite) {
        case StaticTileSprite(:final column, :final row):
          if (column < 0 || row < 0 || column >= columns || row >= rows) {
            throw ArgumentError.value(
              sprite,
              '${type.name} sprite',
              'is outside the image, which has $columns × $rows tiles of '
                  '${tileSize.x.toInt()} × ${tileSize.y.toInt()} pixels',
            );
          }
      }
    }
  }

  /// The image the tiles are cut from.
  final Image image;

  /// The size of one tile in [image], in pixels. The world uses the same
  /// size.
  final Vector2 tileSize;

  /// How each tile type is drawn.
  final Map<TileType, TileSprite> tiles;

  /// Returns the part of [image] to draw for each tile id in [palette].
  ///
  /// Throws if a tile type in [palette] has no sprite.
  List<Rect> sourceRects(TilePalette palette) => [
    for (final type in palette.types) _sourceRect(type),
  ];

  Rect _sourceRect(TileType type) {
    final sprite = tiles[type];
    if (sprite == null) {
      throw ArgumentError.value(
        type,
        'type',
        'has no sprite. Add it to the Tileset\'s tiles',
      );
    }
    return switch (sprite) {
      StaticTileSprite(:final column, :final row) => Rect.fromLTWH(
        column * tileSize.x,
        row * tileSize.y,
        tileSize.x,
        tileSize.y,
      ),
    };
  }
}
