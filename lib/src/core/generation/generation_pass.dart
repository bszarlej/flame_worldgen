import 'dart:math';

import '../chunk_data.dart';
import '../coords.dart';
import '../hash.dart';
import '../noise/noise_field.dart';
import '../random.dart';
import '../tile_palette.dart';
import '../tile_type.dart';
import 'biome.dart';
import 'sample.dart';

/// A step that runs after biomes are placed, for things noise can't express,
/// such as roads or rivers.
///
/// ```dart
/// class RoadPass extends GenerationPass {
///   const RoadPass();
///
///   @override
///   void apply(ChunkBuilder chunk) {
///     for (final coord in chunk.coords) {
///       if (coord.y % 64 == 0 && chunk.tileAt(coord) == grass) {
///         chunk.setTile(coord, dirt);
///       }
///     }
///   }
/// }
/// ```
///
/// Passes run once per chunk, in order, and each sees the changes of the
/// ones before. A pass only sees its own chunk, and must be deterministic:
/// the result may only depend on the chunk, the world seed and
/// [ChunkBuilder.random].
abstract class GenerationPass {
  /// Allows subclasses to have const constructors.
  const GenerationPass();

  /// Changes the tiles of [chunk].
  void apply(ChunkBuilder chunk);
}

/// A chunk being generated, as seen by a [GenerationPass].
///
/// Every method that takes a [TileCoord] throws if it's outside this chunk.
abstract interface class ChunkBuilder {
  /// Where the chunk is in the world.
  ChunkCoord get coord;

  /// The world seed.
  int get seed;

  /// The tiles of the chunk, row by row.
  Iterable<TileCoord> get coords;

  /// Whether [tile] is inside this chunk.
  bool contains(TileCoord tile);

  /// Returns the tile type at [tile].
  TileType tileAt(TileCoord tile);

  /// Replaces the tile type at [tile] with [type].
  ///
  /// [type] must be in the world's tileset. Throws otherwise.
  void setTile(TileCoord tile, TileType type);

  /// Returns the biome chosen for [tile]. Passes don't change biomes.
  Biome biomeAt(TileCoord tile);

  /// Returns the value of [field] at [tile]. The field must be one of the
  /// generator's fields.
  double valueAt(NoiseField field, TileCoord tile);

  /// A random number generator for this chunk and pass.
  ///
  /// It gives the same sequence every time the chunk is generated. The
  /// sequence depends on the world seed, the chunk and the pass's position
  /// in the list, so reordering passes changes it.
  Random get random;
}

/// The [ChunkBuilder] that [ChunkGenerator] passes to each pass.
class ChunkBuilderImpl implements ChunkBuilder {
  /// Wraps [chunk], whose fields have been evaluated into [fields].
  ChunkBuilderImpl(
    this._chunk,
    this._palette,
    this._biomes,
    this._fields, {
    required this.seed,
    required int passIndex,
  }) : random = WorldRandom(
         hash3(_chunk.coord.x, _chunk.coord.y, passIndex, seed),
       );

  final ChunkData _chunk;
  final TilePalette _palette;
  final List<Biome> _biomes;
  final ChunkFields _fields;

  @override
  final int seed;

  @override
  final Random random;

  @override
  ChunkCoord get coord => _chunk.coord;

  @override
  Iterable<TileCoord> get coords => _chunk.coords;

  @override
  bool contains(TileCoord tile) => _chunk.contains(tile);

  @override
  TileType tileAt(TileCoord tile) => _palette[_chunk.tileIdAt(tile)];

  @override
  void setTile(TileCoord tile, TileType type) {
    if (!_palette.contains(type)) {
      throw ArgumentError.value(
        type,
        'type',
        "can't be placed because it isn't in the world's tileset. Add it to "
            "the Tileset's tiles",
      );
    }
    _chunk.setTileId(tile, _palette.idOf(type));
  }

  @override
  Biome biomeAt(TileCoord tile) => _biomes[_chunk.biomeAt(tile)];

  @override
  double valueAt(NoiseField field, TileCoord tile) {
    if (!contains(tile)) {
      throw ArgumentError.value(tile, 'tile', 'is not in chunk $coord');
    }
    return _fields.valueAt(field, _chunk.grid.localIndex(tile));
  }
}
