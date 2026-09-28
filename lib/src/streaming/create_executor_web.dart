import '../core/coords.dart';
import '../core/generation/world_generator.dart';
import '../core/tile_type.dart';
import 'chunk_executor.dart';
import 'frame_budget_executor.dart';

/// Creates the executor for this platform: generation on the main isolate,
/// at most [frameBudget] per frame.
Future<ChunkExecutor> createExecutor(
  WorldGenerator generator, {
  required int seed,
  required ChunkGrid grid,
  required Iterable<TileType> tiles,
  required Duration frameBudget,
}) async => FrameBudgetExecutor(
  ChunkGenerator(generator, seed: seed, grid: grid, tiles: tiles),
  budget: frameBudget,
);
