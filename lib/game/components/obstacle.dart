import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Obstacle component for the neon-cyberpunk platformer game
/// Represents laser traps and other hazardous elements that damage the player
class Obstacle extends PositionComponent with HasGameRef, CollisionCallbacks {
  /// Type of obstacle (laser_horizontal, laser_vertical, spike_trap, energy_barrier)
  final String obstacleType;
  
  /// Movement speed for moving obstacles
  final double moveSpeed;
  
  /// Whether this obstacle moves back and forth
  final bool isMoving;
  
  /// Movement range for moving obstacles
  final double movementRange;
  
  /// Damage dealt to player on collision
  final int damage;
  
  /// Visual sprite component
  late SpriteComponent _sprite;
  
  /// Particle effect for neon glow
  late ParticleSystemComponent _glowEffect;
  
  /// Movement direction for moving obstacles
  Vector2 _moveDirection = Vector2.zero();
  
  /// Starting position for movement calculations
  late Vector2 _startPosition;
  
  /// Whether obstacle is currently active/dangerous
  bool isActive = true;
  
  /// Animation timer for pulsing effects
  double _animationTimer = 0.0;

  Obstacle({
    required this.obstacleType,
    required Vector2 position,
    required Vector2 size,
    this.moveSpeed = 50.0,
    this.isMoving = false,
    this.movementRange = 100.0,
    this.damage = 1,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    _startPosition = position.clone();
    
    // Setup collision hitbox
    add(RectangleHitbox(
      size: size,
      anchor: Anchor.center,
    ));
    
    // Initialize sprite based on obstacle type
    await _initializeSprite();
    
    // Setup movement direction for moving obstacles
    if (isMoving) {
      _setupMovement();
    }
    
    // Add neon glow particle effect
    _addGlowEffect();
    
    // Add pulsing animation effect
    _addPulsingEffect();
  }

  /// Initialize sprite based on obstacle type
  Future<void> _initializeSprite() async {
    try {
      String spritePath = _getSpritePathForType();
      final sprite = await gameRef.loadSprite(spritePath);
      
      _sprite = SpriteComponent(
        sprite: sprite,
        size: size,
        anchor: Anchor.center,
      );
      
      add(_sprite);
    } catch (e) {
      // Fallback to colored rectangle if sprite loading fails
      _createFallbackVisual();
    }
  }

  /// Get sprite path based on obstacle type
  String _getSpritePathForType() {
    switch (obstacleType) {
      case 'laser_horizontal':
        return 'obstacles/laser_horizontal.png';
      case 'laser_vertical':
        return 'obstacles/laser_vertical.png';
      case 'spike_trap':
        return 'obstacles/spike_trap.png';
      case 'energy_barrier':
        return 'obstacles/energy_barrier.png';
      default:
        return 'obstacles/default_obstacle.png';
    }
  }

  /// Create fallback visual representation
  void _createFallbackVisual() {
    final rect = RectangleComponent(
      size: size,
      paint: Paint()..color = _getColorForType(),
      anchor: Anchor.center,
    );
    add(rect);
  }

  /// Get color based on obstacle type following neon cyberpunk theme
  Color _getColorForType() {
    switch (obstacleType) {
      case 'laser_horizontal':
      case 'laser_vertical':
        return const Color(0xFF00FFFF); // Cyan
      case 'spike_trap':
        return const Color(0xFFFF00FF); // Magenta
      case 'energy_barrier':
        return const Color(0xFFFFFF00); // Yellow
      default:
        return const Color(0xFF00FFFF); // Default cyan
    }
  }

  /// Setup movement pattern for moving obstacles
  void _setupMovement() {
    switch (obstacleType) {
      case 'laser_horizontal':
        _moveDirection = Vector2(1, 0);
        break;
      case 'laser_vertical':
        _moveDirection = Vector2(0, 1);
        break;
      case 'energy_barrier':
        _moveDirection = Vector2(
          math.cos(_animationTimer) * 0.5,
          math.sin(_animationTimer) * 0.5,
        );
        break;
      default:
        _moveDirection = Vector2(1, 0);
    }
  }

  /// Add neon glow particle effect
  void _addGlowEffect() {
    final glowParticles = ParticleSystemComponent(
      particle: Particle.generate(
        count: 20,
        lifespan: 2.0,
        generator: (i) => AcceleratedParticle(
          acceleration: Vector2.zero(),
          speed: Vector2.random() * 10,
          position: Vector2.random() * size,
          child: CircleParticle(
            radius: math.Random().nextDouble() * 2 + 1,
            paint: Paint()
              ..color = _getColorForType().withOpacity(0.6)
              ..blendMode = BlendMode.plus,
          ),
        ),
      ),
    );
    
    add(glowParticles);
    _glowEffect = glowParticles;
  }

  /// Add pulsing animation effect
  void _addPulsingEffect() {
    final pulseEffect = ScaleEffect.by(
      Vector2.all(1.1),
      EffectController(
        duration: 1.0,
        alternate: true,
        infinite: true,
      ),
    );
    
    add(pulseEffect);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    _animationTimer += dt;
    
    // Update movement for moving obstacles
    if (isMoving && isActive) {
      _updateMovement(dt);
    }
    
    // Update glow effect intensity based on activity
    _updateGlowEffect(dt);
  }

  /// Update obstacle movement
  void _updateMovement(double dt) {
    final movement = _moveDirection * moveSpeed * dt;
    position.add(movement);
    
    // Check movement bounds and reverse direction if needed
    final distanceFromStart = position.distanceTo(_startPosition);
    if (distanceFromStart >= movementRange) {
      _moveDirection.negate();
      
      // Clamp position to movement range
      final directionToStart = (_startPosition - position)..normalize();
      position = _startPosition + (directionToStart * -movementRange);
    }
  }

  /// Update glow effect based on obstacle state
  void _updateGlowEffect(double dt) {
    if (_glowEffect.isMounted) {
      final intensity = isActive ? 1.0 : 0.3;
      final pulseIntensity = (math.sin(_animationTimer * 3) + 1) * 0.5;
      _glowEffect.scale = Vector2.all(intensity * (0.8 + pulseIntensity * 0.4));
    }
  }

  @override
  bool onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    // Handle collision with player
    if (other.runtimeType.toString().contains('Player') && isActive) {
      _handlePlayerCollision(other);
      return true;
    }
    
    return false;
  }

