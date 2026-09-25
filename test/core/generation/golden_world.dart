import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/coords.dart';
import 'package:flame_worldgen/src/core/generation/world_generator.dart';

// The world used by the ASCII golden tests. Changing anything here changes
// the goldens.

const water = TileType('water', solid: true);
const sand = TileType('sand');
const grass = TileType('grass');
const forest = TileType('forest');
const stone = TileType('stone', solid: true);
const dirt = TileType('dirt');

final elevation = NoiseField.fbm('elevation', frequency: 0.02, octaves: 4);
final moisture = NoiseField.simplex('moisture', frequency: 0.04);

const trees = ScatterRule('trees', density: 0.15, minDistance: 1.5);
const bushes = ScatterRule('bushes', density: 0.03, minDistance: 3);
const rocks = ScatterRule('rocks', density: 0.08, minDistance: 2);

/// The golden world's biomes, optionally with scatter rules.
List<Biome> goldenBiomes({bool scatter = false}) => [
  Biome('ocean', ground: water, when: (s) => s[elevation] < -0.05),
  Biome('beach', ground: sand, when: (s) => s[elevation] < 0.02),
  Biome(
    'mountains',
    ground: stone,
    when: (s) => s[elevation] > 0.35,
    scatter: scatter ? const [rocks] : const [],
  ),
  Biome(
    'forest',
    ground: forest,
    when: (s) => s[moisture] > 0.2,
    scatter: scatter ? const [trees] : const [],
  ),
  Biome('plains', ground: grass, scatter: scatter ? const [bushes] : const []),
];

/// Lays a road on every 12th row through plains and forest.
class RoadPass extends GenerationPass {
  /// Creates the pass.
  const RoadPass();

  @override
  void apply(ChunkBuilder chunk) {
    for (final coord in chunk.coords) {
      final biome = chunk.biomeAt(coord).name;
      if (coord.y % 12 == 0 && (biome == 'plains' || biome == 'forest')) {
        chunk.setTile(coord, dirt);
      }
    }
  }
}

/// The golden world's generator for seed 42 in chunks of 16 tiles.
ChunkGenerator goldenChunks({
  List<GenerationPass> passes = const [],
  bool scatter = false,
}) => ChunkGenerator(
  WorldGenerator(
    fields: [elevation, moisture],
    biomes: goldenBiomes(scatter: scatter),
    passes: passes,
  ),
  seed: 42,
  grid: ChunkGrid(16),
  tiles: const [dirt],
);

/// Renders chunks x -2..2, y -1..0 as one character per tile, with `*` for
/// trees and bushes and `o` for rocks.
String renderGolden(ChunkGenerator chunks) {
  const tileChars = {
    water: '~',
    sand: '.',
    grass: ',',
    forest: 'T',
    stone: '^',
    dirt: '=',
  };
  const spotChars = {'trees': '*', 'bushes': '*', 'rocks': 'o'};
  final grid = chunks.grid;
  final size = grid.size;
  final rows = List.generate(2 * size, (_) => StringBuffer());
  for (var cy = -1; cy <= 0; cy++) {
    for (var cx = -2; cx <= 2; cx++) {
      final chunk = chunks.generate(ChunkCoord(cx, cy));
      final cells = [
        for (final id in chunk.tiles) tileChars[chunks.palette[id]]!,
      ];
      for (final spot in chunk.spots) {
        final rule = chunks.generator.scatterRules[spot.ruleIndex];
        cells[grid.localIndex(spot.coord)] = spotChars[rule.name]!;
      }
      for (var i = 0; i < grid.area; i++) {
        rows[(cy + 1) * size + i ~/ size].write(cells[i]);
      }
    }
  }
  return rows.join('\n');
}
