import 'dart:ui';

import 'package:flame_worldgen/src/core/core.dart';
import 'package:flame_worldgen/src/render/chunk_painter.dart';
import 'package:flame_worldgen/src/render/dual_grid.dart';
import 'package:flame_worldgen/src/render/tile_sources.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// Tile ids. Water, sand and grass are terrains, from low to high. Roads
// aren't, so they get hard edges.
const _water = 0;
const _sand = 1;
const _grass = 2;
const _road = 3;

/// The atlas rect of each tile id, 8 × 8 pixels.
Rect _tile(int id) => Rect.fromLTWH(id * 10.0, 0, 8, 8);

/// The atlas rect of the transition for [mask], from [lower] to [upper].
Rect _transition(int upper, int lower, int mask) =>
    Rect.fromLTWH(mask * 10.0, 100.0 + upper * 20 + lower, 8, 8);

/// Quarter [part] (0 top left to 3 bottom right) of the atlas rect of [id].
Rect _quarter(int id, int part) {
  final tile = _tile(id);
  return Rect.fromLTWH(
    tile.left + (part & 1) * 4,
    tile.top + (part >> 1) * 4,
    4,
    4,
  );
}

TileSources _sources({Map<int, List<Rect>> animations = const {}}) =>
    TileSources(
      rects: [
        for (var id = 0; id < 4; id++) animations[id] ?? [_tile(id)],
      ],
      cumulativeWeights: List.filled(4, null),
      stepTimes: [
        for (var id = 0; id < 4; id++) animations.containsKey(id) ? 1.0 : null,
      ],
      seed: 0,
    );

final _dualGrid = DualGrid(['water', 'sand', 'grass', 'road'], [0, 1, 2, -1], {
  for (final (upper, lower) in [(_sand, _water), (_grass, _sand)])
    (upper, lower): [
      for (var mask = 0; mask < 16; mask++) _transition(upper, lower, mask),
    ],
});

ChunkPainter _painter({bool dualGrid = true, TileSources? sources}) =>
    ChunkPainter(
      grid: ChunkGrid(4),
      tileWidth: 8,
      tileHeight: 8,
      sources: sources ?? _sources(),
      dualGrid: dualGrid ? _dualGrid : null,
    );

/// A 4 × 4 chunk at [coord] of [fill], except for [tiles].
ChunkData _chunk(
  int fill, {
  ChunkCoord coord = const ChunkCoord(0, 0),
  Map<(int, int), int> tiles = const {},
}) {
  final chunk = ChunkData(coord, ChunkGrid(4));
  chunk.tiles.fillRange(0, 16, fill);
  for (final MapEntry(key: (x, y), value: id) in tiles.entries) {
    chunk.setTileId(TileCoord(x, y), id);
  }
  return chunk;
}

/// Every sprite of [painted]: its position and its atlas rect.
List<(Offset, Rect)> _sprites(PaintedChunk painted) => [
  for (var i = 0; i < painted.mesh.length; i++)
    (painted.mesh.positionAt(i), painted.mesh.sourceAt(i)),
];

/// The sprites of display cell ([x], [y]), which starts half a tile up and
/// left of tile ([x], [y]).
List<(Offset, Rect)> _cell(PaintedChunk painted, int x, int y) {
  final cell = Rect.fromLTWH(x * 8 - 4, y * 8 - 4, 8, 8);
  return [
    for (final sprite in _sprites(painted))
      if (cell.contains(sprite.$1)) sprite,
  ];
}

int? _waterEverywhere(int x, int y) => _water;

