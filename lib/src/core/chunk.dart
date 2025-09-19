import 'dart:collection';
import 'dart:math';

import 'package:fast_noise/fast_noise.dart';
import 'package:flame/extensions.dart';

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
  final Vector2i coords;

  /// The size of this chunk in tiles (width x height).
  final Vector2i size;

  /// The size of a single tile in pixels (width x height).
  final Vector2i tileSize;

  /// The size of the chunk in pixel units.
  late final Vector2 worldSize;

  /// The position of the chunk in the world coordinate system (pixels)
  late final Vector2 worldPosition;

  /// The [Rect] of this chunk constructed from it's position and size
  /// in the world coordinate system (pixels)
  late final Rect worldRect;

  /// The height map for all tiles in this chunk.
  ///
  /// Stored as a flat list in row-major order.
  final List<double> _heightMap;

  /// Creates a new [Chunk] and generates its height map using [noise].
  ///
  /// [coords] specifies the chunk’s position in chunk-space.
  /// [size] defines how many tiles wide and tall the chunk is.
  /// [tileSize] defines the size of each tile in pixels.
  Chunk({
    required this.noise,
    required this.coords,
    required this.size,
    required this.tileSize,
  }) : assert(size.x > 0 && size.y > 0, 'Chunk size must be positive'),
       assert(tileSize.x > 0 && tileSize.y > 0, 'Tile size must be positive'),
       _heightMap = List.filled(size.x * size.y, 0, growable: false) {
    worldSize = Vector2(
      size.x * tileSize.x.toDouble(),
      size.y * tileSize.y.toDouble(),
    );
    worldPosition = Vector2(worldSize.x * coords.x, worldSize.y * coords.y);
    worldRect = Rect.fromLTWH(
      worldPosition.x,
      worldPosition.y,
      worldSize.x,
      worldSize.y,
    );
    _generateHeightMap();
  }

  /// Returns the height map for this chunk.
  List<double> get heightMap => UnmodifiableListView(_heightMap);

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
    final index = row * size.x + col;
    return _heightMap[index];
  }

  /// Returns the world position (in pixels) for the tile at ([col], [row]).
  Vector2i getTileWorldPosition(int col, int row) {
    return Vector2i(
      coords.x * size.x * tileSize.x + col * tileSize.x,
      coords.y * size.y * tileSize.y + row * tileSize.y,
    );
  }

  Vector2 getRandomPosition([Random? rng]) {
    final r = rng ?? Random();
    return Vector2(
      r.nextDouble() * worldSize.x + worldPosition.x,
      r.nextDouble() * worldSize.y + worldPosition.y,
    );
  }

  /// Generates the height map for this chunk using the [noise] generator.
  void _generateHeightMap() {
    for (int col = 0; col < size.x; col++) {
      for (int row = 0; row < size.y; row++) {
        final globalPos = getTileWorldPosition(col, row);
        final index = row * size.x + col;
        _heightMap[index] = noise.getNoise2(
          globalPos.x.toDouble(),
          globalPos.y.toDouble(),
        );
      }
    }
  }
}
