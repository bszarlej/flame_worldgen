import '../chunk_data.dart';
import '../coords.dart';
import '../noise/noise_field.dart';
import '../tile_palette.dart';
import 'biome.dart';
import 'sample.dart';

/// Decides which tile type goes where, using noise fields and biomes.
///
/// ```dart
/// final generator = WorldGenerator(
///   fields: [elevation, moisture],
///   biomes: [
///     Biome('ocean', ground: water, when: (s) => s[elevation] < -0.1),
///     Biome('forest', ground: grass, when: (s) => s[moisture] > 0.3),
///     Biome('plains', ground: grass),
///   ],
/// );
/// ```
///
/// A generator holds no seed. The same generator produces a different world
/// for every seed.
class WorldGenerator {
  /// Creates a generator that picks between [biomes] using [fields].
  ///
  /// Throws if [biomes] is empty, if the last biome has a `when` condition,
  /// if any other biome lacks one, or if two biomes share a name.
  WorldGenerator({
    List<NoiseField> fields = const [],
    required List<Biome> biomes,
  }) : fields = List.unmodifiable(fields),
       biomes = List.unmodifiable(biomes) {
    _checkBiomes(this.biomes);
  }

  /// The noise fields that biome conditions can read.
  final List<NoiseField> fields;

  /// The biomes, in the order they're checked.
  final List<Biome> biomes;
}

void _checkBiomes(List<Biome> biomes) {
  if (biomes.isEmpty) {
    throw ArgumentError.value(biomes, 'biomes', 'must not be empty');
  }
  if (biomes.length > ChunkData.maxBiomes) {
    throw ArgumentError.value(
      biomes.length,
      'biomes',
      'A world can have at most ${ChunkData.maxBiomes} biomes',
    );
  }

  final names = <String>{};
  for (final (index, biome) in biomes.indexed) {
    if (biome.name.isEmpty) {
      throw ArgumentError.value(biome, 'biomes', 'names must not be empty');
    }
    if (!names.add(biome.name)) {
      throw ArgumentError.value(
        biome,
        'biomes',
        'Two biomes are named "${biome.name}"',
      );
    }
    final isLast = index == biomes.length - 1;
    if (isLast && biome.when != null) {
      throw ArgumentError.value(
        biome,
        'biomes',
        'The last biome must have no `when` condition, so every tile gets a '
            'biome',
      );
    }
    if (!isLast && biome.when == null) {
      throw ArgumentError.value(
        biome,
        'biomes',
        '${biome.name} has no `when` condition, so the biomes after it can '
            'never be chosen. Move it to the end',
      );
    }
  }
}

/// Generates chunks for one world: a [WorldGenerator] with a seed and a chunk
/// size.
///
/// Reuses its buffers between chunks, so each isolate needs its own.
class ChunkGenerator {
  /// Prepares [generator] for the world with [seed], in chunks of [grid].
  ChunkGenerator(this.generator, {required this.seed, required this.grid})
    : palette = TilePalette([
        for (final biome in generator.biomes) biome.ground,
      ]),
      _fields = ChunkFields(generator.fields, seed, grid) {
    _groundIds = [
      for (final biome in generator.biomes) palette.idOf(biome.ground),
    ];
  }

  /// The generator this builds chunks with.
  final WorldGenerator generator;

  /// The world seed.
  final int seed;

  /// The size of the chunks.
  final ChunkGrid grid;

  /// The tile ids used in the generated chunks.
  final TilePalette palette;

  final ChunkFields _fields;
  late final List<int> _groundIds;

  /// Generates the chunk at [coord].
  ChunkData generate(ChunkCoord coord) {
    final chunk = ChunkData(coord, grid);
    final biomes = generator.biomes;
    final sample = _fields.sample;
    _fields.evaluate(coord);

    for (var index = 0; index < grid.area; index++) {
      _fields.moveTo(index);
      // The last biome has no condition, so the loop always ends.
      var biome = 0;
      while (biomes[biome].when?.call(sample) == false) {
        biome++;
      }
      chunk.tiles[index] = _groundIds[biome];
      chunk.biomes[index] = biome;
    }
    return chunk;
  }
}
