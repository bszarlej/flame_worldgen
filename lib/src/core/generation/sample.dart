import 'dart:typed_data';

import '../coords.dart';
import '../noise/noise_field.dart';

/// The noise values at one tile, passed to biome conditions such as
/// `when: (s) => s[elevation] < 0`.
///
/// A sample is only valid during the call it's passed to. Don't store it.
abstract interface class Sample {
  /// The tile being generated.
  TileCoord get coord;

  /// The value of [field] at [coord], between -1 and 1.
  ///
  /// Throws if [field] isn't one of the generator's fields.
  double operator [](NoiseField field);
}

/// Evaluates a world's noise fields for a whole chunk at once and exposes
/// them one tile at a time through [sample].
///
/// Each field is evaluated once per tile, no matter how many biome conditions
/// read it. The buffers are reused for every chunk.
class ChunkFields {
  /// Prepares [fields] for the world with [worldSeed], in chunks of [grid].
  ///
  /// Throws if two different fields share a name, because they would get the
  /// same seed.
  ChunkFields(Iterable<NoiseField> fields, int worldSeed, this.grid) {
    final byName = <String, NoiseField>{};
    for (final field in fields) {
      if (_slots.containsKey(field)) continue;
      final existing = byName[field.name];
      if (existing != null) {
        throw ArgumentError.value(
          field,
          'fields',
          'Two different noise fields are named "${field.name}"',
        );
      }
      byName[field.name] = field;
      _slots[field] = _samplers.length;
      _samplers.add(field.sampler(worldSeed));
      _values.add(Float64List(grid.area));
    }
    sample = _ChunkSample(this);
  }

  /// The size of the chunks this evaluates.
  final ChunkGrid grid;

  final _slots = Map<NoiseField, int>.identity();
  final _samplers = <NoiseFunction>[];
  final _values = <Float64List>[];

  ChunkCoord _chunk = const ChunkCoord(0, 0);
  int _index = 0;

  /// The sample for the current tile. Move it with [moveTo].
  late final Sample sample;

  /// Evaluates every field for each tile of [chunk].
  void evaluate(ChunkCoord chunk) {
    _chunk = chunk;
    final origin = grid.origin(chunk);
    final size = grid.size;
    for (var slot = 0; slot < _samplers.length; slot++) {
      final sampler = _samplers[slot];
      final values = _values[slot];
      var index = 0;
      for (var y = 0; y < size; y++) {
        final worldY = (origin.y + y).toDouble();
        for (var x = 0; x < size; x++) {
          values[index++] = sampler((origin.x + x).toDouble(), worldY);
        }
      }
    }
  }

  /// Points [sample] at the tile with the row-major [index] in the chunk
  /// last passed to [evaluate].
  void moveTo(int index) => _index = index;
}

class _ChunkSample implements Sample {
  _ChunkSample(this._fields);

  final ChunkFields _fields;

  @override
  TileCoord get coord => _fields.grid.tileAt(_fields._chunk, _fields._index);

  @override
  double operator [](NoiseField field) {
    final slot = _fields._slots[field];
    if (slot == null) {
      throw ArgumentError.value(
        field,
        'field',
        'is not one of the generator\'s fields. Add it to '
            'WorldGenerator(fields: [...])',
      );
    }
    return _fields._values[slot][_fields._index];
  }
}
