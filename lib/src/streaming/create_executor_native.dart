import '../core/coords.dart';
import '../core/generation/world_generator.dart';
import '../core/tile_type.dart';
import 'chunk_executor.dart';
import 'isolate_executor.dart';

/// Creates the executor for this platform: a worker isolate.
///
/// [frameBudget] is only used on the web.
Future<ChunkExecutor> createExecutor(
  WorldGenerator generator, {
  required int seed,
  required ChunkGrid grid,
  required Iterable<TileType> tiles,
  required Duration frameBudget,
}) => IsolateExecutor.spawn(generator, seed: seed, grid: grid, tiles: tiles);
