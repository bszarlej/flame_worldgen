import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'y_priority.dart';

enum PlayerState {
  idleDown('idle_down'),
  idleUp('idle_up'),
  idleSide('idle_side'),
  runDown('run_down'),
  runUp('run_up'),
  runSide('run_side');

  final String name;

  const PlayerState(this.name);

  static PlayerState fromName(String name) {
    return PlayerState.values.firstWhere((element) => element.name == name);
  }
}

class Player extends SpriteAnimationGroupComponent<PlayerState>
    with KeyboardHandler, HasGameReference<FlameWorldgenExample>, YPriority {
  Set<LogicalKeyboardKey> _keysPressed = {};
  final _moveSpeed = 100.0;
  final _direction = Vector2.zero();
  final _prevDirection = Vector2.zero();

  Player({super.position});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(
      RectangleHitbox.relative(
        Vector2(2 / 7, 0.25),
        position: Vector2(16 * 5 / 7, 24),
        parentSize: Vector2(32, 32),
      ),
    );

    anchor = const Anchor(0.5, 0.936);

    final idleImg = game.images.fromCache('player_idle.png');
    final runImg = game.images.fromCache('player_run.png');

    animations = {
      PlayerState.idleDown: SpriteAnimation.fromFrameData(
        idleImg,
        SpriteAnimationData.sequenced(
          amount: 2,
          stepTime: 0.4,
          textureSize: Vector2.all(32),
        ),
      ),
      PlayerState.idleUp: SpriteAnimation.fromFrameData(
        idleImg,
        SpriteAnimationData.sequenced(
          amount: 2,
          stepTime: 0.4,
          textureSize: Vector2.all(32),
          texturePosition: Vector2(0, 32),
        ),
      ),
      PlayerState.idleSide: SpriteAnimation.fromFrameData(
        idleImg,
        SpriteAnimationData.sequenced(
          amount: 2,
          stepTime: 0.4,
          textureSize: Vector2.all(32),
          texturePosition: Vector2(0, 64),
        ),
      ),
      PlayerState.runDown: SpriteAnimation.fromFrameData(
        runImg,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.2,
          textureSize: Vector2.all(32),
        ),
      ),
      PlayerState.runUp: SpriteAnimation.fromFrameData(
        runImg,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.2,
          textureSize: Vector2.all(32),
          texturePosition: Vector2(0, 32),
        ),
      ),
      PlayerState.runSide: SpriteAnimation.fromFrameData(
        runImg,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.2,
          textureSize: Vector2.all(32),
          texturePosition: Vector2(0, 64),
        ),
      ),
    };

    current = PlayerState.idleDown;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _direction.setZero();

    if (_keysPressed.contains(LogicalKeyboardKey.keyW)) _direction.y = -1;
    if (_keysPressed.contains(LogicalKeyboardKey.keyA)) _direction.x = -1;
    if (_keysPressed.contains(LogicalKeyboardKey.keyS)) _direction.y = 1;
    if (_keysPressed.contains(LogicalKeyboardKey.keyD)) _direction.x = 1;

    double boost = 1;
    if (_keysPressed.contains(LogicalKeyboardKey.shiftLeft)) {
      boost = 5;
    }

    if (!_direction.isZero()) {
      _direction.normalize();
      position += _direction * boost * _moveSpeed * dt;
      _prevDirection.setFrom(_direction);
      scale.x = _direction.x < 0 ? -1 : 1;
    }

    _updateAnimation();
  }

  void _updateAnimation() {
    String animPrefix = '';
    String animSuffix = '';

    if (_direction.isZero()) {
      animPrefix = 'idle';
    } else {
      animPrefix = 'run';
    }

    if (_direction.y > 0) {
      animSuffix = 'down';
    } else if (_direction.y < 0) {
      animSuffix = 'up';
    } else if (_prevDirection.y > 0) {
      animSuffix = 'down';
    } else if (_prevDirection.y < 0) {
      animSuffix = 'up';
    } else {
      animSuffix = 'side';
    }

    current = PlayerState.fromName('${animPrefix}_$animSuffix');
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keysPressed = keysPressed;
    return super.onKeyEvent(event, keysPressed);
  }
}
