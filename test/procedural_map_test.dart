import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/core.dart'
    show ChunkGenerator, ChunkGrid;
import 'package:flutter_test/flutter_test.dart';

const _water = TileType('water');
const _grass = TileType('grass');
const _dirt = TileType('dirt');

final _elevation = NoiseField.simplex('elevation', frequency: 0.05);

WorldGenerator _generator() => WorldGenerator(
  fields: [_elevation],
  biomes: [
    Biome('ocean', ground: _water, when: (s) => s[_elevation] < 0),
    const Biome(
      'plains',
      ground: _grass,
      scatter: [ScatterRule('bushes', density: 0.05)],
    ),
  ],
);

/// Updates [game] until [map] has every chunk it wants.
///
/// Chunks are generated on a worker isolate, so they arrive some time after
/// the update that asks for them.
Future<void> _settle(FlameGame game, ProceduralMap map) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (true) {
    game.update(0);
    if (map.isSettled) return;
    if (DateTime.now().isAfter(deadline)) fail('chunks never arrived');
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  late Image image;

  setUpAll(() async {
    image = await generateImage(48, 16);
  });

  Tileset tileset({bool withGrass = true}) => Tileset(
    image: image,
    tileSize: Vector2.all(16),
    tiles: {
      _water: const TileSprite.at(0, 0),
      if (withGrass) _grass: const TileSprite.at(1, 0),
      _dirt: const TileSprite.at(2, 0),
    },
  );

  ProceduralMap map({
    WorldGenerator? generator,
    StreamingOptions? streaming,
    void Function(Chunk chunk)? onChunkLoaded,
    void Function(Chunk chunk)? onChunkUnloaded,
  }) => ProceduralMap(
    seed: 42,
    generator: generator ?? _generator(),
    tileset: tileset(),
    chunkSize: 16,
    streaming: streaming,
    onChunkLoaded: onChunkLoaded,
    onChunkUnloaded: onChunkUnloaded,
  );

  // The game is 800 × 600 pixels. Chunks are 16 tiles of 16 pixels, so 256
  // pixels. The camera looks at (0, 0), so it sees x -400..400 and
  // y -300..300: chunks -2..1 in both directions.

  testWithFlameGame('loads the visible chunks plus a margin of 1', (
    game,
  ) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);

    final expected = {
      for (var y = -3; y <= 2; y++)
        for (var x = -3; x <= 2; x++) ChunkCoord(x, y),
    };
    expect(procedural.loadedChunks.toSet(), expected);
  });

  testWithFlameGame('follows the camera and drops far chunks', (game) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);

    game.camera.viewfinder.position = Vector2(256.0 * 100, 0);
    await _settle(game, procedural);

    final chunks = procedural.loadedChunks.toSet();
    expect(chunks, contains(const ChunkCoord(100, 0)));
    expect(chunks, isNot(contains(const ChunkCoord(0, 0))));
    expect(chunks, hasLength(36));
  });

  testWithFlameGame('keeps chunks just outside the load margin', (game) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);

    // Move one chunk right: column -3 is now 2 chunks outside the view,
    // within the unload margin, so it stays loaded.
    game.camera.viewfinder.position = Vector2(256, 0);
    await _settle(game, procedural);
    expect(procedural.loadedChunks, contains(const ChunkCoord(-3, 0)));

    // Two more chunks right, and it's unloaded.
    game.camera.viewfinder.position = Vector2(256.0 * 3, 0);
    await _settle(game, procedural);
    expect(procedural.loadedChunks, isNot(contains(const ChunkCoord(-3, 0))));
  });

  testWithFlameGame('uses the streaming options', (game) async {
    final procedural = map(
      streaming: StreamingOptions(loadMargin: 0, unloadMargin: 0),
    );
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);
    expect(procedural.loadedChunks, hasLength(16));
  });

  testWithFlameGame('zooming out loads more chunks', (game) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);
    final before = procedural.loadedChunks.length;

    game.camera.viewfinder.zoom = 0.25;
    await _settle(game, procedural);
    expect(procedural.loadedChunks.length, greaterThan(before * 4));
  });

  testWithFlameGame('chunk callbacks see the generated chunks', (game) async {
    final loaded = <ChunkCoord, Chunk>{};
    final unloaded = <ChunkCoord>[];
    final generator = _generator();
    final procedural = map(
      generator: generator,
      onChunkLoaded: (chunk) {
        expect(loaded, isNot(contains(chunk.coord)));
        loaded[chunk.coord] = chunk;
      },
      onChunkUnloaded: (chunk) {
        expect(loaded.remove(chunk.coord), same(chunk));
        unloaded.add(chunk.coord);
      },
    );
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);
    expect(loaded.keys.toSet(), procedural.loadedChunks.toSet());

    final direct = ChunkGenerator(
      generator,
      seed: 42,
      grid: ChunkGrid(16),
      tiles: tileset().tiles.keys,
    );
    for (final chunk in loaded.values) {
      final expected = direct.generate(chunk.coord);
      final types = direct.palette;
      for (final coord in chunk.coords) {
        expect(chunk.tileAt(coord), types[expected.tileIdAt(coord)]);
        expect(
          chunk.biomeAt(coord),
          same(generator.biomes[expected.biomeAt(coord)]),
        );
      }
      expect(
        chunk.spots.map((s) => (s.x, s.y)),
        expected.spots.map((s) => (s.x, s.y)),
      );
    }

    game.camera.viewfinder.position = Vector2(256.0 * 100, 0);
    await _settle(game, procedural);
    expect(unloaded, contains(const ChunkCoord(0, 0)));
    expect(loaded.keys.toSet(), procedural.loadedChunks.toSet());
  });

  testWithFlameGame('a chunk knows where it is', (game) async {
    Chunk? origin;
    final procedural = map(
      onChunkLoaded: (chunk) {
        if (chunk.coord == const ChunkCoord(0, 0)) origin = chunk;
      },
    );
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);

    final chunk = origin!;
    expect(chunk.bounds, const Rect.fromLTWH(0, 0, 256, 256));
    expect(chunk.coords, hasLength(256));
    expect(chunk.contains(const TileCoord(15, 15)), isTrue);
    expect(chunk.contains(const TileCoord(16, 0)), isFalse);
    expect(() => chunk.tileAt(const TileCoord(-1, 0)), throwsArgumentError);
    expect(() => chunk.spots.clear(), throwsUnsupportedError);
  });

  testWithFlameGame('removing the map unloads every chunk', (game) async {
    var loaded = 0;
    final procedural = map(
      onChunkLoaded: (_) => loaded++,
      onChunkUnloaded: (_) => loaded--,
    );
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);
    expect(loaded, 36);

    game.world.remove(procedural);
    await game.ready();
    expect(loaded, 0);
    expect(procedural.loadedChunks, isEmpty);

    // Adding it again starts a new worker.
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);
    expect(loaded, 36);
  });

  testWithFlameGame('renders, also in debug mode', (game) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);

    for (final debug in [false, true]) {
      procedural.debugMode = debug;
      final recorder = PictureRecorder();
      game.render(Canvas(recorder));
      recorder.endRecording().dispose();
    }
  });

  testWithFlameGame('throws when a ground tile has no sprite', (game) async {
    final procedural = ProceduralMap(
      seed: 42,
      generator: _generator(),
      tileset: tileset(withGrass: false),
    );
    await expectLater(
      () => game.world.ensureAdd(procedural),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains("Add it to the Tileset's tiles"),
        ),
      ),
    );
  });

  test('chunkSize must be a power of two', () {
    expect(
      () => ProceduralMap(
        seed: 1,
        generator: _generator(),
        tileset: tileset(),
        chunkSize: 24,
      ),
      throwsArgumentError,
    );
  });
}
