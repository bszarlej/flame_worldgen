# flame_worldgen

![Demo](assets/demo.gif)

This package provides a lightweight, modular system for managing
**procedurally generated tilemaps** in Flutter using the [Flame
engine](https://flame-engine.org/).\
It is built around the concept of **chunks**, **noise-based terrain
generation**, and **sprite selectors** for flexible rendering.


<a title="CI" href="https://github.com/bszarlej/flame_worldgen/actions/workflows/ci.yaml"><img src="https://github.com/bszarlej/flame_worldgen/actions/workflows/ci.yaml/badge.svg"></a>
<a title="Pub" href="https://pub.dev/packages/flame_worldgen" ><img src="https://img.shields.io/pub/v/flame_worldgen.svg?style=popout"></a>
<a title="Pub Points" href="https://pub.dev/packages/flame_worldgen/score"><img src="https://img.shields.io/pub/points/flame_worldgen.svg?style=popout"></a>
<a title="Pub Likes" href="https://pub.dev/packages/flame_worldgen/score"><img src="https://img.shields.io/pub/likes/flame_worldgen.svg?style=popout"></a>
<a title="Pub Downloads" href="https://pub.dev/packages/flame_worldgen/score" ><img src="https://img.shields.io/pub/dm/flame_worldgen"></a>

## ✨ Features

-   📦 **Chunk-based world streaming**
    -   Dynamically load/unload chunks around the camera or player.
    -   Adjustable view distance and chunk cache for performance tuning.
-   🌄 **Noise-driven terrain generation**
    -   Powered by [fast_noise](https://pub.dev/packages/fast_noise).
    -   Heightmaps per chunk for flexible tile selection.
-   🎨 **Sprite selection system**
    -   `StaticSpriteSelector` --- pick a tile based only on noise
        and/or position.
    -   `AnimatedSpriteSelector` --- cycle through frames per tile.
    -   `WeightedSpriteSelector` --- probabilistic sprite selection with
        noise-, and position-based weights.
-   🖼 **Batch rendering with Flame's `SpriteBatch`**
    -   Efficient tile rendering using batched draw calls.
-   🎬 **Tile animations**
    -   `TileAnimationController` updates frame indices at a fixed
        duration.
    -   Integrates seamlessly with selectors.
-   🛠 **Utility functions**
    -   Convert between chunk, tile, and world coordinates.


## 🚀 Usage

### 1. Create a ChunkManager

``` dart
final chunkManager = ChunkManager(
  noise: PerlinFractalNoise( // Choose your noise generator
    seed: seed,
    frequency: 0.0005,
    octaves: 5,
    lacunarity: 2.0,
  ),
  chunkSize: Vector2i(16, 16),
  tileSize: Vector2i(16, 16),
  viewDistance: 4,
);
```

### 2. Configure your TileLayers

``` dart
final waterLayer = TileLayerComponent(
  chunkManager: chunkManager,
  spriteBatch: SpriteBatch(images.fromCache('water.png')),
  config: TileLayerConfig(
    animationController: TileAnimationController(frameDuration: 0.3),
    spriteSelector: AnimatedSpriteSelector((noise, _) {
      // render animated water all over the map
      return [
          Rect.fromLTWH(0, 0, 16, 16), // 1. frame
          Rect.fromLTWH(16, 0, 16, 16), // 2. frame
          Rect.fromLTWH(32, 0, 16, 16), // 3. frame
          Rect.fromLTWH(48, 0, 16, 16), // 4. frame
        ];
    }),
  ),
  priority: -0x80000000,
);

final groundLayer = TileLayerComponent(
  chunkManager: chunkManager,
  spriteBatch: SpriteBatch(images.fromCache('grass.png')),
  config: TileLayerConfig(
    animationController: TileAnimationController(frameDuration: 0.3), // animation controller is needed to animate `WeightedSprite.multi` sprite 
    spriteSelector: WeightedSpriteSelector(
      options: [
        WeightedSprite.single(
          Rect.fromLTWH(16, 16, 16, 16),
          weight: (noise, _) => 0.7, // 70% chance to get this tile
        ),
        WeightedSprite.single(
          Rect.fromLTWH(0, 80, 16, 16),
          weight: (noise, _) => 0.15, // 15% chance to get this tile
        ),
        WeightedSprite.multi([ // Animated tile
          Rect.fromLTWH(32, 96, 16, 16),
          Rect.fromLTWH(48, 96, 16, 16),
          Rect.fromLTWH(64, 96, 16, 16),
          Rect.fromLTWH(80, 96, 16, 16),
        ], weight: (noise, _) => 0.15), // 15% chance to get this tile
      ],
      predicate: (noise, _) => noise > -0.08, // only render grass when if the noise value is bigger than -0.08
    ),
  ),
  priority: -0x7FFFFFFF, // render the ground layer with the priority 1 higher than the water layer
);

// add the layers to the world
world.add(groundLayer);
world.add(waterLayer);
```

## 🧩 Sprite Selection Strategies

### StaticSpriteSelector

Selects a sprite based on noise and position only.

``` dart
StaticSpriteSelector((noise, _) => noise > 0.5 ? grassTile : waterTile);
```

### AnimatedSpriteSelector

Cycles through frames per tile.

``` dart
AnimatedSpriteSelector((noise, _) =>
  noise > 0.5 ? grassFrames : waterFrames
);
```

### WeightedSpriteSelector

Weighted random sprite choice.

``` dart
WeightedSpriteSelector(
  predicate: (noise, _) => noise > 0.5,
  options: [
    WeightedSprite.single(grassTile, weight: (_, _) => 0.7), // 70% probability
    WeightedSprite.single(flowerTile, weight: (_, _) => 0.3), // 30% probability
  ],
);
```
> [!TIP]
> For working example and usage, check out the  [example folder](example/).

------------------------------------------------------------------------

## 📏 Coordinate Conversion Helpers

-   `chunkToWorldPosition(chunkCoords, chunkWorldSize)`\
-   `worldToChunkPosition(worldPos, chunkWorldSize)`\
-   `tileToWorldPosition(tileCoords, tileSize)`\
-   `worldToTilePosition(worldPos, tileSize)`

These make it easy to move between world, chunk, and tile coordinates.

------------------------------------------------------------------------

## 📡 Chunk Streaming

-   The `ChunkManager` loads/unloads chunks around the camera or player.
-   Emits `ChunkUpdateInfo` events on changes (loaded/unloaded chunks).
-   Integrates with `TileLayerComponent` to rebuild batches efficiently.

------------------------------------------------------------------------

## ⚡ Performance Notes

-   SpriteBatch drastically reduces draw calls.
-   Chunk caching avoids regenerating terrain unnecessarily.

## Contributing

Contributions and suggestions are welcome! Feel free to open issues or submit pull requests.