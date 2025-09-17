import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Minimap extends CameraComponent {
  final Anchor? anchor;
  final double radius;
  final double zoom;
  Vector2? position;

  Minimap({
    required this.radius,
    this.anchor,
    this.position,
    this.zoom = 0.1,
    super.world,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    backdrop = CircleComponent(
      radius: radius,
      paint: Paint()
        ..color = Colors.grey.shade800
        ..style = PaintingStyle.fill,
    );

    viewport = CircularViewport(radius)
      ..anchor = anchor ?? Anchor.center
      ..position = position ?? Vector2.zero();

    final miniMapBorder = CircleComponent(
      radius: radius,
      paint: Paint()
        ..color = Colors.grey.shade800.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius / 16,
    );
    viewport.add(miniMapBorder);
    viewfinder.zoom = zoom;
  }
}
