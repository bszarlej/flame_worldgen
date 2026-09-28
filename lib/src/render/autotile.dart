import '../core/tile_type.dart';

/// A smooth transition between two terrains, instead of hard square edges.
///
/// ```dart
/// Tileset(
///   ...,
///   transitions: [
///     Autotile.dualGrid(upper: sand, lower: water, at: (0, 8)),
///     Autotile.dualGrid(upper: grass, lower: sand, at: (4, 8)),
///   ],
/// )
/// ```
sealed class Autotile {
  const Autotile._();

  /// A dual-grid transition that draws [upper] on top of [lower], using the
  /// 4 × 4 block of tiles whose top-left tile is at [at], (column, row) of
  /// the tileset image.
  ///
  /// The map is drawn on a second grid, offset by half a tile, so each drawn
  /// tile covers the corners of 4 world tiles. The block has one tile for
  /// each combination of corners that are [upper], marked here, in the
  /// layout of jess::codes' dual-grid tilesets. Neighbouring tiles in the
  /// block match along their shared edges, so it can be painted as one
  /// picture.
  ///
  /// ```text
  ///  ┌───┬───┬───┬───┐
  ///  │ ▖ │ ▐ │ ▙ │ ▄ │
  ///  ├───┼───┼───┼───┤
  ///  │ ▚ │ ▟ │ █ │ ▛ │
  ///  ├───┼───┼───┼───┤
  ///  │ ▝ │ ▀ │ ▜ │ ▌ │
  ///  ├───┼───┼───┼───┤
  ///  │   │ ▗ │ ▞ │ ▘ │
  ///  └───┴───┴───┴───┘
  /// ```
  ///
  /// [upper] is drawn over [lower], so transition tiles can be transparent
  /// where [lower] shows, and an animated [lower] stays animated.
  const factory Autotile.dualGrid({
    required TileType upper,
    required TileType lower,
    required (int, int) at,
  }) = DualGridAutotile;
}

/// An [Autotile] drawn with the dual-grid technique.
final class DualGridAutotile extends Autotile {
  /// Creates a transition from [lower] to [upper], using the 4 × 4 block at
  /// [at].
  const DualGridAutotile({
    required this.upper,
    required this.lower,
    required this.at,
  }) : super._();

  /// The terrain drawn on top.
  final TileType upper;

  /// The terrain drawn below.
  final TileType lower;

  /// The (column, row) of the block's top-left tile in the tileset image.
  final (int, int) at;

  @override
  String toString() =>
      'Autotile.dualGrid(upper: ${upper.name}, lower: ${lower.name}, '
      'at: $at)';
}