  /// Handle collision with player component
  void _handlePlayerCollision(PositionComponent player) {
    try {
      // Deal damage to player
      if (player is HasGameRef) {
        // Trigger damage event
        gameRef.overlays.add('damage_indicator');
        
        // Add screen shake effect
        _addScreenShakeEffect();
        
        // Add collision particle effect
        _addCollisionEffect();
        
        // Temporarily deactivate obstacle to prevent multiple hits
        _temporaryDeactivate();
      }
    } catch (e) {
      // Handle collision error gracefully
      print('Error handling player collision: $e');
    }
  }

  /// Add screen shake effect on collision
  void _addScreenShakeEffect() {
    final shakeEffect = MoveEffect.by(
      Vector2(5, 0),
      EffectController(
        duration: 0.1,
        alternate: true,
        repeatCount: 3,
      ),
    );
    
    if (gameRef.camera.viewport.isMounted) {
      gameRef.camera.viewport.add(shakeEffect);
    }
  }

  /// Add collision particle effect
  void _addCollisionEffect() {
    final collisionParticles = ParticleSystemComponent(
      particle: Particle.generate(
        count: 15,
        lifespan: 0.5,
        generator: (i) => AcceleratedParticle(
          acceleration: Vector2(0, 200),
          speed: Vector2.random() * 100,
          position: position.clone(),
          child: CircleParticle(
            radius: math.Random().nextDouble() * 3 + 2,
            paint: Paint()
              ..color = Colors.white.withOpacity(0.8)
              ..blendMode = BlendMode.plus,
          ),
        ),
      ),
    );
    
    parent?.add(collisionParticles);
  }

  /// Temporarily deactivate obstacle after collision
  void _temporaryDeactivate() {
    isActive = false;
    
    // Reactivate after short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (isMounted) {
        isActive = true;
      }
    });
  }

  /// Activate the obstacle
  void activate() {
    isActive = true;
    opacity = 1.0;
  }

  /// Deactivate the obstacle
  void deactivate() {
    isActive = false;
    opacity = 0.3;
  }

  /// Get obstacle damage value
  int getDamage() => damage;

  /// Check if obstacle is currently dangerous
  bool isDangerous() => isActive;

  @override
  void onRemove() {
    // Clean up resources
    _glowEffect.removeFromParent();
    super.onRemove();
  }
}