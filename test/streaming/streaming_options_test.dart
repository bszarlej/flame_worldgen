import 'package:flame_worldgen/src/streaming/streaming_options.dart';
import 'package:test/test.dart';

void main() {
  test('defaults', () {
    final options = StreamingOptions();
    expect(options.loadMargin, 1);
    expect(options.unloadMargin, 2);
    expect(options.cacheSize, 128);
    expect(options.frameBudget, const Duration(milliseconds: 2));
  });

  test('allows no margins, no cache and no frame budget', () {
    StreamingOptions(
      loadMargin: 0,
      unloadMargin: 0,
      cacheSize: 0,
      frameBudget: Duration.zero,
    );
  });

  test('rejects invalid values', () {
    expect(
      () => StreamingOptions(loadMargin: 2, unloadMargin: 1),
      throwsArgumentError,
    );
    expect(() => StreamingOptions(loadMargin: -1), throwsArgumentError);
    expect(() => StreamingOptions(cacheSize: -1), throwsArgumentError);
    expect(
      () => StreamingOptions(frameBudget: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
  });
}
