import 'dart:ui';

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
  /// Throws if [tileSize] isn't a positive whole number of pixels or if a
  /// sprite lies outside the image.
  Tileset({
    required this.image,
    required Vector2 tileSize,
    required Map<TileType, TileSprite> tiles,
  }) : tileSize = tileSize.clone(),
       tiles = Map.unmodifiable(tiles) {
    if (tileSize.x <= 0 ||
        tileSize.y <= 0 ||
        tileSize.x != tileSize.x.roundToDouble() ||
        tileSize.y != tileSize.y.roundToDouble()) {
      throw ArgumentError.value(
        tileSize,
        'tileSize',
        'must be a positive whole number of pixels',
      );
    }
    for (final MapEntry(key: type, value: sprite) in tiles.entries) {
      switch (sprite) {
        case StaticTileSprite(:final column, :final row):
          if (column < 0 || row < 0 || column >= _columns || row >= _rows) {
            throw ArgumentError.value(
              sprite,
              '${type.name} sprite',
              'is outside the image, which has $_columns × $_rows tiles of '
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

  int get _width => tileSize.x.toInt();
  int get _height => tileSize.y.toInt();
  int get _columns => image.width ~/ _width;
  int get _rows => image.height ~/ _height;

  /// The image the map draws from: [image] with a 1-pixel copy of each
  /// tile's own edge around it.
  ///
  /// When the camera isn't at a whole pixel, the GPU can sample just outside
  /// a tile. Without the border, that sample comes from the neighbouring tile
  /// in the image and shows up as thin lines between tiles.
  late final Image atlas = _extrude();

  /// Returns the part of [atlas] to draw for each tile id in [palette].
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
      StaticTileSprite(:final column, :final row) => _atlasRect(column, row),
    };
  }

  Rect _atlasRect(int column, int row) => Rect.fromLTWH(
    column * (_width + 2) + 1.0,
    row * (_height + 2) + 1.0,
    tileSize.x,
    tileSize.y,
  );

  Image _extrude() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    final w = _width.toDouble();
    final h = _height.toDouble();

    void copy(
      double sx,
      double sy,
      double sw,
      double sh,
      double dx,
      double dy,
    ) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(sx, sy, sw, sh),
        Rect.fromLTWH(dx, dy, sw, sh),
        paint,
      );
    }

    for (var row = 0; row < _rows; row++) {
      for (var column = 0; column < _columns; column++) {
        final sx = column * w;
        final sy = row * h;
        final target = _atlasRect(column, row);
        final dx = target.left;
        final dy = target.top;

        copy(sx, sy, w, h, dx, dy);
        // Edges.
        copy(sx, sy, w, 1, dx, dy - 1);
        copy(sx, sy + h - 1, w, 1, dx, dy + h);
        copy(sx, sy, 1, h, dx - 1, dy);
        copy(sx + w - 1, sy, 1, h, dx + w, dy);
        // Corners.
        copy(sx, sy, 1, 1, dx - 1, dy - 1);
        copy(sx + w - 1, sy, 1, 1, dx + w, dy - 1);
        copy(sx, sy + h - 1, 1, 1, dx - 1, dy + h);
        copy(sx + w - 1, sy + h - 1, 1, 1, dx + w, dy + h);
      }
    }

    return recorder.endRecording().toImageSync(
      _columns * (_width + 2),
      _rows * (_height + 2),
    );
  }
}
