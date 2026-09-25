import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/coords.dart';
import 'package:flame_worldgen/src/core/generation/world_generator.dart';
import 'package:test/test.dart';

const _water = TileType('water', solid: true);
const _sand = TileType('sand');
const _grass = TileType('grass');
const _forest = TileType('forest');
const _stone = TileType('stone', solid: true);
const _dirt = TileType('dirt');

final _elevation = NoiseField.fbm('elevation', frequency: 0.02, octaves: 4);
final _moisture = NoiseField.simplex('moisture', frequency: 0.04);

List<Biome> get _biomes => [
  Biome('ocean', ground: _water, when: (s) => s[_elevation] < -0.05),
  Biome('beach', ground: _sand, when: (s) => s[_elevation] < 0.02),
  Biome('mountains', ground: _stone, when: (s) => s[_elevation] > 0.35),
  Biome('forest', ground: _forest, when: (s) => s[_moisture] > 0.2),
  const Biome('plains', ground: _grass),
];

/// Lays a road on every 12th row through plains and forest.
class _RoadPass extends GenerationPass {
  const _RoadPass();

  @override
  void apply(ChunkBuilder chunk) {
    for (final coord in chunk.coords) {
      final biome = chunk.biomeAt(coord).name;
      if (coord.y % 12 == 0 && (biome == 'plains' || biome == 'forest')) {
        chunk.setTile(coord, _dirt);
      }
    }
  }
}

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
  int size = 16,
  List<TileType> tiles = const [_dirt],
}) => ChunkGenerator(
  WorldGenerator(
    fields: [_elevation, _moisture],
    biomes: _biomes,
    passes: passes,
  ),
  seed: seed,
  grid: ChunkGrid(size),
  tiles: tiles,
);

/// Renders chunks x -2..2, y -1..0 as one character per tile.
String _render(ChunkGenerator chunks) {
  const chars = {
    _water: '~',
    _sand: '.',
    _grass: ',',
    _forest: 'T',
    _stone: '^',
    _dirt: '=',
  };
  final size = chunks.grid.size;
  final rows = List.generate(2 * size, (_) => StringBuffer());
  for (var cy = -1; cy <= 0; cy++) {
    for (var cx = -2; cx <= 2; cx++) {
      final chunk = chunks.generate(ChunkCoord(cx, cy));
      for (var i = 0; i < chunks.grid.area; i++) {
        final type = chunks.palette[chunk.tiles[i]];
        rows[(cy + 1) * size + i ~/ size].write(chars[type]);
      }
    }
  }
  return rows.join('\n');
}

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
    expect(_render(_chunks([const _RoadPass()])), _golden.trimLeft());
  });

  test('passes run in order and see earlier changes', () {
    final seen = <TileType>[];
    final chunks = _chunks([
      _CallbackPass((chunk) => chunk.setTile(chunk.coords.first, _dirt)),
      _CallbackPass((chunk) => seen.add(chunk.tileAt(chunk.coords.first))),
    ]);
    chunks.generate(const ChunkCoord(3, -4));
    expect(seen, [_dirt]);
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
          final isOcean = chunk.valueAt(_elevation, coord) < -0.05;
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
      _CallbackPass((chunk) => chunk.setTile(chunk.coords.first, _dirt)),
    ]);
    final chunk = chunks.generate(const ChunkCoord(0, 0));
    final unchanged = _chunks([]).generate(const ChunkCoord(0, 0));
    expect(chunk.biomes, unchanged.biomes);
  });

  test('placing a tile that is not in the tileset throws', () {
    final chunks = _chunks([
      _CallbackPass((chunk) => chunk.setTile(chunk.coords.first, _dirt)),
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
        attempt(() => chunk.setTile(outside, _dirt));
        attempt(() => chunk.biomeAt(outside));
        attempt(() => chunk.valueAt(_elevation, outside));
      }),
    ]);
    chunks.generate(const ChunkCoord(0, 0));
    expect(errors, hasLength(4));
  });
}
