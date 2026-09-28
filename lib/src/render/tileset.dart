import 'dart:ui';

import 'package:flame/extensions.dart';

import '../core/tile_palette.dart';
import '../core/tile_type.dart';
import 'autotile.dart';
import 'dual_grid.dart';
import 'tile_sources.dart';
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
///
/// Without [transitions], terrains meet at hard square edges. See
/// [Autotile.dualGrid] for smooth ones.
class Tileset {
  /// Creates a tileset that cuts [image] into tiles of [tileSize] pixels.
  ///
  /// Throws if [tileSize] isn't a positive whole number of pixels, if a
  /// sprite is invalid, such as outside the image, or if the transitions
  /// are invalid.
  Tileset({
    required this.image,
    required Vector2 tileSize,
    required Map<TileType, TileSprite> tiles,
    List<Autotile> transitions = const [],
  }) : tileSize = tileSize.clone(),
       tiles = Map.unmodifiable(tiles),
       transitions = List.unmodifiable(transitions) {
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
      _checkSprite(type, sprite);
    }
    _terrains = _checkTransitions();
  }

  /// The image the tiles are cut from.
  final Image image;

  /// The size of one tile in [image], in pixels. The world uses the same
  /// size.
  final Vector2 tileSize;

  /// How each tile type is drawn.
  final Map<TileType, TileSprite> tiles;

  /// The smooth transitions between terrains.
  final List<Autotile> transitions;

  /// The terrains of [transitions], lowest first.
  late final List<TileType> _terrains;

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

  /// Returns which part of [atlas] to draw for each tile id in [palette],
  /// in the world with [seed].
  ///
  /// Throws if a tile type in [palette] has no sprite.
  TileSources sources(TilePalette palette, {required int seed}) {
    final rects = <List<Rect>>[];
    final weights = <List<double>?>[];
    final stepTimes = <double?>[];
    for (final type in palette.types) {
      switch (tiles[type]) {
        case null:
          throw ArgumentError.value(
            type,
            'type',
            "has no sprite. Add it to the Tileset's tiles",
          );
        case StaticTileSprite(:final column, :final row):
          rects.add([_atlasRect(column, row)]);
          weights.add(null);
          stepTimes.add(null);
        case VariantTileSprite(:final sprites, weights: final given):
          rects.add([
            for (final sprite in sprites.cast<StaticTileSprite>())
              _atlasRect(sprite.column, sprite.row),
          ]);
          var total = 0.0;
          weights.add([
            for (var i = 0; i < sprites.length; i++) total += given?[i] ?? 1,
          ]);
          stepTimes.add(null);
        case AnimatedTileSprite(:final frames, :final stepTime):
          rects.add([
            for (final (column, row) in frames) _atlasRect(column, row),
          ]);
          weights.add(null);
          stepTimes.add(stepTime);
      }
    }
    return TileSources(
      rects: rects,
      cumulativeWeights: weights,
      stepTimes: stepTimes,
      seed: seed,
    );
  }

  /// Returns the terrains and transitions for the tile ids of [palette], or
  /// null if there are no transitions.
  DualGrid? dualGrid(TilePalette palette) {
    if (transitions.isEmpty) return null;
    return DualGrid(
      [for (final type in palette.types) type.name],
      [for (final type in palette.types) _terrains.indexOf(type)],
      {
        for (final DualGridAutotile(:upper, :lower, at: (column, row))
            in transitions.cast<DualGridAutotile>())
          (palette.idOf(upper), palette.idOf(lower)): [
            for (final index in dualGridLayout)
              _atlasRect(column + index % 4, row + index ~/ 4),
          ],
      },
    );
  }

  List<TileType> _checkTransitions() {
    if (transitions.isEmpty) return const [];
    if (_width.isOdd || _height.isOdd) {
      throw ArgumentError.value(
        tileSize,
        'tileSize',
        'must be an even number of pixels with transitions, because tiles '
            'are drawn in quarters',
      );
    }
    final pairs = <(TileType, TileType)>[];
    for (final transition in transitions) {
      switch (transition) {
        case DualGridAutotile(
          :final upper,
          :final lower,
          at: (final column, final row),
        ):
          if (upper == lower) {
            throw ArgumentError.value(
              transition,
              'transitions',
              'needs two different terrains',
            );
          }
          for (final terrain in [upper, lower]) {
            if (!tiles.containsKey(terrain)) {
              throw ArgumentError.value(
                transition,
                'transitions',
                "${terrain.name} has no sprite. Add it to the Tileset's tiles",
              );
            }
          }
          if (pairs.contains((upper, lower)) ||
              pairs.contains((lower, upper))) {
            throw ArgumentError.value(
              transition,
              'transitions',
              'There are two transitions between ${upper.name} and '
                  '${lower.name}',
            );
          }
          if (column < 0 ||
              row < 0 ||
              column + 4 > _columns ||
              row + 4 > _rows) {
            throw ArgumentError.value(
              transition,
              'transitions',
              'The 4 × 4 block at ($column, $row) is outside the image, which '
                  'has $_columns × $_rows tiles of $_width × $_height pixels',
            );
          }
          pairs.add((upper, lower));
      }
    }
    return orderTerrains(pairs);
  }

  void _checkSprite(TileType type, TileSprite sprite) {
    switch (sprite) {
      case StaticTileSprite(:final column, :final row):
        if (column < 0 || row < 0 || column >= _columns || row >= _rows) {
          throw ArgumentError.value(
            sprite,
            '${type.name} sprite',
            'is outside the image, which has $_columns × $_rows tiles of '
                '$_width × $_height pixels',
          );
        }
      case VariantTileSprite(:final sprites, :final weights):
        if (sprites.isEmpty) {
          throw ArgumentError.value(
            sprite,
            '${type.name} sprite',
            'needs at least one variant',
          );
        }
        if (weights != null && weights.length != sprites.length) {
          throw ArgumentError.value(
            sprite,
            '${type.name} sprite',
            'has ${sprites.length} variants but ${weights.length} weights',
          );
        }
        if (weights != null && !weights.every((w) => w > 0 && w.isFinite)) {
          throw ArgumentError.value(
            sprite,
            '${type.name} sprite',
            'weights must be positive',
          );
        }
        for (final variant in sprites) {
          if (variant is! StaticTileSprite) {
            throw ArgumentError.value(
              sprite,
              '${type.name} sprite',
              'variants must be TileSprite.at',
            );
          }
          _checkSprite(type, variant);
        }
      case AnimatedTileSprite(:final frames, :final stepTime):
        if (frames.isEmpty) {
          throw ArgumentError.value(
            sprite,
            '${type.name} sprite',
            'needs at least one frame',
          );
        }
        if (!(stepTime > 0 && stepTime.isFinite)) {
          throw ArgumentError.value(
            sprite,
            '${type.name} sprite',
            'stepTime must be a positive number of seconds',
          );
        }
        for (final (column, row) in frames) {
          _checkSprite(type, TileSprite.at(column, row));
        }
    }
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
