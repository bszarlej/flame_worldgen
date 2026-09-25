/// The position of a tile in the world, in tiles.
///
/// Coordinates must fit in a signed 32-bit integer.
extension type const TileCoord._((int, int) _xy) {
  /// Creates the coordinate of the tile at ([x], [y]).
  const TileCoord(int x, int y) : _xy = (x, y);

  /// The column of the tile.
  int get x => _xy.$1;

  /// The row of the tile.
  int get y => _xy.$2;

  /// Returns the coordinate [dx] tiles to the right and [dy] tiles down.
  TileCoord translate(int dx, int dy) => TileCoord(x + dx, y + dy);
}

/// The position of a chunk in the world, in chunks.
extension type const ChunkCoord._((int, int) _xy) {
  /// Creates the coordinate of the chunk at ([x], [y]).
  const ChunkCoord(int x, int y) : _xy = (x, y);

  /// The column of the chunk.
  int get x => _xy.$1;

  /// The row of the chunk.
  int get y => _xy.$2;

  /// Returns the coordinate [dx] chunks to the right and [dy] chunks down.
  ChunkCoord translate(int dx, int dy) => ChunkCoord(x + dx, y + dy);
}

/// Converts between [TileCoord]s and [ChunkCoord]s for square chunks of
/// [size] × [size] tiles.
///
/// Conversions use floor division, so tile -1 is in chunk -1, not chunk 0.
class ChunkGrid {
  /// Creates a grid of chunks with [size] tiles per side.
  ///
  /// [size] must be a power of two.
  ChunkGrid(this.size) : _shift = size.bitLength - 1, _mask = size - 1 {
    if (size <= 0 || size & (size - 1) != 0) {
      throw ArgumentError.value(size, 'size', 'must be a power of two');
    }
  }

  /// The number of tiles along each side of a chunk.
  final int size;

  /// The number of tiles in a chunk.
  int get area => size * size;

  final int _shift;
  final int _mask;

  // On the web, bitwise operators return unsigned 32-bit results, so `-1 >> 5`
  // is 4294967295. They're only used where the result is non-negative, and
  // negative values are multiplied or divided instead.

  /// Returns the chunk that contains [tile].
  ChunkCoord chunkOf(TileCoord tile) =>
      ChunkCoord(_floorDiv(tile.x), _floorDiv(tile.y));

  /// Divides [value] by [size], rounding towards negative infinity.
  ///
  /// `value & _mask` is the position within the chunk, which is non-negative
  /// even for negative values, so the subtraction lands exactly on the chunk
  /// origin and `~/` has nothing to truncate.
  int _floorDiv(int value) => (value - (value & _mask)) ~/ size;

  /// Returns the top-left tile of [chunk].
  TileCoord origin(ChunkCoord chunk) =>
      TileCoord(chunk.x * size, chunk.y * size);

  /// Returns the row-major index of [tile] within its chunk, from 0 to
  /// [area] - 1.
  int localIndex(TileCoord tile) =>
      (tile.y & _mask) << _shift | (tile.x & _mask);

  /// Returns the tile at the row-major [index] within [chunk].
  TileCoord tileAt(ChunkCoord chunk, int index) => TileCoord(
    chunk.x * size + (index & _mask),
    chunk.y * size + (index >> _shift),
  );
}
