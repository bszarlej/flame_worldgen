import 'tile_type.dart';

/// Assigns each [TileType] in a world a compact numeric id, so chunks can
/// store tiles as 16-bit integers.
///
/// Ids depend on the order the types were added and are only valid while the
/// game runs. Save files store names instead, so reordering tile types never
/// breaks a save.
class TilePalette {
  /// Creates a palette with [types], in order.
  ///
  /// The same instance may appear more than once. Throws if two different
  /// instances share a name, or if there are more than [maxTypes] types.
  TilePalette(Iterable<TileType> types) {
    for (final type in types) {
      if (_ids.containsKey(type)) continue;
      if (type.name.isEmpty) {
        throw ArgumentError.value(
          type,
          'types',
          'tile names must not be empty',
        );
      }
      final existing = _byName[type.name];
      if (existing != null) {
        throw ArgumentError.value(
          type,
          'types',
          'Two different tile types are named "${type.name}"',
        );
      }
      if (_types.length == maxTypes) {
        throw ArgumentError.value(
          type,
          'types',
          'A world can have at most $maxTypes tile types',
        );
      }
      _ids[type] = _types.length;
      _byName[type.name] = type;
      _types.add(type);
    }
  }

  /// The largest number of tile types a palette can hold.
  static const maxTypes = 65536;

  final _types = <TileType>[];
  final _ids = Map<TileType, int>.identity();
  final _byName = <String, TileType>{};

  /// The number of tile types.
  int get length => _types.length;

  /// All tile types, indexed by id.
  List<TileType> get types => List.unmodifiable(_types);

  /// Returns the tile type with [id].
  TileType operator [](int id) => _types[id];

  /// Returns the id of [type].
  ///
  /// Throws if [type] isn't in this palette.
  int idOf(TileType type) =>
      _ids[type] ??
      (throw ArgumentError.value(type, 'type', 'is not in this palette'));

  /// Whether [type] is in this palette.
  bool contains(TileType type) => _ids.containsKey(type);

  /// Returns the tile type called [name], or null if there is none.
  TileType? byName(String name) => _byName[name];
}
