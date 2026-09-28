import 'package:flame_worldgen/src/core/chunk_data.dart';
import 'package:flame_worldgen/src/core/coords.dart';
import 'package:flame_worldgen/src/streaming/chunk_cache.dart';
import 'package:test/test.dart';

ChunkData _chunk(int x) => ChunkData(ChunkCoord(x, 0), ChunkGrid(4));

void main() {
  test('get returns cached chunks and leaves them in the cache', () {
    final cache = ChunkCache(4);
    final chunk = _chunk(0);
    cache.put(chunk);
    expect(cache.get(const ChunkCoord(0, 0)), same(chunk));
    expect(cache.get(const ChunkCoord(1, 0)), isNull);
    expect(cache.length, 1);
  });

  test('take removes the chunk', () {
    final cache = ChunkCache(4)..put(_chunk(0));
    expect(cache.take(const ChunkCoord(0, 0)), isNotNull);
    expect(cache.take(const ChunkCoord(0, 0)), isNull);
    expect(cache.length, 0);
  });

  test('drops the least recently used chunks', () {
    final cache = ChunkCache(2)
      ..put(_chunk(0))
      ..put(_chunk(1));
    // Using chunk 0 makes chunk 1 the least recently used.
    cache
      ..get(const ChunkCoord(0, 0))
      ..put(_chunk(2));
    expect(cache.get(const ChunkCoord(1, 0)), isNull);
    expect(cache.get(const ChunkCoord(0, 0)), isNotNull);
    expect(cache.get(const ChunkCoord(2, 0)), isNotNull);
  });

  test('putting a chunk again replaces it', () {
    final cache = ChunkCache(2)..put(_chunk(0));
    final again = _chunk(0);
    cache.put(again);
    expect(cache.length, 1);
    expect(cache.get(const ChunkCoord(0, 0)), same(again));
  });

  test('a capacity of 0 keeps nothing', () {
    final cache = ChunkCache(0)..put(_chunk(0));
    expect(cache.length, 0);
  });

  test('clear and a negative capacity', () {
    final cache = ChunkCache(2)..put(_chunk(0));
    cache.clear();
    expect(cache.length, 0);
    expect(() => ChunkCache(-1), throwsRangeError);
  });
}
