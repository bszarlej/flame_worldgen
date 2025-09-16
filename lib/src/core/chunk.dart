import 'package:fast_noise/fast_noise.dart';

import '../math/vector2i.dart';

/// Represents a chunk of tiles in a procedural world.
///
/// Each chunk is a rectangular section of the world and contains a height map
/// generated from a 2D noise function. The chunk can convert between local
/// tile coordinates, global tile coordinates, and world positions.
class Chunk {
  /// The noise generator used to create the height map.
  final Noise2 noise;

  /// The coordinates of this chunk in chunk space.
  ///
  /// For example, (0,0) is the origin chunk, (1,0) is one chunk to the right, etc.
  final Vector2i chunkCoords;

  /// The size of this chunk in tiles (width x height).
  final Vector2i chunkSize;

  /// The size of a single tile in pixels (width x height).
  final Vector2i tileSize;

  /// The height map for all tiles in this chunk.
  ///
  /// Stored as a flat list in row-major order.
  final List<double> _heightMap;

  /// Creates a new [Chunk] and generates its height map using [noise].
  ///
  /// [chunkCoords] specifies the chunk’s position in chunk-space.
  /// [chunkSize] defines how many tiles wide and tall the chunk is.
  /// [tileSize] defines the size of each tile in pixels.
  Chunk({
    required this.noise,
    required this.chunkCoords,
    required this.chunkSize,
    required this.tileSize,
  }) : assert(
         chunkSize.x > 0 && chunkSize.y > 0,
         'Chunk size must be positive',
       ),
       assert(tileSize.x > 0 && tileSize.y > 0, 'Tile size must be positive'),
       _heightMap = List.filled(chunkSize.x * chunkSize.y, 0, growable: false) {
    _generateHeightMap();
  }

  /// The total size of this chunk in world coordinates (pixels).
  Vector2i get chunkWorldSize =>
      Vector2i(chunkSize.x * tileSize.x, chunkSize.y * tileSize.y);

  /// Returns the height map for this chunk.
  List<double> get heightMap => _heightMap;

  /// Converts local tile coordinates ([col], [row]) to global tile coordinates.
  Vector2i getGlobalTileCoords(int col, int row) {
    final worldPos = getTileWorldPosition(col, row);
    return Vector2i(
      (worldPos.x / tileSize.x).floor(),
      (worldPos.y / tileSize.y).floor(),
    );
  }

  /// Returns the noise value (height) for the tile at ([col], [row]).
  double getNoise(int col, int row) {
    final index = row * chunkSize.x + col;
    return _heightMap[index];
  }

  /// Returns the world position (in pixels) for the tile at ([col], [row]).
  Vector2i getTileWorldPosition(int col, int row) {
    return Vector2i(
      chunkCoords.x * chunkSize.x * tileSize.x + col * tileSize.x,
      chunkCoords.y * chunkSize.y * tileSize.y + row * tileSize.y,
    );
  }

  /// Generates the height map for this chunk using the [noise] generator.
  void _generateHeightMap() {
    for (int col = 0; col < chunkSize.x; col++) {
      for (int row = 0; row < chunkSize.y; row++) {
        final globalPos = getTileWorldPosition(col, row);
        final index = row * chunkSize.x + col;
        _heightMap[index] = noise.getNoise2(
          globalPos.x.toDouble(),
          globalPos.y.toDouble(),
        );
      }
    }
  }
}
