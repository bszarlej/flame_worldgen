import 'dart:collection';
import 'dart:math';

import 'package:fast_noise/fast_noise.dart';
import 'package:flame/extensions.dart';

import '../math/vector2i.dart';
import 'tile.dart';

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

  // the tiles inside this chunk
  final List<Tile> _tiles = [];

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
       assert(tileSize.x > 0 && tileSize.y > 0, 'Tile size must be positive') {
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
    _fillTileList();
  }

  // Returns an unmodifiable list of tiles inside this chunk
  List<Tile> get tiles => UnmodifiableListView(_tiles);

  /// Returns a random position within the bounds of this chunk.
  Vector2 getRandomPosition([Random? rng]) {
    final r = rng ?? Random();
    return Vector2(
      r.nextDouble() * worldSize.x + worldPosition.x,
      r.nextDouble() * worldSize.y + worldPosition.y,
    );
  }

  Tile getTileAt(Vector2i localCoords) {
    return tiles.where((tile) => tile.localCoords == localCoords).first;
  }

  void _fillTileList() {
    _tiles.clear();

    for (int col = 0; col < size.x; col++) {
      for (int row = 0; row < size.y; row++) {
        final localCoords = Vector2i(col, row);
        final globalCoords = Vector2i(
          coords.x * size.x + col,
          coords.y * size.y + row,
        );
        final position = Vector2(
          globalCoords.x * tileSize.x.toDouble(),
          globalCoords.y * tileSize.y.toDouble(),
        );
        _tiles.add(
          Tile(
            noise: noise.getNoise2(
              globalCoords.x.toDouble(),
              globalCoords.y.toDouble(),
            ),
            globalCoords: globalCoords,
            localCoords: localCoords,
            size: tileSize,
            position: position,
          ),
        );
      }
    }
  }
}
