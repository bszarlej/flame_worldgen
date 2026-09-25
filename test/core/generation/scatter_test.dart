import 'dart:math';

import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/coords.dart';
import 'package:flame_worldgen/src/core/generation/scatter.dart';
import 'package:flame_worldgen/src/core/generation/world_generator.dart';
import 'package:test/test.dart';

import 'golden_world.dart';

// The golden world with roads, trees and bushes (`*`) and rocks (`o`). No
// spot is on a road, a beach or water.
const _golden = '''
^^^^^^^,,,.~~~~~~~~~~~~~~~~~..~~~,,,,^^^,,,,,,,,,,,^^o^^^^^,,,,,,,,,,TTTTTTT^^^o
^o^^^^,,,.~~~~~~~~~~~~~~~~~~.,,..,,,^^^^^,,,,,,,*,,,^^^^^^^,,,,,,,,,,TTTTTT*^^^^
^^^^^*,,,.~~~~~~~~~~~~~~~~~~.,,,,,,,^^^o^,,,,,,,,,,,^^^^^^,,,,,,,,,,TTTTTTTT^^^^
^^^^*,,,.~~~~~~~~~~~~~~~~~~~~.,,,,,,,T^^^T,,,,,,,,,,,^^^^,,,,,,,,,,,T*TTT^^*o^T,
^^^^===.~~~~~~~~~~~~~~~~~~~~~~.=======^^^^^=====================================
^^^^,,,~~~~~~~~~~~~~~~~~~~~~~~.,,,TTT^^^^^TT*TT,,,,,,,,,,*,,,,,,,,,TTTT^^^TTTT*T
^^^T,,~~~~~~~~~~~~~~~~~~~~~~~~.,,,TT*^o^^TTTTTT,,,,,,,,,,,,,,,,,,TTTTTT^^^^^^TTT
o^T,,,~~~~~~~~~~~~~~~~~~~~~~~~.,,TTTTTT^*TTTTTTT,,.....,...,,,T..T..*TT^^^^^^^*T
TT,,,~~~~~~~~~~~~~~~~~~~~~~~~~~.,TT*TTT*TTTT*TT*,,*..~......*T....~.TTT^^^^o^^TT
*T*,.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~..TTTTTTTTTTTT,,,..~...~.TTT...~~~TT*^^^^^^^*T
T,,.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~..T*T*TT*TTTT,,,........TT*...~~.*TT^^^^TTTTT
,,,~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~..TTTT*TTT,,,,.........TTTT*...TTTTTT*TT*TT*
,,.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~...,,,,,,,,,*..*T...TTTTTTT..T*T*TTTTTTTT.
,.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,,,,,,TTTT..TTTTT*T..*TTTTTTTTTT.~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,,,,,,T**T*TTTT*TTT.....TT*TTT*.~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,^o^^,,,TTTTTTTTTTTT.~~~~~.TTTTT.~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~....===^^^^^^=============.~~~~~..===.~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,^o^^^^^^T^^^^TTT*TTT.~~~~~~...~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,^^^^^^o^^o^^^^T*TTTT..~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~,,,,,^^^^^^^^^^^^^^^TTTTTT*.~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,^^^^^^^^^^^^^^^TT*TTTTT.~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,^^^o^^^^^^^^o^^^T*TTTT*T.~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.*,,,o^^^^^^^o^^^^^^^TTTT*T..~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,^^^^^^^^^^^^^TT*TTTTT.~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~.~~~~~~~~~~~~~~~~~~~~,,,,,^^^^^^^^^^^TTTTTTT.~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,^^^^^^^^^TTTTT**TT.~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,^^o^o^^,,,TTTTTTT*~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~TT,,,^^^,,,,*,,*TTTTTT.~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~=====================..~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,*,,,,,,,,,,TTTTT.~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~........,..,,,,T*T.~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~..~~~~~~~~~.,,,TT*.~~~~~~~~~~~~~~~~~~~''';

/// A world that is plains everywhere, with [rules].
ChunkGenerator _plains(List<ScatterRule> rules, {int seed = 1}) =>
    ChunkGenerator(
      WorldGenerator(
        biomes: [Biome('plains', ground: grass, scatter: rules)],
      ),
      seed: seed,
      grid: ChunkGrid(16),
    );

List<ScatterSpot> _spotsIn(ChunkGenerator chunks, int from, int to) => [
  for (var cy = from; cy <= to; cy++)
    for (var cx = from; cx <= to; cx++)
      ...chunks.generate(ChunkCoord(cx, cy)).spots,
];

