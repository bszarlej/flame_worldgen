import 'dart:ui';

import 'core/coords.dart';
import 'core/generation/biome.dart';
import 'core/generation/scatter.dart';
import 'core/tile_type.dart';

/// A loaded chunk of a `ProceduralMap`, as seen by `onChunkLoaded` and
/// `onChunkUnloaded`.
///
/// ```dart
/// ProceduralMap(
///   onChunkLoaded: (chunk) {
///     for (final coord in chunk.coords) {
///       if (chunk.tileAt(coord).hasTag('liquid')) ...
///     }
///   },
///   ...
/// );
/// ```
///
/// Every method that takes a [TileCoord] throws if it's outside this chunk.
abstract interface class Chunk {
  /// Where the chunk is in the world.
  ChunkCoord get coord;

  /// Where the chunk is in the world, in the map's coordinates (pixels).
  Rect get bounds;

  /// The tiles of the chunk, row by row.
  Iterable<TileCoord> get coords;

  /// Whether [tile] is inside this chunk.
  bool contains(TileCoord tile);

  /// Returns the tile type at [tile].
  TileType tileAt(TileCoord tile);

  /// Returns the biome at [tile].
  Biome biomeAt(TileCoord tile);

  /// Where objects go in this chunk.
  List<ScatterSpot> get spots;
}
