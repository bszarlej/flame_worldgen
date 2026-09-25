import 'package:flame_worldgen/src/core/tile_palette.dart';
import 'package:flame_worldgen/src/core/tile_type.dart';
import 'package:test/test.dart';

const _water = TileType('water', solid: true);
const _sand = TileType('sand');
const _grass = TileType('grass');

void main() {
  test('assigns ids in order', () {
    final palette = TilePalette([_water, _sand, _grass]);
    expect(palette.length, 3);
    expect(palette.idOf(_water), 0);
    expect(palette.idOf(_sand), 1);
    expect(palette.idOf(_grass), 2);
    expect(palette[1], same(_sand));
    expect(palette.types, [_water, _sand, _grass]);
  });

  test('ignores repeated instances', () {
    final palette = TilePalette([_water, _sand, _water, _sand]);
    expect(palette.length, 2);
    expect(palette.idOf(_sand), 1);
  });

  test('finds types by name', () {
    final palette = TilePalette([_water, _grass]);
    expect(palette.byName('grass'), same(_grass));
    expect(palette.byName('lava'), isNull);
  });

  test('contains', () {
    final palette = TilePalette([_water]);
    expect(palette.contains(_water), isTrue);
    expect(palette.contains(_sand), isFalse);
  });

  test('throws for unknown types', () {
    final palette = TilePalette([_water]);
    expect(() => palette.idOf(_sand), throwsArgumentError);
  });

  test('rejects different types with the same name', () {
    expect(
      () => TilePalette([_grass, const TileType('grass', solid: true)]),
      throwsArgumentError,
    );
  });

  test('rejects empty names', () {
    expect(() => TilePalette([const TileType('')]), throwsArgumentError);
  });

  test('holds at most maxTypes types', () {
    final types = [
      for (var i = 0; i < TilePalette.maxTypes; i++) TileType('t$i'),
    ];
    expect(TilePalette(types).length, TilePalette.maxTypes);
    expect(
      () => TilePalette([...types, const TileType('one too many')]),
      throwsArgumentError,
    );
  });

  test('types is unmodifiable', () {
    final palette = TilePalette([_water]);
    expect(() => palette.types.add(_sand), throwsUnsupportedError);
  });
}
