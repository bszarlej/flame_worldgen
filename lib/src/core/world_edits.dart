import 'dart:collection';

import 'coords.dart';

/// The changes a game made to its generated world.
///
/// Only the differences are stored: the rest of the world comes from the
/// seed. Tiles are stored by the name of their type, so reordering or adding
/// tile types never breaks the edits.
///
/// Edits are made through `ProceduralMap.setTile`, which records them here
/// and updates the loaded chunks.
class WorldEdits {
  /// Creates edits that change nothing.
  WorldEdits();

  final _tiles = <TileCoord, String>{};

  /// The tiles that were changed, with the name of their new type.
  Map<TileCoord, String> get tiles => UnmodifiableMapView(_tiles);

  /// Whether nothing was changed.
  bool get isEmpty => _tiles.isEmpty;
}

/// Records that the tile at [coord] was changed to the type called [name].
///
/// Not exported, so games change tiles with `ProceduralMap.setTile`, which
/// also updates the loaded chunks.
void recordTile(WorldEdits edits, TileCoord coord, String name) =>
    edits._tiles[coord] = name;
