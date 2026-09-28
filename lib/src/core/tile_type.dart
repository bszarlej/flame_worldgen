/// What a tile *is*: its name, whether it blocks movement, and any data the
/// game attaches to it.
///
/// Define tile types once, usually as top-level constants:
///
/// ```dart
/// const water = TileType('water', solid: true, tags: {'liquid'});
/// const dirt = TileType('dirt', properties: {'speed': 0.8});
/// ```
///
/// For typed data, extend this class:
///
/// ```dart
/// class GameTile extends TileType {
///   const GameTile(super.name, {required this.speed, super.solid});
///   final double speed;
/// }
/// ```
///
/// The [name] identifies the tile type, including in save files, so keep it
/// stable once you've shipped. Tile types are equal when their names are
/// equal: chunks are generated on another isolate, where a tile type declared
/// as a top-level `final` is a different object. Two tile types in the same
/// world with the same name must have the same definition.
class TileType {
  /// Creates a tile type called [name].
  const TileType(
    this.name, {
    this.solid = false,
    this.tags = const {},
    this.properties = const {},
  });

  /// Identifies the tile type, including in save files.
  final String name;

  /// Whether the tile blocks movement. Solid tiles get collision hitboxes.
  final bool solid;

  /// Labels for grouping tile types, such as `'liquid'` or `'minable'`.
  final Set<String> tags;

  /// Free-form data for the game, such as `{'speed': 0.8}`.
  final Map<String, Object?> properties;

  /// Whether [tags] contains [tag].
  bool hasTag(String tag) => tags.contains(tag);

  @override
  bool operator ==(Object other) => other is TileType && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'TileType($name)';
}
