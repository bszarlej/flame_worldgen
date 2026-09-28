import 'dart:ui';

import 'package:flame_worldgen/src/render/chunk_mesh.dart';
import 'package:flutter_test/flutter_test.dart';

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

/// A 2 × 1 atlas of 4 × 4 pixel tiles: red, then blue.
Future<Image> _atlas() {
  final recorder = PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = _red)
    ..drawRect(const Rect.fromLTWH(4, 0, 4, 4), Paint()..color = _blue);
  return recorder.endRecording().toImage(8, 4);
}

const _redTile = Rect.fromLTWH(0, 0, 4, 4);
const _blueTile = Rect.fromLTWH(4, 0, 4, 4);

/// Renders [mesh] into a 8 × 4 image and returns the colour of each 4 × 4
/// cell, from the left.
Future<List<Color>> _render(ChunkMesh mesh, Image atlas) async {
  final recorder = PictureRecorder();
  mesh.render(Canvas(recorder), atlas, Paint());
  final image = await recorder.endRecording().toImage(8, 4);
  final bytes = (await image.toByteData())!;
  Color pixel(int x, int y) {
    final rgba = bytes.getUint32((y * 8 + x) * 4);
    return Color((rgba >> 8) | (rgba & 0xFF) << 24);
  }

  return [pixel(1, 1), pixel(5, 2)];
}

void main() {
  test('draws each sprite at its position', () async {
    final atlas = await _atlas();
    final mesh = ChunkMesh(4);
    expect(mesh.add(_blueTile, 0, 0), 0);
    expect(mesh.add(_redTile, 4, 0), 1);
    expect(mesh.length, 2);

    expect(await _render(mesh, atlas), [_blue, _red]);
  });

  test('setSource changes what a sprite shows', () async {
    final atlas = await _atlas();
    final mesh = ChunkMesh(2)
      ..add(_redTile, 0, 0)
      ..add(_redTile, 4, 0);
    expect(await _render(mesh, atlas), [_red, _red]);

    mesh.setSource(1, _blueTile);
    expect(mesh.sourceAt(1), _blueTile);
    expect(await _render(mesh, atlas), [_red, _blue]);
  });

  test('an empty mesh draws nothing', () async {
    final atlas = await _atlas();
    expect(await _render(ChunkMesh(4), atlas), [
      const Color(0x00000000),
      const Color(0x00000000),
    ]);
  });
}
