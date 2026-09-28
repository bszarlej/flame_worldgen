import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flame_worldgen/src/core/core.dart'
    show ChunkData, ChunkGenerator, ChunkGrid;
import 'package:flame_worldgen/src/render/chunk_painter.dart';
import 'package:flutter_test/flutter_test.dart';

const _water = TileType('water', solid: true);
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

class _CollisionGame extends FlameGame with HasCollisionDetection {}

/// Records what it collides with.
class _Probe extends PositionComponent with CollisionCallbacks {
  _Probe(Vector2 position)
    : super(position: position, size: Vector2.all(4), anchor: Anchor.center) {
    add(RectangleHitbox());
  }

  final touched = <PositionComponent>[];

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    touched.add(other);
  }
}

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
    bool collision = false,
    void Function(Chunk chunk)? onChunkLoaded,
    void Function(Chunk chunk)? onChunkUnloaded,
  }) => ProceduralMap(
    seed: 42,
    generator: generator ?? _generator(),
    tileset: tileset(),
    chunkSize: 16,
    streaming: streaming,
    collision: collision,
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

  testWithFlameGame('animated tiles all show the current frame', (game) async {
    const frame0 = Rect.fromLTWH(1, 1, 16, 16);
    const frame1 = Rect.fromLTWH(37, 1, 16, 16);
    const grassRect = Rect.fromLTWH(19, 1, 16, 16);

    final water = <TileCoord>[];
    final grass = <TileCoord>[];
    final procedural = ProceduralMap(
      seed: 42,
      generator: _generator(),
      tileset: Tileset(
        image: image,
        tileSize: Vector2.all(16),
        tiles: {
          _water: const TileSprite.animated([(0, 0), (2, 0)], stepTime: 0.5),
          _grass: const TileSprite.at(1, 0),
          _dirt: const TileSprite.at(2, 0),
        },
      ),
      chunkSize: 16,
      onChunkLoaded: (chunk) {
        for (final coord in chunk.coords) {
          (chunk.tileAt(coord) == _water ? water : grass).add(coord);
        }
      },
      onChunkUnloaded: (chunk) {
        water.removeWhere(chunk.contains);
        grass.removeWhere(chunk.contains);
      },
    );
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);
    expect(water, isNotEmpty);
    expect(grass, isNotEmpty);

    void expectFrame(Rect frame) {
      expect(water.map(procedural.sourceRectAt).toSet(), {frame});
      expect(grass.map(procedural.sourceRectAt).toSet(), {grassRect});
    }

    expectFrame(frame0);
    game.update(0.5);
    expectFrame(frame1);

    // Chunks that load now start at the current frame.
    game.camera.viewfinder.position = Vector2(256.0 * 100, 0);
    await _settle(game, procedural);
    expect(water, isNotEmpty);
    expectFrame(frame1);

    game.update(0.5);
    expectFrame(frame0);
  });

  testWithFlameGame("with transitions, chunks draw their neighbours' edge "
      'tiles', (game) async {
    final generator = _generator();
    final set = Tileset(
      image: await generateImage(128, 64),
      tileSize: Vector2.all(16),
      tiles: {
        _water: const TileSprite.at(0, 0),
        _grass: const TileSprite.at(1, 0),
        _dirt: const TileSprite.at(2, 0),
      },
      transitions: const [
        Autotile.dualGrid(upper: _grass, lower: _water, at: (4, 0)),
      ],
    );
    final procedural = ProceduralMap(
      seed: 42,
      generator: generator,
      tileset: set,
      chunkSize: 16,
    );
    await game.world.ensureAdd(procedural);
    await _settle(game, procedural);

    // Paint each chunk again, knowing every tile, and compare.
    final grid = ChunkGrid(16);
    final direct = ChunkGenerator(
      generator,
      seed: 42,
      grid: grid,
      tiles: set.tiles.keys,
    );
    final chunks = <ChunkCoord, ChunkData>{};
    ChunkData chunkAt(ChunkCoord coord) =>
        chunks[coord] ??= direct.generate(coord);
    final painter = ChunkPainter(
      grid: grid,
      tileWidth: 16,
      tileHeight: 16,
      sources: set.sources(direct.palette, seed: 42),
      dualGrid: set.dualGrid(direct.palette),
    );

    for (final coord in procedural.loadedChunks) {
      final painted = procedural.paintedChunk(coord)!;
      final expected = painter.paint(chunkAt(coord), (int x, int y) {
        final tile = TileCoord(x, y);
        return chunkAt(grid.chunkOf(tile)).tileIdAt(tile);
      }, 0);
      final neighboursLoaded = [(-1, 0), (0, -1), (-1, -1)].every(
        (d) => procedural.loadedChunks.contains(coord.translate(d.$1, d.$2)),
      );
      if (!neighboursLoaded) continue;
      expect(painted.mesh.length, expected.mesh.length, reason: '$coord');
      for (var i = 0; i < painted.mesh.length; i++) {
        expect(
          (painted.mesh.positionAt(i), painted.mesh.sourceAt(i)),
          (expected.mesh.positionAt(i), expected.mesh.sourceAt(i)),
          reason: '$coord, sprite $i',
        );
      }
    }
  });

  group('queries', () {
    // Tiles on both sides of chunk borders, also at negative coords.
    final coords = [
      for (var y = -20; y <= 20; y += 5)
        for (var x = -33; x <= 63; x += 3) TileCoord(x, y),
    ];

    /// The tile at the centre of [coord].
    Vector2 centreOf(TileCoord coord) =>
        Vector2(coord.x * 16.0 + 8, coord.y * 16.0 + 8);

    void expectGenerated(ProceduralMap procedural) {
      final generator = procedural.generator;
      final direct = ChunkGenerator(
        generator,
        seed: 42,
        grid: ChunkGrid(16),
        tiles: tileset().tiles.keys,
      );
      for (final coord in coords) {
        final chunk = direct.generate(ChunkGrid(16).chunkOf(coord));
        final tile = direct.palette[chunk.tileIdAt(coord)];
        final biome = generator.biomes[chunk.biomeAt(coord)];
        expect(procedural.tileAtCoord(coord), tile, reason: '$coord');
        expect(procedural.tileAt(centreOf(coord)), tile, reason: '$coord');
        expect(procedural.biomeAtCoord(coord), same(biome), reason: '$coord');
        expect(
          procedural.biomeAt(centreOf(coord)),
          same(biome),
          reason: '$coord',
        );
      }
    }

    test('tileCoordAt and positionOf convert between pixels and tiles', () {
      final procedural = map();
      expect(procedural.tileCoordAt(Vector2(0, 15.9)), const TileCoord(0, 0));
      expect(procedural.tileCoordAt(Vector2(16, 32)), const TileCoord(1, 2));
      expect(
        procedural.tileCoordAt(Vector2(-0.1, -16.1)),
        const TileCoord(-1, -2),
      );
      expect(procedural.positionOf(const TileCoord(-2, 3)), Vector2(-32, 48));
      final coord = procedural.tileCoordAt(Vector2(-100, 70));
      expect(procedural.tileCoordAt(procedural.positionOf(coord)), coord);
    });

    test('work before the map is added, by generating chunks', () {
      expectGenerated(map());
    });

    testWithFlameGame('read loaded chunks and generate the others', (
      game,
    ) async {
      final procedural = map();
      await game.world.ensureAdd(procedural);
      await _settle(game, procedural);
      // Chunks -3..2 are loaded, so the coords in chunk 3 aren't.
      expect(procedural.loadedChunks, contains(const ChunkCoord(-3, -2)));
      expect(procedural.loadedChunks, isNot(contains(const ChunkCoord(3, 0))));
      expectGenerated(procedural);
    });

    test('valueAt evaluates the field anywhere', () {
      final procedural = map();
      final elevation = _elevation.sampler(42);
      for (final coord in coords) {
        // At the centre of a tile, it's the value the biomes saw.
        final value = procedural.valueAt(_elevation, centreOf(coord));
        expect(value, elevation(coord.x.toDouble(), coord.y.toDouble()));
        expect(
          procedural.biomeAtCoord(coord).name,
          value < 0 ? 'ocean' : 'plains',
        );
      }
      // Between tile centres, it's the field in between.
      expect(
        procedural.valueAt(_elevation, Vector2(16, 20)),
        elevation(0.5, 0.75),
      );
    });

    test('valueAt rejects fields the generator does not have', () {
      expect(
        () => map().valueAt(NoiseField.simplex('heat'), Vector2.zero()),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("is not one of the generator's fields"),
          ),
        ),
      );
    });
  });

  group('collision', () {
    final grid = ChunkGrid(16);

    Iterable<SolidTiles> solidsOf(ProceduralMap map) =>
        map.children.whereType<SolidTiles>();

    testWithGame(
      'solid tiles get passive hitboxes, per chunk and type',
      _CollisionGame.new,
      (game) async {
        final procedural = map(collision: true);
        await game.world.ensureAdd(procedural);
        await _settle(game, procedural);
        await game.ready();

        final solids = solidsOf(procedural).toList();
        expect(solids, isNotEmpty);
        expect(solids.map((s) => s.type).toSet(), {_water});

        for (final chunk in procedural.loadedChunks) {
          final hitboxes = [
            for (final solid in solidsOf(procedural))
              if (solid.chunk == chunk)
                for (final hitbox in solid.children.whereType<ShapeHitbox>())
                  hitbox,
          ];
          for (final hitbox in hitboxes) {
            expect(hitbox.collisionType, CollisionType.passive);
            expect(hitbox.isSolid, isTrue);
          }
          final origin = grid.origin(chunk);
          for (var y = origin.y; y < origin.y + 16; y++) {
            for (var x = origin.x; x < origin.x + 16; x++) {
              final centre = Vector2(x * 16.0 + 8, y * 16.0 + 8);
              final covering = hitboxes.where((h) => h.containsPoint(centre));
              expect(
                covering.length,
                procedural.tileAtCoord(TileCoord(x, y)).solid ? 1 : 0,
                reason: '($x, $y)',
              );
            }
          }
        }
      },
    );

    testWithGame('hitboxes come and go with their chunks', _CollisionGame.new, (
      game,
    ) async {
      final procedural = map(collision: true);
      await game.world.ensureAdd(procedural);
      await _settle(game, procedural);

      for (final x in [100, 0]) {
        game.camera.viewfinder.position = Vector2(256.0 * x, 0);
        await _settle(game, procedural);
        await game.ready();
        final chunks = solidsOf(procedural).map((s) => s.chunk).toSet();
        expect(chunks, isNotEmpty);
        expect(procedural.loadedChunks.toSet().containsAll(chunks), isTrue);
      }

      game.world.remove(procedural);
      await game.ready();
      expect(solidsOf(procedural), isEmpty);
      expect(game.collisionDetection.items, isEmpty);

      await game.world.ensureAdd(procedural);
      await _settle(game, procedural);
      await game.ready();
      expect(solidsOf(procedural), isNotEmpty);
    });

    testWithGame(
      'other components collide with solid tiles',
      _CollisionGame.new,
      (game) async {
        final procedural = map(collision: true);
        await game.world.ensureAdd(procedural);
        await _settle(game, procedural);
        await game.ready();

        /// The centre of a loaded tile of [type].
        Vector2 centreOfA(TileType type) {
          final coord = procedural.loadedChunks
              .expand((c) => [for (var i = 0; i < 256; i++) grid.tileAt(c, i)])
              .firstWhere((coord) => procedural.tileAtCoord(coord) == type);
          return procedural.positionOf(coord) + Vector2.all(8);
        }

        // The probes are smaller than a tile, so they're inside the tile
        // hitboxes and don't cross their edges.
        final wet = _Probe(centreOfA(_water));
        final dry = _Probe(centreOfA(_grass));
        await game.world.ensureAddAll([wet, dry]);
        game.update(0);
        expect(wet.touched, hasLength(1));
        final solid = wet.touched.single as SolidTiles;
        expect(solid.type, _water);
        expect(dry.touched, isEmpty);
      },
    );

    testWithFlameGame('without collision, there are no hitboxes', (game) async {
      final procedural = map();
      await game.world.ensureAdd(procedural);
      await _settle(game, procedural);
      await game.ready();
      expect(solidsOf(procedural), isEmpty);
    });

    testWithFlameGame('collision needs HasCollisionDetection', (game) async {
      await expectLater(
        () => game.world.ensureAdd(map(collision: true)),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains('needs HasCollisionDetection'),
          ),
        ),
      );
    });
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
