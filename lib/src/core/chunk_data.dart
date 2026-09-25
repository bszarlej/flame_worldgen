import 'dart:typed_data';

import 'coords.dart';
import 'generation/scatter.dart';

/// The generated contents of one chunk: a tile id and a biome index per
/// tile, stored row by row, and the chunk's scatter spots.
///
/// Holds only plain data, so it can be sent between isolates. Tile
/// ids refer to the world's `TilePalette`, and biome indexes to the order of
/// the world's biomes.
class ChunkData {
  /// Creates an empty chunk at [coord], with every tile id and biome index 0.
  ChunkData(this.coord, this.grid)
    : tiles = Uint16List(grid.area),
      biomes = Uint8List(grid.area);

  /// Creates a chunk at [coord] from existing [tiles] and [biomes].
  ///
  /// Both lists must have one entry per tile.
  ChunkData.from(this.coord, this.grid, this.tiles, this.biomes) {
    if (tiles.length != grid.area) {
      throw ArgumentError.value(
        tiles.length,
        'tiles.length',
        'must be ${grid.area}',
      );
    }
    if (biomes.length != grid.area) {
      throw ArgumentError.value(
        biomes.length,
        'biomes.length',
        'must be ${grid.area}',
      );
    }
  }

  /// The largest number of biomes a world can have.
  static const maxBiomes = 256;

  /// Where the chunk is in the world.
  final ChunkCoord coord;

  /// The size of the chunk and how its tiles are indexed.
  final ChunkGrid grid;

  /// The tile id of every tile, indexed by [ChunkGrid.localIndex].
  final Uint16List tiles;

  /// The biome index of every tile, indexed by [ChunkGrid.localIndex].
  final Uint8List biomes;

  /// Where objects go in this chunk.
  final List<ScatterSpot> spots = [];

  /// The top-left tile of the chunk.
  TileCoord get origin => grid.origin(coord);

  /// Whether [tile] is inside this chunk.
  bool contains(TileCoord tile) => grid.chunkOf(tile) == coord;

  /// Returns the tile id at [tile], which must be inside this chunk.
  int tileIdAt(TileCoord tile) => tiles[_indexOf(tile)];

  /// Sets the tile id at [tile], which must be inside this chunk.
  void setTileId(TileCoord tile, int id) => tiles[_indexOf(tile)] = id;

  /// Returns the biome index at [tile], which must be inside this chunk.
  int biomeAt(TileCoord tile) => biomes[_indexOf(tile)];

  /// Returns the tile coordinates in this chunk, row by row.
  Iterable<TileCoord> get coords =>
      Iterable.generate(grid.area, (index) => grid.tileAt(coord, index));

  int _indexOf(TileCoord tile) {
    if (!contains(tile)) {
      throw ArgumentError.value(tile, 'tile', 'is not in chunk $coord');
    }
    return grid.localIndex(tile);
  }

  @override
  String toString() => 'ChunkData($coord)';
}
