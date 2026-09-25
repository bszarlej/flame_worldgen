import '../chunk_data.dart';
import '../coords.dart';
import '../hash.dart';
import '../noise/noise_field.dart';
import '../tile_palette.dart';
import '../tile_type.dart';
import 'biome.dart';
import 'generation_pass.dart';
import 'sample.dart';
import 'scatter.dart';

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
  /// Creates a generator that picks between [biomes] using [fields], then
  /// runs [passes] in order.
  ///
  /// Throws if [biomes] is empty, if the last biome has a `when` condition,
  /// if any other biome lacks one, or if two biomes share a name.
  WorldGenerator({
    List<NoiseField> fields = const [],
    required List<Biome> biomes,
    List<GenerationPass> passes = const [],
  }) : fields = List.unmodifiable(fields),
       biomes = List.unmodifiable(biomes),
       passes = List.unmodifiable(passes) {
    _checkBiomes(this.biomes);
    scatterRules = _collectScatterRules(this.biomes);
  }

  /// The noise fields that biome conditions and passes can read.
  final List<NoiseField> fields;

  /// The biomes, in the order they're checked.
  final List<Biome> biomes;

  /// The passes that run after biomes are placed, in order.
  final List<GenerationPass> passes;

  /// Every scatter rule of every biome, each once, in biome order.
  late final List<ScatterRule> scatterRules;
}

List<ScatterRule> _collectScatterRules(List<Biome> biomes) {
  final rules = <ScatterRule>[];
  final names = <String>{};
  for (final biome in biomes) {
    for (final rule in biome.scatter) {
      if (rules.any((existing) => identical(existing, rule))) continue;
      checkScatterRule(rule);
      if (!names.add(rule.name)) {
        throw ArgumentError.value(
          rule,
          'scatter',
          'Two different scatter rules are named "${rule.name}"',
        );
      }
      rules.add(rule);
    }
  }
  return List.unmodifiable(rules);
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
  ///
  /// Passes can place the biomes' ground tiles and any of [tiles], which the
  /// map fills from its tileset.
  ChunkGenerator(
    this.generator, {
    required this.seed,
    required this.grid,
    Iterable<TileType> tiles = const [],
  }) : palette = TilePalette([
         for (final biome in generator.biomes) biome.ground,
         ...tiles,
       ]),
       _fields = ChunkFields(generator.fields, seed, grid) {
    _groundIds = [
      for (final biome in generator.biomes) palette.idOf(biome.ground),
    ];
    _ruleSeeds = [
      for (final rule in generator.scatterRules)
        deriveSeed(seed, 'scatter ${rule.name}'),
    ];
    _ruleOwners = [
      for (final rule in generator.scatterRules)
        [
          for (final biome in generator.biomes)
            biome.scatter.any((owned) => identical(owned, rule)),
        ],
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
  late final List<int> _ruleSeeds;

  /// For each scatter rule, whether each biome has it.
  late final List<List<bool>> _ruleOwners;

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

    for (final (index, pass) in generator.passes.indexed) {
      pass.apply(
        ChunkBuilderImpl(
          chunk,
          palette,
          biomes,
          _fields,
          seed: seed,
          passIndex: index,
        ),
      );
    }

    _scatter(chunk);
    return chunk;
  }

  void _scatter(ChunkData chunk) {
    final origin = chunk.origin;
    for (var rule = 0; rule < generator.scatterRules.length; rule++) {
      final owners = _ruleOwners[rule];
      final spots = scatterSpots(
        generator.scatterRules[rule],
        rule,
        _ruleSeeds[rule],
        origin.x,
        origin.y,
        grid.size,
      );
      for (final spot in spots) {
        final index = grid.localIndex(spot.coord);
        final biome = chunk.biomes[index];
        if (owners[biome] && chunk.tiles[index] == _groundIds[biome]) {
          chunk.spots.add(spot);
        }
      }
    }
  }
}
