import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:test/test.dart';

class _GameTile extends TileType {
  const _GameTile(super.name, {required this.speed, super.solid});

  final double speed;
}

void main() {
  test('defaults', () {
    const grass = TileType('grass');
    expect(grass.solid, isFalse);
    expect(grass.tags, isEmpty);
    expect(grass.properties, isEmpty);
  });

  test('hasTag', () {
    const water = TileType('water', tags: {'liquid'});
    expect(water.hasTag('liquid'), isTrue);
    expect(water.hasTag('solid'), isFalse);
  });

  test('properties', () {
    const dirt = TileType('dirt', properties: {'speed': 0.8});
    expect(dirt.properties['speed'], 0.8);
  });

  test('compares by identity', () {
    // ignore: prefer_const_constructors
    expect(TileType('grass'), isNot(TileType('grass')));
    expect(const TileType('grass'), same(const TileType('grass')));
  });

  test('can be used as a key in const maps', () {
    const grass = TileType('grass');
    const sprites = {grass: 1};
    expect(sprites[grass], 1);
  });

  test('can be extended with typed data', () {
    const mud = _GameTile('mud', speed: 0.5, solid: true);
    const TileType type = mud;
    expect(type.name, 'mud');
    expect(type.solid, isTrue);
    expect((type as _GameTile).speed, 0.5);
  });

  test('toString', () {
    expect(const TileType('sand').toString(), 'TileType(sand)');
  });
}
