# flame_worldgen

<a title="CI" href="https://github.com/bszarlej/flame_worldgen/actions/workflows/ci.yaml"><img src="https://github.com/bszarlej/flame_worldgen/actions/workflows/ci.yaml/badge.svg"></a>
<a title="Pub" href="https://pub.dev/packages/flame_worldgen" ><img src="https://img.shields.io/pub/v/flame_worldgen.svg?style=popout"></a>
<a title="Pub Points" href="https://pub.dev/packages/flame_worldgen/score"><img src="https://img.shields.io/pub/points/flame_worldgen.svg?style=popout"></a>
<a title="Pub Likes" href="https://pub.dev/packages/flame_worldgen/score"><img src="https://img.shields.io/pub/likes/flame_worldgen.svg?style=popout"></a>
<a title="Pub Downloads" href="https://pub.dev/packages/flame_worldgen/score" ><img src="https://img.shields.io/pub/dm/flame_worldgen"></a>

> [!IMPORTANT]
> This README describes the upcoming **3.0** API, which is under active
> development and not published yet. For the current release, see the
> [2.0.0 documentation on pub.dev](https://pub.dev/packages/flame_worldgen/versions/2.0.0).

**Infinite, seeded, procedural tile worlds for [Flame](https://flame-engine.org/).**

Describe your world with noise fields and biomes, map tile types to sprites,
and flame_worldgen handles the rest: it streams chunks around the camera,
generates them off the main thread, autotiles the transitions between
terrains, spawns objects, builds collision, and remembers what the player
changed.

## Features

- **Deterministic worlds.** The same seed produces the same world on every
  platform, so a seed plus the player's edits is a complete save file.
- **Noise fields and biomes.** Combine several named noise fields (elevation,
  moisture, anything you like) and pick biomes from them. First match wins.
- **Chunk streaming.** Chunks load around the camera's visible area and are
  generated in a background isolate on native platforms, or within a per-frame
  time budget on the web, so crossing a chunk border doesn't hitch.
- **Tilesets with variants and animation.** Weighted random variants and
  animated tiles, chosen deterministically per tile.
- **Autotiling.** Smooth transitions between terrains using the dual-grid
  technique, which needs only 16 tiles per terrain pair.
- **Object scattering.** Trees, rocks and other props are spread evenly per
  biome and spawned as regular Flame components when their chunk loads, then
  removed when it unloads.
- **World queries.** Ask what tile or biome is at a position, or read any
  noise field there.
- **Collision.** Solid tiles are merged into as few hitboxes as possible and
  work with Flame's collision detection.
- **Edits and persistence.** Change tiles and remove objects at runtime; only
  the differences from the generated world are stored and serialized.

## Getting started

```sh
flutter pub add flame_worldgen
```

A complete game with an ocean and grassland:

```dart
import 'package:flame/game.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flutter/widgets.dart';

const water = TileType('water', solid: true);
const grass = TileType('grass');

final elevation = NoiseField.fbm('elevation', frequency: 0.01, octaves: 4);

void main() => runApp(GameWidget(game: MyGame()));

class MyGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    world.add(
      ProceduralMap(
        seed: 42,
        generator: WorldGenerator(
          fields: [elevation],
          biomes: [
            Biome('ocean', ground: water, when: (s) => s[elevation] < 0),
            Biome('grassland', ground: grass),
          ],
        ),
        tileset: Tileset(
          image: await images.load('terrain.png'),
          tileSize: Vector2.all(16),
          tiles: {
            water: TileSprite.at(0, 0),
            grass: TileSprite.at(1, 0),
          },
        ),
      ),
    );
  }
}
```

By default the map follows the game's camera. Move the camera and new chunks
appear.

## Core concepts

flame_worldgen keeps **what the world is** separate from **how it looks**:

| Concept | Responsibility |
|---|---|
| `TileType` | What a tile *is*: its name, whether it's solid, tags, custom properties. |
| `WorldGenerator` | Decides which `TileType` goes where, using noise fields and biomes. |
| `Tileset` | Decides how each `TileType` is drawn. |
| `ProceduralMap` | The Flame component that streams, renders and lets you query and edit the world. |

Game logic only ever deals with tile types, never sprites, so you can reskin
the world without touching gameplay code.

## Tile types

```dart
const water = TileType('water', solid: true, tags: {'liquid'});
const sand = TileType('sand');
const grass = TileType('grass');
const dirt = TileType('dirt', properties: {'speed': 0.8});
```

The name identifies a tile type in save files, so keep it stable once you've
shipped.

## Generating the world

### Noise fields

A noise field gives every point in the world a value between -1 and 1.

```dart
final elevation = NoiseField.fbm('elevation', frequency: 0.004, octaves: 5);
final moisture = NoiseField.simplex('moisture', frequency: 0.01);
final temperature = NoiseField.perlin(
  'temperature',
  frequency: 0.002,
  warp: DomainWarp(strength: 40), // bends the field for more natural shapes
);
// x and y are in tiles. Use the seed so every world gets different rivers.
final rivers = NoiseField.custom('rivers', (x, y, seed) => myRivers(x, y, seed));
```

Each field gets its own seed derived from the world seed and the field's name.
Renaming a field changes its output; reordering fields doesn't. Noise values
are identical on every platform, including the web.

### Biomes

Biomes are checked in order, and the first one whose `when` matches is used.
A biome without `when` matches everything, so put it last as a fallback.

```dart
final generator = WorldGenerator(
  fields: [elevation, moisture],
  biomes: [
    Biome('ocean', ground: water, when: (s) => s[elevation] < -0.1),
    Biome('beach', ground: sand, when: (s) => s[elevation] < -0.05),
    Biome('forest', ground: grass, when: (s) => s[moisture] > 0.3),
    Biome('plains', ground: grass),
  ],
);
```

### Custom passes

For things noise can't express, such as roads or rivers, add passes that run
after biomes are placed. Passes run in order, one chunk at a time, and must be
deterministic: use `chunk.random` instead of `Random()`, which gives the same
numbers every time the chunk is generated. Passes can also read
`chunk.biomeAt(coord)` and `chunk.valueAt(field, coord)`, and can place any
tile type that's in the tileset.

```dart
class RoadPass extends GenerationPass {
  const RoadPass();

  @override
  void apply(ChunkBuilder chunk) {
    for (final coord in chunk.coords) {
      if (coord.y % 64 == 0 && chunk.tileAt(coord) == grass) {
        chunk.setTile(coord, dirt);
      }
    }
  }
}

WorldGenerator(fields: [...], biomes: [...], passes: [const RoadPass()]);
```

## Drawing the world

### Tilesets

`TileSprite.at(column, row)` refers to a tile by its grid position in the
image, based on the tileset's `tileSize`.

```dart
final tileset = Tileset(
  image: await images.load('terrain.png'),
  tileSize: Vector2.all(16),
  tiles: {
    // Weighted random variants, picked deterministically per tile.
    grass: TileSprite.variants(
      [TileSprite.at(1, 1), TileSprite.at(0, 5), TileSprite.at(1, 5)],
      weights: [10, 1, 1],
    ),
    sand: TileSprite.at(4, 1),
    // Animated tiles. Only tiles that are actually animated are updated each
    // frame.
    water: TileSprite.animated(
      [(0, 3), (1, 3), (2, 3), (3, 3)],
      stepTime: 0.3,
    ),
  },
  transitions: [...],
);
```

### Autotiling

Without transitions, terrains meet at hard square edges. Add a dual-grid
transition for each pair of terrains that touch. Each one is a 4×4 block of
tiles in the standard dual-grid layout.

```dart
transitions: [
  Autotile.dualGrid(upper: sand, lower: water, at: (0, 8)),
  Autotile.dualGrid(upper: grass, lower: sand, at: (4, 8)),
],
```

`upper` is drawn on top of `lower`. When you change a tile at runtime, the
transitions around it update too.

## Objects

Scatter objects per biome. Spots are spread evenly and are the same every time
a chunk is generated. `spawn` returns any Flame component.

```dart
Biome(
  'forest',
  ground: grass,
  when: (s) => s[moisture] > 0.3,
  scatter: [
    Scatter(
      'trees',
      density: 0.05, // expected objects per tile
      minDistance: 2, // in tiles
      spawn: (spot) => Tree(position: spot.position),
    ),
    Scatter(
      'rocks',
      density: 0.01,
      spawn: (spot) => Rock(position: spot.position, size: spot.random.nextInt(3)),
    ),
  ],
),
```

Spawned components are added to the map's parent (usually your `World`), so
they can be sorted together with the player. They're removed automatically
when their chunk unloads.

## Querying the world

```dart
final tile = map.tileAt(player.position); // TileType
if (tile.hasTag('liquid')) player.swim();

final biome = map.biomeAt(player.position); // Biome
final height = map.valueAt(elevation, player.position); // double

final coord = map.tileCoordAt(player.position); // TileCoord
final topLeft = map.positionOf(coord); // Vector2
```

## Collision

```dart
ProceduralMap(
  collision: true,
  ...
);
```

Solid tiles in each chunk are merged into as few rectangles as possible and
added as `RectangleHitbox`es when the chunk loads. Your game needs Flame's
`HasCollisionDetection` mixin.

## Edits and saving

```dart
// Change a tile. Collision and autotiling around it update.
map.setTile(map.tileCoordAt(target), dirt);

// Remove a spawned object for good, so it doesn't come back when its chunk
// reloads.
map.removeObject(tree);

// Only the differences from the generated world are stored.
final save = map.edits.toJson();

// Restore later with the same seed.
ProceduralMap(seed: 42, edits: WorldEdits.fromJson(save), ...);
```

## Streaming

```dart
ProceduralMap(
  streaming: StreamingOptions(
    loadMargin: 1, // chunks loaded beyond the visible area
    unloadMargin: 2, // chunks kept before unloading, prevents churn at borders
    cacheSize: 128, // generated chunks kept in memory after unloading
    frameBudget: Duration(milliseconds: 2), // generation time per frame on the web
  ),
  onChunkLoaded: (chunk) {},
  onChunkUnloaded: (chunk) {},
  ...
);
```

Chunk callbacks run synchronously during `update`, before the chunk is first
rendered.

## Migrating from 2.x

3.0 is a complete rewrite. The concepts map roughly like this:

| 2.x | 3.0 |
|---|---|
| `ChunkManager` | `ProceduralMap` (streaming is built in) |
| `TileLayerComponent`, `TileLayerConfig` | `ProceduralMap` + `Tileset` |
| Noise thresholds in sprite selectors | `Biome(when: ...)` |
| `StaticSpriteSelector` | `TileSprite.at` |
| `AnimatedSpriteSelector`, `TileAnimationController` | `TileSprite.animated` |
| `WeightedSpriteSelector`, `WeightedSprite` | `TileSprite.variants` |
| Spawning props in `onChunkLoaded` | `Scatter` |
| `Vector2i` | `TileCoord`, `ChunkCoord` |
| Re-exported `fast_noise` | `NoiseField` |

## Roadmap

3.0:

- [ ] Deterministic seeding and hashing
- [ ] Noise fields and biomes
- [ ] Chunk streaming with background generation
- [ ] Tilesets with variants and animation
- [ ] Dual-grid autotiling
- [ ] Object scattering
- [ ] World queries
- [ ] Collision
- [ ] Edits and persistence
- [ ] Hosted web demo

Later:

- [ ] Blob-47 autotiling
- [ ] Structures and prefabs, including hand-made Tiled maps
- [ ] Multiple tile layers
- [ ] Pathfinding grid export

## Contributing

Contributions and suggestions are welcome. Feel free to open an
[issue](https://github.com/bszarlej/flame_worldgen/issues) or submit a pull
request.
