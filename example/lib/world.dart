import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flame_worldgen/flame_worldgen.dart';

// What the world is: tile types, noise fields, biomes and passes.

const water = TileType('water', solid: true, tags: {'liquid'});
const sand = TileType('sand');
const grass = TileType('grass');
const forestFloor = TileType('forest floor');
const stone = TileType('stone', solid: true);
const dirt = TileType('dirt');

final elevation = NoiseField.fbm('elevation', frequency: 0.01, octaves: 5);
final moisture = NoiseField.simplex(
  'moisture',
  frequency: 0.02,
  warp: const DomainWarp(strength: 20),
);

final generator = WorldGenerator(
  fields: [elevation, moisture],
  biomes: [
    Biome('ocean', ground: water, when: (s) => s[elevation] < -0.05),
    Biome('beach', ground: sand, when: (s) => s[elevation] < 0.02),
    Biome(
      'mountains',
      ground: stone,
      when: (s) => s[elevation] > 0.35,
      scatter: const [ScatterRule('rocks', density: 0.05, minDistance: 2)],
    ),
    Biome(
      'forest',
      ground: forestFloor,
      when: (s) => s[moisture] > 0.2,
      scatter: const [ScatterRule('trees', density: 0.15, minDistance: 1.5)],
    ),
    const Biome(
      'plains',
      ground: grass,
      scatter: [ScatterRule('bushes', density: 0.02, minDistance: 3)],
    ),
  ],
  passes: const [RoadPass()],
);

/// Lays an east-west road every 64 tiles through plains and forest.
class RoadPass extends GenerationPass {
  const RoadPass();

  @override
  void apply(ChunkBuilder chunk) {
    for (final coord in chunk.coords) {
      final biome = chunk.biomeAt(coord).name;
      if (coord.y % 64 == 0 && (biome == 'plains' || biome == 'forest')) {
        chunk.setTile(coord, dirt);
      }
    }
  }
}

// How the world looks. Until the example has a real tileset, the sprite sheet
// is drawn in code. Row 0 has one coloured square per tile type, then the
// grass variants. Row 1 has the frames of the water animation.

const tileSize = 16;

final _colors = {
  water: Color(0xFF2E6FB7),
  sand: Color(0xFFE3D08A),
  grass: Color(0xFF6DAA45),
  forestFloor: Color(0xFF2F6B35),
  stone: Color(0xFF8A8A8A),
  dirt: Color(0xFF8B5E3C),
};

/// Slightly darker and lighter grass, drawn now and then among the plain
/// grass.
const _grassVariants = [Color(0xFF629C3D), Color(0xFF78B34F)];

const _waterFrames = 4;

/// Draws the sprite sheet and returns the tileset that uses it.
Tileset createTileset() {
  const size = tileSize * 1.0;
  final colors = [..._colors.values, ..._grassVariants];
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  for (final (index, color) in colors.indexed) {
    canvas.drawRect(
      Rect.fromLTWH(index * size, 0, size, size),
      Paint()..color = color,
    );
  }

  // Water with two light ripples that drift right, 3 pixels per frame.
  final ripple = Paint()..color = const Color(0xFF5B93D1);
  for (var frame = 0; frame < _waterFrames; frame++) {
    final left = frame * size;
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(left, size, size, size))
      ..drawRect(
        Rect.fromLTWH(left, size, size, size),
        Paint()..color = _colors[water]!,
      );
    for (final (x, y) in [(2, 4), (9, 11)]) {
      for (final wrap in [0, -tileSize]) {
        canvas.drawRect(
          Rect.fromLTWH(
            left + (x + frame * 3) % tileSize + wrap,
            size + y,
            5,
            1,
          ),
          ripple,
        );
      }
    }
    canvas.restore();
  }

  final image = recorder.endRecording().toImageSync(
    tileSize * colors.length,
    tileSize * 2,
  );

  final types = _colors.keys.toList();
  return Tileset(
    image: image,
    tileSize: Vector2.all(size),
    tiles: {
      for (final (index, type) in types.indexed)
        type: switch (type) {
          water => TileSprite.animated([
            for (var frame = 0; frame < _waterFrames; frame++) (frame, 1),
          ], stepTime: 0.4),
          grass => TileSprite.variants(
            [
              TileSprite.at(index, 0),
              TileSprite.at(types.length, 0),
              TileSprite.at(types.length + 1, 0),
            ],
            weights: [8, 1, 1],
          ),
          _ => TileSprite.at(index, 0),
        },
    },
  );
}
