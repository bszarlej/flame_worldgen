import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TileAnimationController', () {
    test('initial frame is 0', () {
      final controller = TileAnimationController(frameDuration: 0.1);
      expect(controller.currentFrame, 0);
    });

    test('increments frame after enough time passes', () {
      final controller = TileAnimationController(frameDuration: 0.1);

      controller.update(0.05);
      expect(controller.currentFrame, 0, reason: 'Not enough time yet');

      controller.update(0.06); // now exceeds 0.1
      expect(controller.currentFrame, 1);
    });

    test('calls listeners on frame change', () {
      final controller = TileAnimationController(frameDuration: 0.1);
      int called = 0;
      controller.addListener(() {
        called++;
      });

      controller.update(0.11);
      expect(controller.currentFrame, 1);
      expect(called, 1);

      controller.update(0.2);
      expect(controller.currentFrame, 3);
      expect(called, 3);
    });

    test('supports multiple listeners', () {
      final controller = TileAnimationController(frameDuration: 0.05);
      int calledA = 0;
      int calledB = 0;

      controller.addListener(() => calledA++);
      controller.addListener(() => calledB++);

      controller.update(0.06);
      expect(controller.currentFrame, 1);
      expect(calledA, 1);
      expect(calledB, 1);

      controller.update(0.06);
      expect(controller.currentFrame, 2);
      expect(calledA, 2);
      expect(calledB, 2);
    });
  });
}
