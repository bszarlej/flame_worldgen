/// How a tile type is drawn: which part of the tileset image it uses.
///
/// ```dart
/// TileSprite.at(3, 0) // the tile in column 3, row 0 of the tileset
/// ```
sealed class TileSprite {
  const TileSprite._();

  /// The tile at [column] and [row] of the tileset image, counted in tiles
  /// from the top left, starting at 0.
  const factory TileSprite.at(int column, int row) = StaticTileSprite;
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
