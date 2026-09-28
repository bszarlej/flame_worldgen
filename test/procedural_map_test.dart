import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
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

  ProceduralMap map() => ProceduralMap(
    seed: 42,
    generator: _generator(),
    tileset: tileset(),
    chunkSize: 16,
  );

  // The game is 800 × 600 pixels. Chunks are 16 tiles of 16 pixels, so 256
  // pixels. The camera looks at (0, 0), so it sees x -400..400 and
  // y -300..300: chunks -2..1 in both directions.

  testWithFlameGame('loads the visible chunks plus a margin of 1', (
    game,
  ) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    game.update(0);

    final expected = {
      for (var y = -3; y <= 2; y++)
        for (var x = -3; x <= 2; x++) ChunkCoord(x, y),
    };
    expect(procedural.loadedChunks.toSet(), expected);
  });

  testWithFlameGame('follows the camera and drops far chunks', (game) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    game.update(0);

    game.camera.viewfinder.position = Vector2(256.0 * 100, 0);
    game.update(0);

    final chunks = procedural.loadedChunks.toSet();
    expect(chunks, contains(const ChunkCoord(100, 0)));
    expect(chunks, isNot(contains(const ChunkCoord(0, 0))));
    expect(chunks, hasLength(36));
  });

  testWithFlameGame('keeps chunks just outside the load margin', (game) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    game.update(0);

    // Move one chunk right: column -3 is now 2 chunks outside the view,
    // within the unload margin, so it stays loaded.
    game.camera.viewfinder.position = Vector2(256, 0);
    game.update(0);
    expect(procedural.loadedChunks, contains(const ChunkCoord(-3, 0)));

    // Two more chunks right, and it's dropped.
    game.camera.viewfinder.position = Vector2(256.0 * 3, 0);
    game.update(0);
    expect(procedural.loadedChunks, isNot(contains(const ChunkCoord(-3, 0))));
  });

  testWithFlameGame('zooming out loads more chunks', (game) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    game.update(0);
    final before = procedural.loadedChunks.length;

    game.camera.viewfinder.zoom = 0.25;
    game.update(0);
    expect(procedural.loadedChunks.length, greaterThan(before * 4));
  });

  testWithFlameGame('renders, also in debug mode', (game) async {
    final procedural = map();
    await game.world.ensureAdd(procedural);
    game.update(0);

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
