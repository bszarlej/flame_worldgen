import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(GameWidget(game: FlameWorldgenExample()));
}

class FlameWorldgenExample extends FlameGame {}
