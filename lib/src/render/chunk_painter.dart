import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/chunk_data.dart';
import '../core/coords.dart';
import 'chunk_mesh.dart';
import 'dual_grid.dart';
import 'tile_sources.dart';

/// Returns the tile id at ([x], [y]), or null if its chunk isn't loaded.
typedef TileIdLookup = int? Function(int x, int y);

/// A chunk turned into sprites.
class PaintedChunk {
  PaintedChunk._(this.mesh, this.animated, this.bounds);

  /// The sprites.
  final ChunkMesh mesh;

  /// For each animated tile id, the sprites that show it, each packed as
  /// `index * 8 + part`: part 0 is the whole tile, 1 to 4 one of its
  /// quarters.
  final Map<int, List<int>> animated;

  /// The area the sprites cover, in pixels.
  final Rect bounds;

  /// Shows [frame] of the animated tile [id] everywhere it appears.
  void showFrame(int id, Rect frame) {
    final sprites = animated[id];
    if (sprites == null) return;
    for (final packed in sprites) {
      final part = packed & 7;
      mesh.setSource(
        packed >> 3,
        part == 0 ? frame : _quarter(frame, part - 1),
      );
    }
  }
}

/// Turns chunks into sprites.
///
/// Without a [dualGrid], each tile is one sprite. With one, the sprites lie
/// on a second grid, offset by half a tile up and left. Display cell (x, y)
/// covers the corners of tiles (x - 1, y - 1), (x, y - 1), (x - 1, y) and
/// (x, y). Each chunk draws the display cells with its own tile
/// coordinates, so it needs the column of tiles left of it and the row
/// above it from its neighbours.
class ChunkPainter {
  /// Creates a painter for chunks of [grid] with tiles of [tileWidth] ×
  /// [tileHeight] pixels, drawn from [sources].
  ChunkPainter({
    required this.grid,
    required this.tileWidth,
    required this.tileHeight,
    required this.sources,
    this.dualGrid,
  });

  /// The size of the chunks.
  final ChunkGrid grid;

  /// The width of a tile, in pixels.
  final double tileWidth;

  /// The height of a tile, in pixels.
  final double tileHeight;

  /// Which part of the atlas each tile id uses.
  final TileSources sources;

  /// The terrains and transitions, or null to draw every tile on its own.
  final DualGrid? dualGrid;

  /// Terrain pairs without a transition, warned about once in debug mode.
  final _warned = <(int, int)>{};

  /// Turns [chunk] into sprites, [time] seconds after animations started.
  ///
  /// With a dual grid, tiles outside the chunk come from [neighbours]. While
  /// a neighbour isn't loaded, the nearest tile in the chunk stands in for
  /// its tiles; paint the chunk again once the neighbour loads.
  PaintedChunk paint(ChunkData chunk, TileIdLookup neighbours, double time) {
    final dualGrid = this.dualGrid;
    return dualGrid == null
        ? _paintTiles(chunk, time)
        : _paintDualGrid(chunk, dualGrid, neighbours, time);
  }

  PaintedChunk _paintTiles(ChunkData chunk, double time) {
    final origin = chunk.origin;
    final size = grid.size;
    final mesh = ChunkMesh(grid.area);
    final animated = <int, List<int>>{};
    for (var index = 0; index < grid.area; index++) {
      final x = origin.x + index % size;
      final y = origin.y + index ~/ size;
      final id = chunk.tiles[index];
      final sprite = mesh.add(
        sources.rectAt(id, x, y, time),
        x * tileWidth,
        y * tileHeight,
      );
      if (sources.isAnimated(id)) (animated[id] ??= []).add(sprite * 8);
    }
    return PaintedChunk._(
      mesh,
      animated,
      Rect.fromLTWH(
        origin.x * tileWidth,
        origin.y * tileHeight,
        size * tileWidth,
        size * tileHeight,
      ),
    );
  }

