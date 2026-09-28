/// How a tile type is drawn: which part of the tileset image it uses.
///
/// ```dart
/// TileSprite.at(3, 0) // the tile in column 3, row 0 of the tileset
///
/// // One of several tiles, 10 times as often the first as each other one.
/// TileSprite.variants(
///   [TileSprite.at(1, 1), TileSprite.at(0, 5), TileSprite.at(1, 5)],
///   weights: [10, 1, 1],
/// )
///
/// // Four frames, each shown for 0.3 seconds.
/// TileSprite.animated([(0, 3), (1, 3), (2, 3), (3, 3)], stepTime: 0.3)
/// ```
sealed class TileSprite {
  const TileSprite._();

  /// The tile at [column] and [row] of the tileset image, counted in tiles
  /// from the top left, starting at 0.
  const factory TileSprite.at(int column, int row) = StaticTileSprite;

  /// One of [sprites] per tile, picked at random but the same every time the
  /// tile is drawn, for the same world seed.
  ///
  /// Each sprite must be a [TileSprite.at]. [weights], if given, has one
  /// positive weight per sprite: a sprite with weight 2 is picked twice as
  /// often as one with weight 1. Without weights, every sprite is equally
  /// likely.
  const factory TileSprite.variants(
    List<TileSprite> sprites, {
    List<double>? weights,
  }) = VariantTileSprite;

  /// An animation that shows each of [frames], given as (column, row) of the
  /// tileset image, for [stepTime] seconds, then starts over.
  ///
  /// All tiles of a type show the same frame at the same time.
  const factory TileSprite.animated(
    List<(int, int)> frames, {
    required double stepTime,
  }) = AnimatedTileSprite;
}

/// A [TileSprite] that always shows the same tile.
final class StaticTileSprite extends TileSprite {
  /// Creates a sprite for the tile at [column] and [row].
  const StaticTileSprite(this.column, this.row) : super._();

  /// The column in the tileset image, in tiles.
  final int column;

  /// The row in the tileset image, in tiles.
  final int row;

  @override
  String toString() => 'TileSprite.at($column, $row)';
}

/// A [TileSprite] that shows one of several tiles, chosen per tile.
final class VariantTileSprite extends TileSprite {
  /// Creates a sprite that picks one of [sprites], weighted by [weights].
  const VariantTileSprite(this.sprites, {this.weights}) : super._();

  /// The sprites to pick from.
  final List<TileSprite> sprites;

  /// How often each sprite is picked, relative to the others. Null means
  /// equally often.
  final List<double>? weights;

  @override
  String toString() => 'TileSprite.variants($sprites, weights: $weights)';
}

/// A [TileSprite] that cycles through several tiles.
final class AnimatedTileSprite extends TileSprite {
  /// Creates an animation that shows each of [frames] for [stepTime]
  /// seconds.
  const AnimatedTileSprite(this.frames, {required this.stepTime}) : super._();

  /// The (column, row) of each frame in the tileset image, in tiles.
  final List<(int, int)> frames;

  /// How long each frame is shown, in seconds.
  final double stepTime;

  @override
  String toString() => 'TileSprite.animated($frames, stepTime: $stepTime)';
}