void main() {
  test('without a dual grid, each tile is one sprite', () {
    final painted = _painter(
      dualGrid: false,
    ).paint(_chunk(_water, tiles: {(1, 2): _sand}), _waterEverywhere, 0);
    expect(painted.mesh.length, 16);
    expect(painted.bounds, const Rect.fromLTWH(0, 0, 32, 32));
    expect(_sprites(painted)[2 * 4 + 1], (const Offset(8, 16), _tile(_sand)));
  });

  test('one terrain fills each cell with one tile, half a tile up and '
      'left', () {
    final painted = _painter().paint(_chunk(_water), _waterEverywhere, 0);
    expect(painted.mesh.length, 16);
    expect(painted.bounds, const Rect.fromLTWH(-4, -4, 32, 32));
    expect(_sprites(painted).first, (const Offset(-4, -4), _tile(_water)));
    expect(_sprites(painted).last, (const Offset(20, 20), _tile(_water)));
  });

  test('a higher terrain adds a transition in the cells around it', () {
    final painted = _painter().paint(
      _chunk(_water, tiles: {(1, 1): _sand}),
      _waterEverywhere,
      0,
    );
    expect(painted.mesh.length, 16 + 4);
    // The sand tile is the bottom right corner of cell (1, 1), the bottom
    // left of (2, 1), the top right of (1, 2) and the top left of (2, 2).
    for (final (x, y, mask) in [(1, 1, 1), (2, 1, 2), (1, 2, 4), (2, 2, 8)]) {
      final at = Offset(x * 8 - 4, y * 8 - 4);
      expect(_cell(painted, x, y), [
        (at, _tile(_water)),
        (at, _transition(_sand, _water, mask)),
      ], reason: 'cell ($x, $y)');
    }
    expect(_cell(painted, 3, 3), [(const Offset(20, 20), _tile(_water))]);
  });

  test('terrains stack from the lowest to the highest', () {
    final painted = _painter().paint(
      _chunk(_grass, tiles: {(0, 0): _water, (1, 0): _sand, (0, 1): _grass}),
      (x, y) => _grass,
      0,
    );
    // Cell (1, 1): water top left, sand top right, grass below. Sand covers
    // every corner at or above it, grass the bottom two, over sand.
    expect(_cell(painted, 1, 1), [
      (const Offset(4, 4), _tile(_water)),
      (const Offset(4, 4), _transition(_sand, _water, 4 | 2 | 1)),
      (const Offset(4, 4), _transition(_grass, _sand, 2 | 1)),
    ]);
  });

  test('without a transition for a pair, terrains meet at hard edges', () {
    final messages = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = print);

    final painted = _painter().paint(
      _chunk(_water, tiles: {(1, 1): _grass}),
      _waterEverywhere,
      0,
    );
    // The grass tile's top left quarter, in the bottom right of cell (1, 1).
    expect(_cell(painted, 1, 1), [
      (const Offset(4, 4), _tile(_water)),
      (const Offset(8, 8), _quarter(_grass, 0)),
    ]);
    expect(_cell(painted, 2, 2), [
      (const Offset(12, 12), _tile(_water)),
      (const Offset(12, 12), _quarter(_grass, 3)),
    ]);
    expect(messages, hasLength(1));
    expect(messages.single, contains('grass meets water with hard edges'));
  });

  test('tiles that are not terrains are drawn in quarters on top', () {
    final painted = _painter().paint(
      _chunk(_water, tiles: {(1, 1): _road}),
      _waterEverywhere,
      0,
    );
    expect(_cell(painted, 1, 1), [
      (const Offset(4, 4), _tile(_water)),
      (const Offset(8, 8), _quarter(_road, 0)),
    ]);
    expect(_cell(painted, 2, 1), [
      (const Offset(12, 4), _tile(_water)),
      (const Offset(12, 8), _quarter(_road, 1)),
    ]);
    expect(_cell(painted, 1, 2), [
      (const Offset(4, 12), _tile(_water)),
      (const Offset(8, 12), _quarter(_road, 2)),
    ]);
    expect(_cell(painted, 2, 2), [
      (const Offset(12, 12), _tile(_water)),
      (const Offset(12, 12), _quarter(_road, 3)),
    ]);
  });

  test('a cell of only roads is four quarters', () {
    final painted = _painter().paint(_chunk(_road), (x, y) => _road, 0);
    expect(_cell(painted, 2, 2), [
      (const Offset(4 + 8, 4 + 8), _quarter(_road, 3)),
      (const Offset(8 + 8, 4 + 8), _quarter(_road, 2)),
      (const Offset(4 + 8, 8 + 8), _quarter(_road, 1)),
      (const Offset(8 + 8, 8 + 8), _quarter(_road, 0)),
    ]);
  });

  group('neighbours', () {
    // The chunk right of the origin: tiles 4 to 7.
    final water = _chunk(_water, coord: const ChunkCoord(1, 1));

    test('the left column and the top row come from the neighbours', () {
      final painted = _painter().paint(
        water,
        (x, y) => x == 3 ? _sand : _water,
        0,
      );
      // Cells in column 4 have sand in both left corners.
      expect(_cell(painted, 4, 5), [
        (const Offset(28, 36), _tile(_water)),
        (const Offset(28, 36), _transition(_sand, _water, 8 | 2)),
      ]);
      expect(_cell(painted, 5, 5), [(const Offset(36, 36), _tile(_water))]);
    });

    test('the top-left corner comes from the diagonal neighbour', () {
      final painted = _painter().paint(
        water,
        (x, y) => (x, y) == (3, 3) ? _sand : _water,
        0,
      );
      expect(_cell(painted, 4, 4), [
        (const Offset(28, 28), _tile(_water)),
        (const Offset(28, 28), _transition(_sand, _water, 8)),
      ]);
    });

    test('missing neighbours are stood in for by the chunk edge', () {
      final painted = _painter().paint(
        _chunk(_water, coord: const ChunkCoord(1, 1), tiles: {(4, 4): _sand}),
        (x, y) => null,
        0,
      );
      // Tiles (3, 3), (4, 3) and (3, 4) are unknown, and taken from (4, 4).
      expect(_cell(painted, 4, 4), [(const Offset(28, 28), _tile(_sand))]);
    });
  });

  test('animated tiles change frames in whole tiles and quarters', () {
    const frame0 = Rect.fromLTWH(200, 0, 8, 8);
    const frame1 = Rect.fromLTWH(210, 0, 8, 8);
    final sources = _sources(
      animations: {
        _water: [frame0, frame1],
        _road: [frame0, frame1],
      },
    );
    final painted = _painter(
      sources: sources,
    ).paint(_chunk(_water, tiles: {(1, 1): _road}), _waterEverywhere, 0);
    expect(_cell(painted, 1, 1).map((s) => s.$2), [
      frame0,
      const Rect.fromLTWH(200, 0, 4, 4),
    ]);

    painted
      ..showFrame(_water, frame1)
      ..showFrame(_road, frame1);
    expect(_cell(painted, 1, 1).map((s) => s.$2), [
      frame1,
      const Rect.fromLTWH(210, 0, 4, 4),
    ]);
    expect(_cell(painted, 2, 2).map((s) => s.$2), [
      frame1,
      const Rect.fromLTWH(214, 4, 4, 4),
    ]);
  });
}
