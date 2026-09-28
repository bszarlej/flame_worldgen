import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'player.dart';
import 'world.dart';

void main() {
  runApp(GameWidget(game: FlameWorldgenExample()));
}

/// Walk around an infinite world.
///
/// WASD or arrow keys walk, Shift runs, the mouse wheel zooms, F1 toggles
/// chunk borders, scatter spots and hitboxes, and N generates a new world.
/// Trees, rocks and bushes are spawned by the biomes' `Scatter` rules.
class FlameWorldgenExample extends FlameGame
    with HasCollisionDetection, KeyboardEvents, ScrollDetector {
  static const _minZoom = 0.1;
  static const _maxZoom = 4.0;

  late final Tileset _tileset;
  late ProceduralMap _map;
  late final Player _player;
  late final TextComponent _help;
  late final TextComponent _here;
  final _random = Random();
  var _seed = 42;
  var _debug = false;

  @override
  Future<void> onLoad() async {
    _tileset = createTileset();
    _map = _createMap();
    _player = Player(position: _landNear(_map, Vector2.zero()));
    world.addAll([_map, _player]);
    camera.viewfinder.position = _player.position;

    _help = TextComponent(position: Vector2.all(8));
    _here = TextComponent(position: Vector2(8, 28));
    camera.viewport.addAll([
      _help,
      _here,
      FpsTextComponent(position: Vector2(8, 48)),
    ]);
    _updateHelp();
  }

  ProceduralMap _createMap() => ProceduralMap(
    seed: _seed,
    generator: generator,
    tileset: _tileset,
    collision: true,
    // Below every object, which are sorted by their y coordinate.
    priority: -1_000_000_000,
  );

  /// The centre of the land tile closest to [position] on [map].
  ///
  /// Queries work before the map is added: chunks that aren't loaded are
  /// generated on the spot.
  static Vector2 _landNear(ProceduralMap map, Vector2 position) {
    final start = map.tileCoordAt(position);
    for (var radius = 0; radius < 500; radius++) {
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (max(dx.abs(), dy.abs()) != radius) continue;
          final coord = start.translate(dx, dy);
          if (!map.tileAtCoord(coord).solid) {
            return map.positionOf(coord) + map.tileset.tileSize / 2;
          }
        }
      }
    }
    return position;
  }

  void _updateHelp() {
    _help.text =
        'seed $_seed · WASD: walk · Shift: run · wheel: zoom · '
        'F1: debug · N: new world';
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Collisions are resolved at the end of super.update, after the camera's
    // own update. Following the player here, rather than with camera.follow,
    // keeps the camera from seeing the player inside a wall for a frame,
    // which made the screen shake against walls.
    camera.viewfinder.position = _player.position;
    final position = _player.position;
    final text =
        '${_map.tileAt(position).name} in the '
        '${_map.biomeAt(position).name} · '
        'elevation ${_map.valueAt(elevation, position).toStringAsFixed(2)} · '
        'moisture ${_map.valueAt(moisture, position).toStringAsFixed(2)}';
    if (_here.text != text) _here.text = text;
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    double held(LogicalKeyboardKey key, LogicalKeyboardKey arrow) =>
        keysPressed.contains(key) || keysPressed.contains(arrow) ? 1 : 0;

    _player.direction.setValues(
      held(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight) -
          held(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft),
      held(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) -
          held(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp),
    );
    _player.running =
        keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        keysPressed.contains(LogicalKeyboardKey.shiftRight);

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _debug = !_debug;
        // Children only take their parent's debug mode when they're added,
        // so this also covers objects spawned later.
        for (final component in world.descendants(includeSelf: true)) {
          component.debugMode = _debug;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyN) {
        _seed = _random.nextInt(1 << 31);
        _map.removeFromParent();
        _map = _createMap();
        _player.position = _landNear(_map, _player.position);
        world.add(_map);
        _updateHelp();
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
}
