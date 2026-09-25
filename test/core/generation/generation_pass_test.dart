import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/coords.dart';
import 'package:flame_worldgen/src/core/generation/world_generator.dart';
import 'package:test/test.dart';

import 'golden_world.dart';

/// Runs [onApply] for every chunk.
class _CallbackPass extends GenerationPass {
  _CallbackPass(this.onApply);

  final void Function(ChunkBuilder chunk) onApply;

  @override
  void apply(ChunkBuilder chunk) => onApply(chunk);
}

ChunkGenerator _chunks(
  List<GenerationPass> passes, {
  int seed = 42,
  List<TileType> tiles = const [dirt],
}) => ChunkGenerator(
  WorldGenerator(
    fields: [elevation, moisture],
    biomes: goldenBiomes(),
    passes: passes,
  ),
  seed: seed,
  grid: ChunkGrid(16),
  tiles: tiles,
);

// The golden world from world_generator_test.dart, with roads on rows -12, 0
// and 12. They stop at mountains, beaches and water.
const _golden = '''
^^^^^^^,,,.~~~~~~~~~~~~~~~~~..~~~,,,,^^^,,,,,,,,,,,^^^^^^^^,,,,,,,,,,TTTTTTT^^^^
^^^^^^,,,.~~~~~~~~~~~~~~~~~~.,,..,,,^^^^^,,,,,,,,,,,^^^^^^^,,,,,,,,,,TTTTTTT^^^^
^^^^^,,,,.~~~~~~~~~~~~~~~~~~.,,,,,,,^^^^^,,,,,,,,,,,^^^^^^,,,,,,,,,,TTTTTTTT^^^^
^^^^T,,,.~~~~~~~~~~~~~~~~~~~~.,,,,,,,T^^^T,,,,,,,,,,,^^^^,,,,,,,,,,,TTTTT^^T^^T,
^^^^===.~~~~~~~~~~~~~~~~~~~~~~.=======^^^^^=====================================
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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~....===^^^^^^=============.~~~~~..===.~~~~
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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~=====================..~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.,,,,,,,,,,,,,,,TTTTT.~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~........,..,,,,TTT.~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~..~~~~~~~~~.,,,TTT.~~~~~~~~~~~~~~~~~~~''';

void main() {
  test('generates the golden world with roads', () {
    expect(
      renderGolden(goldenChunks(passes: [const RoadPass()])),
      _golden.trimLeft(),
    );
  });

  test('passes run in order and see earlier changes', () {
    final seen = <TileType>[];
    final chunks = _chunks([
      _CallbackPass((chunk) => chunk.setTile(chunk.coords.first, dirt)),
      _CallbackPass((chunk) => seen.add(chunk.tileAt(chunk.coords.first))),
    ]);
    chunks.generate(const ChunkCoord(3, -4));
    expect(seen, [dirt]);
  });

  test('passes see the chunk coordinate and the world seed', () {
    late ChunkCoord coord;
    late int seed;
    final chunks = _chunks([
      _CallbackPass((chunk) {
        coord = chunk.coord;
        seed = chunk.seed;
      }),
    ], seed: 7);
    chunks.generate(const ChunkCoord(-2, 5));
    expect(coord, const ChunkCoord(-2, 5));
    expect(seed, 7);
  });

  test('valueAt matches the biome conditions', () {
    final chunks = _chunks([
      _CallbackPass((chunk) {
        for (final coord in chunk.coords) {
          final isOcean = chunk.valueAt(elevation, coord) < -0.05;
          expect(chunk.biomeAt(coord).name == 'ocean', isOcean);
        }
      }),
    ]);
    chunks.generate(const ChunkCoord(-1, 0));
  });

  test('random is the same every time a chunk is generated', () {
    final values = <int>[];
    final chunks = _chunks([
      _CallbackPass((chunk) => values.add(chunk.random.nextInt(1 << 30))),
    ]);
    chunks.generate(const ChunkCoord(1, 1));
    chunks.generate(const ChunkCoord(2, 1));
    chunks.generate(const ChunkCoord(1, 1));
    expect(values[0], values[2]);
    expect(values[0], isNot(values[1]));
  });

  test('each pass gets its own random sequence', () {
    final values = <int>[];
    void record(ChunkBuilder chunk) =>
        values.add(chunk.random.nextInt(1 << 30));
    _chunks([
      _CallbackPass(record),
      _CallbackPass(record),
    ]).generate(const ChunkCoord(0, 0));
    expect(values[0], isNot(values[1]));
  });

  test('setting a tile keeps the biome', () {
    final chunks = _chunks([
      _CallbackPass((chunk) => chunk.setTile(chunk.coords.first, dirt)),
    ]);
    final chunk = chunks.generate(const ChunkCoord(0, 0));
    final unchanged = _chunks([]).generate(const ChunkCoord(0, 0));
    expect(chunk.biomes, unchanged.biomes);
  });

  test('placing a tile that is not in the tileset throws', () {
    final chunks = _chunks([
      _CallbackPass((chunk) => chunk.setTile(chunk.coords.first, dirt)),
    ], tiles: const []);
    expect(
      () => chunks.generate(const ChunkCoord(0, 0)),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains("Add it to the Tileset's tiles"),
        ),
      ),
    );
  });

  test('tiles outside the chunk throw', () {
    final errors = <Object>[];
    void attempt(void Function() action) {
      try {
        action();
      } on ArgumentError catch (e) {
        errors.add(e);
      }
    }

    final chunks = _chunks([
      _CallbackPass((chunk) {
        const outside = TileCoord(16, 0);
        expect(chunk.contains(outside), isFalse);
        attempt(() => chunk.tileAt(outside));
        attempt(() => chunk.setTile(outside, dirt));
        attempt(() => chunk.biomeAt(outside));
        attempt(() => chunk.valueAt(elevation, outside));
      }),
    ]);
    chunks.generate(const ChunkCoord(0, 0));
    expect(errors, hasLength(4));
  });
}
