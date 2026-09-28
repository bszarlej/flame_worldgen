import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

/// The draw data of one chunk: a position and a source rect per sprite, in
/// the form [Canvas.drawRawAtlas] takes.
///
/// The data is kept between frames, so drawing a chunk copies nothing, and
/// changing one sprite's source rect only writes 4 numbers. (`drawAtlas`
/// and Flame's `SpriteBatch` convert every sprite on every frame.)
class ChunkMesh {
  /// Creates a mesh with room for [capacity] sprites. It grows when more are
  /// added.
  ChunkMesh(int capacity)
    : _transforms = Float32List(capacity * 4),
      _rects = Float32List(capacity * 4);

  Float32List _transforms;
  Float32List _rects;
  var _length = 0;

  /// The number of sprites.
  int get length => _length;

  /// Adds a sprite showing [source] of the atlas with its top left at
  /// ([x], [y]), and returns its index.
  int add(Rect source, double x, double y) {
    if (_length * 4 == _rects.length) _grow();
    final index = _length++;
    final offset = index * 4;
    _transforms
      ..[offset] = 1
      ..[offset + 1] = 0
      ..[offset + 2] = x
      ..[offset + 3] = y;
    setSource(index, source);
    return index;
  }

  /// Changes the part of the atlas the sprite at [index] shows.
  void setSource(int index, Rect source) {
    final offset = index * 4;
    _rects
      ..[offset] = source.left
      ..[offset + 1] = source.top
      ..[offset + 2] = source.right
      ..[offset + 3] = source.bottom;
  }

  /// The part of the atlas the sprite at [index] shows.
  Rect sourceAt(int index) {
    final offset = index * 4;
    return Rect.fromLTRB(
      _rects[offset],
      _rects[offset + 1],
      _rects[offset + 2],
      _rects[offset + 3],
    );
  }

  /// Where the top left of the sprite at [index] is drawn.
  Offset positionAt(int index) =>
      Offset(_transforms[index * 4 + 2], _transforms[index * 4 + 3]);

  /// Draws every sprite from [atlas].
  void render(Canvas canvas, Image atlas, Paint paint) {
    if (_length == 0) return;
    canvas.drawRawAtlas(
      atlas,
      Float32List.sublistView(_transforms, 0, _length * 4),
      Float32List.sublistView(_rects, 0, _length * 4),
      null,
      null,
      null,
      paint,
    );
  }

  void _grow() {
    final capacity = max(16, _length * 2);
    _transforms = Float32List(capacity * 4)..setAll(0, _transforms);
    _rects = Float32List(capacity * 4)..setAll(0, _rects);
  }
}
