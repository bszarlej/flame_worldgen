import 'dart:math';

import 'package:flame/components.dart';

import '../../flame_worldgen.dart';

/// Represents a single tile within a [Chunk].
///
/// Each [Tile] contains information about its noise value, position, and size, as well as
/// both global and local coordinates.
class Tile {
  /// The noise value for the tile, typically used in terrain generation.
  final double noise;

  /// The global coordinates of this tile in the world.
  ///
  /// Each tile has a unique global position that identifies it across all chunks.
  final Vector2i globalCoords;

  /// The local coordinates of this tile within its containing chunk.
  ///
  /// For example, in a chunk of size 16x16, values range from 0 to 15.
  final Vector2i localCoords;

  /// The size of this tile in pixels.
  final Vector2i size;

  /// The position of this tile in world space (pixels).
  final Vector2 position;

  /// Creates a new [Tile] instance with the specified noise, coordinates, size, and position.
  Tile({
    required this.noise,
    required this.globalCoords,
    required this.localCoords,
    required this.size,
    required this.position,
  });

  /// Returns a random position within the bounds of this tile.
  ///
  /// Optionally, a [Random] instance can be provided for deterministic results.
  /// If none is provided, a new [Random] instance is used.
  ///
  /// Returns a [Vector2] containing the random position in world space.
  Vector2 getRandomPosition([Random? rng]) {
    final r = rng ?? Random();
    return Vector2(
      r.nextDouble() * size.x + position.x,
      r.nextDouble() * size.y + position.y,
    );
  }
}
