import 'package:flame_worldgen/src/core/core.dart';
import 'package:test/test.dart';

import 'golden_world.dart';

// Seed 42: ocean in the south-west, a mountain range ringed by forest, and a
// lake in the north-east. If this changes, every existing world changes.
const _golden = '''
^^^^^^^,,,.~~~~~~~~~~~~~~~~~..~~~,,,,^^^,,,,,,,,,,,^^^^^^^^,,,,,,,,,,TTTTTTT^^^^
^^^^^^,,,.~~~~~~~~~~~~~~~~~~.,,..,,,^^^^^,,,,,,,,,,,^^^^^^^,,,,,,,,,,TTTTTTT^^^^
^^^^^,,,,.~~~~~~~~~~~~~~~~~~.,,,,,,,^^^^^,,,,,,,,,,,^^^^^^,,,,,,,,,,TTTTTTTT^^^^
^^^^T,,,.~~~~~~~~~~~~~~~~~~~~.,,,,,,,T^^^T,,,,,,,,,,,^^^^,,,,,,,,,,,TTTTT^^T^^T,
^^^^,,,.~~~~~~~~~~~~~~~~~~~~~~.,,,,TTT^^^^^TT,,,,,,,,,,,,,,,,,,,,,,TTTTTTTTTTTTT
^^^^,,,~~~~~~~~~~~~~~~~~~~~~~~.,,,TTT^^^^^TTTTT,,,,,,,,,,,,,,,,,,,,TTTT^^^TTTTTT
^^^T,,~~~~~~~~~~~~~~~~~~~~~~~~.,,,TTT^^^^TTTTTT,,,,,,,,,,,,,,,,,,TTTTTT^^^^^^TTT
^^T,,,~~~~~~~~~~~~~~~~~~~~~~~~.,,TTTTTT^TTTTTTTT,,.....,...,,,T..T..TTT^^^^^^^TT
TT,,,~~~~~~~~~~~~~~~~~~~~~~~~~~.,TTTTTTTTTTTTTTT,,,..~......TT....~.TTT^^^^^^^TT
TT,,.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~..TTTTTTTTTTTT,,,..~...~.TTT...~~~TTT^^^^^^^TT
T,,.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~..TTTTTTTTTTT,,,........TTT...~~.TTT^^^^TTTTT
,,,~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~..TTTTTTTT,,,,.........TTTTT...TTTTTTTTTTTTT
,,.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~...,,,,,,,,,,..TT...TTTTTTT..TTTTTTTTTTTT.
,.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,,,,,,TTTT..TTTTTTT..TTTTTTTTTTT.~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,,,,,,TTTTTTTTTTTTT.....TTTTTTT.~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,^^^^,,,TTTTTTTTTTTT.~~~~~.TTTTT.~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~....,,,^^^^^^,TTTTTTTTTTTT.~~~~~..TTT.~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,^^^^^^^^T^^^^TTTTTTT.~~~~~~...~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,^^^^^^^^^^^^^^TTTTTT..~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~,,,,,^^^^^^^^^^^^^^^TTTTTTT.~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,^^^^^^^^^^^^^^^TTTTTTTT.~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,^^^^^^^^^^^^^^^^TTTTTTTT.~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,^^^^^^^^^^^^^^^^TTTTTT..~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,^^^^^^^^^^^^^TTTTTTTT.~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~.~~~~~~~~~~~~~~~~~~~~,,,,,^^^^^^^^^^^TTTTTTT.~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,^^^^^^^^^TTTTTTTTT.~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,^^^^^^^,,,TTTTTTTT~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~TT,,,^^^,,,,,,,TTTTTTT.~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~TT,,,,,,,,,,,,,,TTTTT..~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,,,,,,,,,,,TTTTT.~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~........,..,,,,TTT.~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~..~~~~~~~~~.,,,TTT.~~~~~~~~~~~~~~~~~~~''';

final _worldGenerator = WorldGenerator(
  fields: [elevation, moisture],
  biomes: goldenBiomes(),
);