  PaintedChunk _paintDualGrid(
    ChunkData chunk,
    DualGrid dualGrid,
    TileIdLookup neighbours,
    double time,
  ) {
    final origin = chunk.origin;
    final size = grid.size;
    final left = origin.x;
    final top = origin.y;
    final halfWidth = tileWidth / 2;
    final halfHeight = tileHeight / 2;
    final mesh = ChunkMesh(grid.area);
    final animated = <int, List<int>>{};

    int tileAt(int x, int y) {
      if (x >= left && y >= top) {
        return chunk.tiles[(y - top) * size + (x - left)];
      }
      return neighbours(x, y) ??
          chunk.tiles[(y < top ? 0 : y - top) * size +
              (x < left ? 0 : x - left)];
    }

    void addTile(int id, int x, int y, double px, double py) {
      final sprite = mesh.add(sources.rectAt(id, x, y, time), px, py);
      if (sources.isAnimated(id)) (animated[id] ??= []).add(sprite * 8);
    }

    // Draws quarter [corner] (0 top left to 3 bottom right) of the cell at
    // (px, py), which shows the opposite quarter of tile (x, y).
    void addQuarter(int id, int x, int y, int corner, double px, double py) {
      final part = 3 - corner;
      final sprite = mesh.add(
        _quarter(sources.rectAt(id, x, y, time), part),
        px + (corner & 1) * halfWidth,
        py + (corner >> 1) * halfHeight,
      );
      if (sources.isAnimated(id)) {
        (animated[id] ??= []).add(sprite * 8 + part + 1);
      }
    }

    final ids = List.filled(4, 0);
    final ranks = List.filled(4, 0);
    for (var row = 0; row < size; row++) {
      for (var column = 0; column < size; column++) {
        final x = left + column;
        final y = top + row;
        final px = (x - 0.5) * tileWidth;
        final py = (y - 0.5) * tileHeight;
        ids
          ..[0] = tileAt(x - 1, y - 1)
          ..[1] = tileAt(x, y - 1)
          ..[2] = tileAt(x - 1, y)
          ..[3] = tileAt(x, y);

        // The lowest terrain fills the cell.
        var base = -1;
        for (var corner = 0; corner < 4; corner++) {
          final rank = ranks[corner] = dualGrid.rank(ids[corner]);
          if (rank >= 0 && (base == -1 || rank < ranks[base])) base = corner;
        }
        if (base != -1) {
          addTile(ids[base], x, y, px, py);

          // Each higher terrain covers the corners at or above it.
          var below = ranks[base];
          while (true) {
            var next = -1;
            for (var corner = 0; corner < 4; corner++) {
              final rank = ranks[corner];
              if (rank > below && (next == -1 || rank < ranks[next])) {
                next = corner;
              }
            }
            if (next == -1) break;
            final rank = ranks[next];
            var mask = 0;
            for (var corner = 0; corner < 4; corner++) {
              if (ranks[corner] >= rank) mask |= 8 >> corner;
            }
            final transition = _transition(dualGrid, ids, ranks, next);
            if (transition != null) {
              mesh.add(transition[mask], px, py);
            } else {
              for (var corner = 0; corner < 4; corner++) {
                if (mask & (8 >> corner) != 0) {
                  addQuarter(
                    ids[next],
                    x - 1 + (corner & 1),
                    y - 1 + (corner >> 1),
                    corner,
                    px,
                    py,
                  );
                }
              }
            }
            below = rank;
          }
        }

        // Tiles that aren't terrains get hard edges.
        for (var corner = 0; corner < 4; corner++) {
          if (ranks[corner] < 0) {
            addQuarter(
              ids[corner],
              x - 1 + (corner & 1),
              y - 1 + (corner >> 1),
              corner,
              px,
              py,
            );
          }
        }
      }
    }

    return PaintedChunk._(
      mesh,
      animated,
      Rect.fromLTWH(
        (left - 0.5) * tileWidth,
        (top - 0.5) * tileHeight,
        size * tileWidth,
        size * tileHeight,
      ),
    );
  }

  /// The transition that draws the terrain of corner [upper] over the
  /// highest terrain below it in the cell, or the next one down if that
  /// pair has none. Null if there's none at all.
  List<Rect>? _transition(
    DualGrid dualGrid,
    List<int> ids,
    List<int> ranks,
    int upper,
  ) {
    int? highest;
    var ceiling = ranks[upper];
    while (true) {
      var lower = -1;
      for (var corner = 0; corner < 4; corner++) {
        final rank = ranks[corner];
        if (rank >= 0 &&
            rank < ceiling &&
            (lower == -1 || rank > ranks[lower])) {
          lower = corner;
        }
      }
      if (lower == -1) break;
      highest ??= ids[lower];
      final transition = dualGrid.transition(ids[upper], ids[lower]);
      if (transition != null) return transition;
      ceiling = ranks[lower];
    }
    assert(() {
      if (_warned.add((ids[upper], highest!))) {
        debugPrint(
          'flame_worldgen: ${dualGrid.name(ids[upper])} meets '
          '${dualGrid.name(highest)} with hard edges, because there is no '
          'transition between them. Add Autotile.dualGrid(upper: '
          '${dualGrid.name(ids[upper])}, lower: ${dualGrid.name(highest)}, '
          'at: ...) to the Tileset.',
        );
      }
      return true;
    }());
    return null;
  }
}

/// Quarter [part] (0 top left to 3 bottom right) of [rect].
Rect _quarter(Rect rect, int part) {
  final width = rect.width / 2;
  final height = rect.height / 2;
  return Rect.fromLTWH(
    rect.left + (part & 1) * width,
    rect.top + (part >> 1) * height,
    width,
    height,
  );
}
