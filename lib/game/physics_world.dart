import 'dart:math';
import 'package:forge2d/forge2d.dart';
import 'package:flutter/material.dart';
import '../models/orb.dart';
import '../models/orb_config.dart';

class PhysicsWorld {
  late World world;
  final List<Orb> orbs = [];
  final double worldWidth = 4.0; // 400 pixels = 4 meters
  final double worldHeight = 7.0; // 700 pixels = 7 meters
  final double deathLineY = 1.5; // 150 pixels = 1.5 meters
  
  Function(int points)? onScoreAdd;
  Function()? onGameOver;
  Function()? onWin;
  Function(int level)? onMerge;
  Function()? onDrop;
  
  bool isSpawning = false;
  int deathTimer = 0;
  DateTime? _lastDropTime;
  static const _minDropInterval = Duration(milliseconds: 400); // Increased from 300ms
  
  // Queue for deferred merges
  final List<_MergeRequest> _pendingMerges = [];

  PhysicsWorld() {
    world = World(Vector2(0, 12.0)); // Gravity
    _createBoundaries();
    world.setContactListener(_ContactListener(this));
  }

  void _createBoundaries() {
    // Ground
    final ground = world.createBody(BodyDef(
      position: Vector2(worldWidth / 2, worldHeight + 0.25),
    ));
    final groundShape = PolygonShape();
    groundShape.setAsBoxXY(worldWidth / 2, 0.25);
    ground.createFixture(FixtureDef(
      groundShape,
      friction: 0.5,
    ));

    // Left wall
    final leftWall = world.createBody(BodyDef(
      position: Vector2(-0.25, worldHeight / 2),
    ));
    final leftShape = PolygonShape();
    leftShape.setAsBoxXY(0.25, worldHeight / 2);
    leftWall.createFixture(FixtureDef(
      leftShape,
      friction: 0.5,
    ));

    // Right wall
    final rightWall = world.createBody(BodyDef(
      position: Vector2(worldWidth + 0.25, worldHeight / 2),
    ));
    final rightShape = PolygonShape();
    rightShape.setAsBoxXY(0.25, worldHeight / 2);
    rightWall.createFixture(FixtureDef(
      rightShape,
      friction: 0.5,
    ));
  }

