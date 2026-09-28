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
  /// A tile type may appear more than once. Throws if two tile types with
  /// the same name have different definitions, or if there are more than
  /// [maxTypes] types.
  TilePalette(Iterable<TileType> types) {
    for (final type in types) {
      final existing = _byName[type.name];
      if (existing != null && _sameDefinition(existing, type)) continue;
      if (type.name.isEmpty) {
        throw ArgumentError.value(
          type,
          'types',
          'tile names must not be empty',
        );
      }
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
  final _ids = <TileType, int>{};
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

/// Whether [a] and [b] describe the same tile type. Subclass fields can't be
/// compared, so this only checks what every tile type has.
bool _sameDefinition(TileType a, TileType b) =>
    identical(a, b) ||
    (a.runtimeType == b.runtimeType &&
        a.solid == b.solid &&
        a.tags.length == b.tags.length &&
        a.tags.containsAll(b.tags) &&
        a.properties.length == b.properties.length &&
        a.properties.entries.every(
          (entry) =>
              b.properties.containsKey(entry.key) &&
              b.properties[entry.key] == entry.value,
        ));