void main() {
  test('generates the golden world with scatter spots', () {
    expect(
      renderGolden(goldenChunks(passes: [const RoadPass()], scatter: true)),
      _golden.trimLeft(),
    );
  });

  test('keeps minDistance, also across chunk borders', () {
    const rule = ScatterRule('trees', density: 0.15, minDistance: 1.5);
    final spots = _spotsIn(_plains([rule]), -2, 1);
    expect(spots.length, greaterThan(100));
    for (var i = 0; i < spots.length; i++) {
      for (var j = i + 1; j < spots.length; j++) {
        final dx = spots[i].x - spots[j].x;
        final dy = spots[i].y - spots[j].y;
        expect(sqrt(dx * dx + dy * dy), greaterThanOrEqualTo(rule.minDistance));
      }
    }
  });

  test('a chunk has the same spots no matter what was generated before', () {
    const rule = ScatterRule('trees', density: 0.08, minDistance: 2);
    final alone = _plains([rule]).generate(const ChunkCoord(0, 0)).spots;
    final chunks = _plains([rule]);
    _spotsIn(chunks, -1, 1);
    final after = chunks.generate(const ChunkCoord(0, 0)).spots;
    expect(alone, isNotEmpty);
    expect(after.map((s) => (s.x, s.y)), alone.map((s) => (s.x, s.y)));
  });

  test('every spot is inside its chunk', () {
    final chunks = _plains([const ScatterRule('rocks', density: 0.2)]);
    for (final coord in const [ChunkCoord(-1, -1), ChunkCoord(2, 0)]) {
      final chunk = chunks.generate(coord);
      expect(chunk.spots, isNotEmpty);
      expect(chunk.spots.every((spot) => chunk.contains(spot.coord)), isTrue);
    }
  });

  group('density matches the request', () {
    for (final (density, minDistance) in const [
      (0.05, 0.0),
      (0.5, 0.0),
      (0.05, 2.0),
      (0.2, 1.0),
      (0.03, 3.0),
    ]) {
      test('$density per tile, minDistance $minDistance', () {
        final rule = ScatterRule(
          'r',
          density: density,
          minDistance: minDistance,
        );
        const size = 300;
        final spots = scatterSpots(rule, 0, 99, 0, 0, size);
        expect(spots.length / (size * size), closeTo(density, density * 0.1));
      });
    }
  });

  test('spots differ per seed and per rule name', () {
    Set<(double, double)> positions(ScatterRule rule, int seed) => {
      for (final spot in _plains([
        rule,
      ], seed: seed).generate(const ChunkCoord(0, 0)).spots)
        (spot.x, spot.y),
    };
    const a = ScatterRule('a', density: 0.1);
    const b = ScatterRule('b', density: 0.1);
    expect(positions(a, 1), isNot(positions(a, 2)));
    expect(positions(a, 1), isNot(positions(b, 1)));
  });

  test('spot seeds differ between spots', () {
    final spots = _plains([
      const ScatterRule('a', density: 0.2),
    ]).generate(const ChunkCoord(0, 0)).spots;
    expect(spots.map((s) => s.seed).toSet(), hasLength(spots.length));
  });

  test('the same rule can be used by several biomes', () {
    const rule = ScatterRule('trees', density: 0.1);
    final generator = WorldGenerator(
      biomes: [
        Biome(
          'west',
          ground: grass,
          when: (s) => s.coord.x < 0,
          scatter: const [rule],
        ),
        const Biome('east', ground: forest, scatter: [rule]),
      ],
    );
    expect(generator.scatterRules, [rule]);
  });

  group('rejects', () {
    WorldGenerator withRule(ScatterRule rule) => WorldGenerator(
      biomes: [
        Biome('plains', ground: grass, scatter: [rule]),
      ],
    );

    test('an empty name', () {
      expect(
        () => withRule(const ScatterRule('', density: 0.1)),
        throwsArgumentError,
      );
    });

    test('a density of 0 or less', () {
      expect(
        () => withRule(const ScatterRule('a', density: 0)),
        throwsArgumentError,
      );
    });

    test('a negative minDistance', () {
      expect(
        () => withRule(const ScatterRule('a', density: 0.1, minDistance: -1)),
        throwsArgumentError,
      );
    });

    test('more than one object per tile without minDistance', () {
      expect(
        () => withRule(const ScatterRule('a', density: 1.5)),
        throwsArgumentError,
      );
    });

    test('a density that does not fit the minDistance', () {
      expect(
        () => withRule(const ScatterRule('a', density: 0.1, minDistance: 2)),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('at most 0.090 objects per tile fit'),
          ),
        ),
      );
    });

    test('two different rules with the same name', () {
      expect(
        () => WorldGenerator(
          biomes: [
            const Biome(
              'plains',
              ground: grass,
              scatter: [
                ScatterRule('trees', density: 0.1),
                ScatterRule('trees', density: 0.2),
              ],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