  void dropOrb(double x) {
    if (isSpawning) return;
    
    isSpawning = true;
    
    // Convert screen x to world x
    final worldX = (x / 100.0).clamp(0.3, worldWidth - 0.3);
    final level = Random().nextInt(3); // Random level 0-2
    
    final orb = Orb(
      position: Vector2(worldX, 0.5),
      level: level,
    );
    
    orb.setWorld(world, Vector2(worldX, 0.5));
    orbs.add(orb);
    
    // Trigger drop callback
    onDrop?.call();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      isSpawning = false;
    });
  }

  void dropOrbWithLevel(double x, int level) {
    if (isSpawning) return;
    
    // Rate limiting: prevent drops faster than 400ms
    final now = DateTime.now();
    if (_lastDropTime != null) {
      final timeSinceLastDrop = now.difference(_lastDropTime!);
      if (timeSinceLastDrop < _minDropInterval) {
        return; // Too fast, ignore this drop
      }
    }
    _lastDropTime = now;
    
    // Limit total number of orbs - reduced from 50 to 40
    if (orbs.length >= 40) {
      return; // Too many orbs, prevent crash
    }
    
    isSpawning = true;
    
    try {
      // Convert screen x to world x
      final worldX = (x / 100.0).clamp(0.3, worldWidth - 0.3);
      
      final orb = Orb(
        position: Vector2(worldX, 0.5),
        level: level,
      );
      
      orb.setWorld(world, Vector2(worldX, 0.5));
      orbs.add(orb);
      
      // Trigger drop callback
      onDrop?.call();
    } catch (e) {
      debugPrint('Drop orb error (handled): $e');
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        isSpawning = false;
      });
    }
  }

  void handleMerge(Orb orbA, Orb orbB) {
    if (orbA.level == orbB.level && orbA.level < OrbConfig.levels.length - 1) {
      // Queue the merge instead of executing immediately
      _pendingMerges.add(_MergeRequest(orbA, orbB));
    }
  }
  
  void _processPendingMerges() {
    if (_pendingMerges.isEmpty) return;
    
    // Process merges in batches to avoid overwhelming the physics engine
    final batchSize = 5;
    final toProcess = _pendingMerges.take(batchSize).toList();
    _pendingMerges.removeRange(0, toProcess.length.clamp(0, _pendingMerges.length));
    
    for (final merge in toProcess) {
      // Check if both orbs still exist and are valid
      if (!orbs.contains(merge.orbA) || !orbs.contains(merge.orbB)) {
        continue;
      }
      
      // Safety check: ensure bodies still exist in world
      if (!world.bodies.contains(merge.orbA.body) || 
          !world.bodies.contains(merge.orbB.body)) {
        continue;
      }
      
      try {
        final midX = (merge.orbA.body.position.x + merge.orbB.body.position.x) / 2;
        final midY = (merge.orbA.body.position.y + merge.orbB.body.position.y) / 2;
        final nextLevel = merge.orbA.level + 1;
        
        // Remove old orbs
        orbs.remove(merge.orbA);
        orbs.remove(merge.orbB);
        world.destroyBody(merge.orbA.body);
        world.destroyBody(merge.orbB.body);
        
        // Create merged orb
        final newOrb = Orb(
          position: Vector2(midX, midY),
          level: nextLevel,
        );
        newOrb.setWorld(world, Vector2(midX, midY));
        orbs.add(newOrb);
        
        // Trigger merge callback
        onMerge?.call(nextLevel);
        
        // Add score
        onScoreAdd?.call(OrbConfig.levels[nextLevel].score);
        
        // Check for win
        if (nextLevel == OrbConfig.levels.length - 1) {
          onWin?.call();
        }
      } catch (e) {
        // Silently handle any merge errors to prevent crashes
        debugPrint('Merge error (handled): $e');
      }
    }
  }

  void update() {
    world.stepDt(1 / 60.0);
    
    // Process any pending merges after the physics step
    _processPendingMerges();
    
    // Clean up old orbs periodically to prevent memory issues
    _cleanupOldOrbs();
    
    // Check death line
    bool dangerous = false;
    for (final orb in orbs) {
      if (orb.isOldEnough && orb.body.position.y < deathLineY) {
        dangerous = true;
        break;
      }
    }
    
    if (dangerous) {
      deathTimer++;
      if (deathTimer > 120) { // ~2 seconds at 60fps
        onGameOver?.call();
      }
    } else {
      deathTimer = 0;
    }
  }

  void _cleanupOldOrbs() {
    // Remove orbs that are way off screen or moving too fast (likely glitched)
    final orbsToRemove = <Orb>[];
    
    for (final orb in orbs) {
      // Check if orb is way below screen (fell through)
      if (orb.body.position.y > worldHeight + 2) {
        orbsToRemove.add(orb);
        continue;
      }
      
      // Check if orb is moving too fast (physics glitch)
      final velocity = orb.body.linearVelocity;
      if (velocity.length > 100) {
        orbsToRemove.add(orb);
        continue;
      }
      
      // Check if orb is way off to the sides
      if (orb.body.position.x < -2 || orb.body.position.x > worldWidth + 2) {
        orbsToRemove.add(orb);
        continue;
      }
    }
    
    // Remove glitched orbs
    for (final orb in orbsToRemove) {
      try {
        orbs.remove(orb);
        world.destroyBody(orb.body);
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
  }

  void reset() {
    for (final orb in orbs) {
      world.destroyBody(orb.body);
    }
    orbs.clear();
    deathTimer = 0;
    isSpawning = false;
  }

  bool get showDeathLine => deathTimer > 0;
}

class _ContactListener extends ContactListener {
  final PhysicsWorld physicsWorld;

  _ContactListener(this.physicsWorld);

  @override
  void beginContact(Contact contact) {
    final bodyA = contact.fixtureA.body;
    final bodyB = contact.fixtureB.body;
    
    final userDataA = bodyA.userData;
    final userDataB = bodyB.userData;
    
    if (userDataA is Orb && userDataB is Orb) {
      physicsWorld.handleMerge(userDataA, userDataB);
    }
  }
}

class _MergeRequest {
  final Orb orbA;
  final Orb orbB;
  
  _MergeRequest(this.orbA, this.orbB);
}