void main() {
  group('ChunkGenerator', () {
    test('generates the golden world', () {
      expect(renderGolden(goldenChunks()), _golden.trimLeft());
    });

    test('generates the same chunk every time', () {
      final a = ChunkGenerator(_worldGenerator, seed: 7, grid: ChunkGrid(32));
      final b = ChunkGenerator(_worldGenerator, seed: 7, grid: ChunkGrid(32));
      final first = a.generate(const ChunkCoord(-1, 3));
      a.generate(const ChunkCoord(10, 10));
      expect(a.generate(const ChunkCoord(-1, 3)).tiles, first.tiles);
      expect(b.generate(const ChunkCoord(-1, 3)).tiles, first.tiles);
    });

    test('a different seed gives a different world', () {
      final a = ChunkGenerator(_worldGenerator, seed: 1, grid: ChunkGrid(32));
      final b = ChunkGenerator(_worldGenerator, seed: 2, grid: ChunkGrid(32));
      expect(
        a.generate(const ChunkCoord(0, 0)).tiles,
        isNot(b.generate(const ChunkCoord(0, 0)).tiles),
      );
    });

    test('stores the biome index and the ground tile of each tile', () {
      final chunks = ChunkGenerator(
        _worldGenerator,
        seed: 42,
        grid: ChunkGrid(16),
      );
      final chunk = chunks.generate(const ChunkCoord(0, 0));
      for (var i = 0; i < chunks.grid.area; i++) {
        final biome = _worldGenerator.biomes[chunk.biomes[i]];
        expect(chunks.palette[chunk.tiles[i]], same(biome.ground));
      }
    });

    test('the first matching biome wins', () {
      final everywhere = NoiseField.custom('everywhere', (x, y, seed) => 1);
      final generator = WorldGenerator(
        fields: [everywhere],
        biomes: [
          Biome('first', ground: sand, when: (s) => s[everywhere] > 0),
          Biome('second', ground: stone, when: (s) => s[everywhere] > 0),
          const Biome('fallback', ground: grass),
        ],
      );
      final chunk = ChunkGenerator(
        generator,
        seed: 0,
        grid: ChunkGrid(4),
      ).generate(const ChunkCoord(0, 0));
      expect(chunk.biomes.toSet(), {0});
    });

    test('the sample knows which tile it is', () {
      final generator = WorldGenerator(
        biomes: [
          Biome('east', ground: sand, when: (s) => s.coord.x >= 2),
          const Biome('west', ground: grass),
        ],
      );
      final chunks = ChunkGenerator(generator, seed: 0, grid: ChunkGrid(4));
      final chunk = chunks.generate(const ChunkCoord(0, 0));
      expect(chunk.biomeAt(const TileCoord(1, 3)), 1);
      expect(chunk.biomeAt(const TileCoord(2, 3)), 0);
    });

    test('biomes can share a ground tile', () {
      final generator = WorldGenerator(
        biomes: [
          Biome('forest', ground: grass, when: (s) => s.coord.x < 0),
          const Biome('plains', ground: grass),
        ],
      );
      final chunks = ChunkGenerator(generator, seed: 0, grid: ChunkGrid(4));
      expect(chunks.palette.length, 1);
    });
  });

  test('withPlainScatterRules keeps everything but the rule classes', () {
    final trees = _CallbackRule('trees', density: 0.1, minDistance: 1);
    const rocks = ScatterRule('rocks', density: 0.02);
    final generator = WorldGenerator(
      fields: [elevation],
      biomes: [
        Biome(
          'hills',
          ground: stone,
          when: (s) => s[elevation] > 0,
          scatter: [trees, rocks],
        ),
        Biome('forest', ground: grass, scatter: [trees]),
      ],
    );
    final plain = generator.withPlainScatterRules();

    expect(plain.scatterRules.map((r) => r.runtimeType), [
      ScatterRule,
      ScatterRule,
    ]);
    expect(plain.scatterRules.map((r) => (r.name, r.density, r.minDistance)), [
      ('trees', 0.1, 1.0),
      ('rocks', 0.02, 0.0),
    ]);
    // Both biomes still share one trees rule.
    expect(plain.biomes[1].scatter.single, same(plain.biomes[0].scatter[0]));
    expect(
      plain.biomes.map((b) => b.when),
      generator.biomes.map((b) => b.when),
    );

    final original = ChunkGenerator(generator, seed: 3, grid: ChunkGrid(32));
    final copy = ChunkGenerator(plain, seed: 3, grid: ChunkGrid(32));
    for (final coord in const [ChunkCoord(0, 0), ChunkCoord(-4, 7)]) {
      final a = original.generate(coord);
      final b = copy.generate(coord);
      expect(b.tiles, a.tiles);
      expect(
        b.spots.map((s) => (s.ruleIndex, s.x, s.y)),
        a.spots.map((s) => (s.ruleIndex, s.x, s.y)),
      );
    }
  });

  group('WorldGenerator rejects', () {
    Biome biome(String name, {bool last = false}) =>
        Biome(name, ground: grass, when: last ? null : (s) => true);

    test('no biomes', () {
      expect(() => WorldGenerator(biomes: []), throwsArgumentError);
    });

    test('a condition on the last biome', () {
      expect(
        () => WorldGenerator(biomes: [biome('a'), biome('b')]),
        throwsArgumentError,
      );
    });

    test('a biome without a condition before the last one', () {
      expect(
        () => WorldGenerator(
          biomes: [biome('a', last: true), biome('b', last: true)],
        ),
        throwsArgumentError,
      );
    });

    test('two biomes with the same name', () {
      expect(
        () => WorldGenerator(biomes: [biome('a'), biome('a', last: true)]),
        throwsArgumentError,
      );
    });

    test('more than 256 biomes', () {
      expect(
        () => WorldGenerator(
          biomes: [
            for (var i = 0; i < 256; i++) biome('b$i'),
            biome('last', last: true),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}

/// A rule with a callback, like a `Scatter` with its `spawn`.
class _CallbackRule extends ScatterRule {
  _CallbackRule(super.name, {required super.density, super.minDistance})
    : callback = (() => 0);

  final int Function() callback;
}
