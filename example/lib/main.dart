import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'world.dart';

void main() {
  runApp(GameWidget(game: FlameWorldgenExample()));
}

/// Fly over an infinite world.
///
/// WASD or arrow keys move, dragging pans, the mouse wheel zooms, F1 toggles
/// chunk borders and scatter spots, and N generates a new world.
class FlameWorldgenExample extends FlameGame
    with KeyboardEvents, ScrollDetector, PanDetector {
  static const _speed = 600.0;
  static const _minZoom = 0.1;
  static const _maxZoom = 4.0;

  late final Tileset _tileset;
  late ProceduralMap _map;
  late final TextComponent _hud;
  final _random = Random();
  var _seed = 42;
  var _debug = false;
  final _direction = Vector2.zero();

  @override
  Future<void> onLoad() async {
    _tileset = createTileset();
    _map = _createMap();
    world.add(_map);

    _hud = TextComponent(position: Vector2.all(8));
    camera.viewport.addAll([_hud, FpsTextComponent(position: Vector2(8, 28))]);
    _updateHud();
  }

  ProceduralMap _createMap() =>
      ProceduralMap(seed: _seed, generator: generator, tileset: _tileset)
        ..debugMode = _debug;

  void _updateHud() {
    _hud.text =
        'seed $_seed · WASD/drag: move · wheel: zoom · '
        'F1: debug · N: new world';
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_direction.isZero()) {
      camera.viewfinder.position +=
          _direction.normalized() * _speed * dt / camera.viewfinder.zoom;
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    double held(LogicalKeyboardKey key, LogicalKeyboardKey arrow) =>
        keysPressed.contains(key) || keysPressed.contains(arrow) ? 1 : 0;

    _direction.setValues(
      held(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight) -
          held(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft),
      held(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) -
          held(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp),
    );

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _debug = !_debug;
        _map.debugMode = _debug;
      } else if (event.logicalKey == LogicalKeyboardKey.keyN) {
        _seed = _random.nextInt(1 << 31);
        _map.removeFromParent();
        _map = _createMap();
        world.add(_map);
        _updateHud();
      }
    }
    return KeyEventResult.handled;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final factor = info.scrollDelta.global.y > 0 ? 0.9 : 1 / 0.9;
    camera.viewfinder.zoom = (camera.viewfinder.zoom * factor).clamp(
      _minZoom,
      _maxZoom,
    );
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    camera.viewfinder.position -= info.delta.global / camera.viewfinder.zoom;
  }
}
