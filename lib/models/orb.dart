import 'package:forge2d/forge2d.dart';
import 'package:flutter/material.dart';
import '../models/orb_config.dart';

class Orb extends BodyComponent {
  final int level;
  final DateTime bornAt;
  late CircleShape _shape;
  
  Orb({
    required Vector2 position,
    required this.level,
  }) : bornAt = DateTime.now() {
    _shape = CircleShape()..radius = OrbConfig.levels[level].radius / 100.0;
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      position: position,
      type: BodyType.dynamic,
      userData: this,
    );

    final body = world.createBody(bodyDef);
    
    final fixtureDef = FixtureDef(
      _shape,
      restitution: 0.4,
      friction: 0.1,
      density: 1.0,
    );
    
    body.createFixture(fixtureDef);
    return body;
  }

  Color get color => OrbConfig.levels[level].color;
  double get radius => OrbConfig.levels[level].radius;
  
  bool get isOldEnough {
    return DateTime.now().difference(bornAt).inMilliseconds > 2000;
  }
}

abstract class BodyComponent {
  late Body body;
  late World world;
  late Vector2 position;

  void setWorld(World world, Vector2 position) {
    this.world = world;
    this.position = position;
    body = createBody();
  }

  Body createBody();
}