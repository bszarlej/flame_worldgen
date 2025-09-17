import 'dart:async';

import 'package:flame/components.dart';

mixin YPriority on PositionComponent {
  bool get canMove => true;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    priority = (y * 1000).toInt();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!canMove) return;

    final newPriority = (y * 1000).toInt();

    if (priority != newPriority) {
      priority = newPriority;
    }
  }
}
