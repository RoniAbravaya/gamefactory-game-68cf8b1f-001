import 'dart:async';
import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/services.dart';

/// Player component for the neon-lit cyber platformer game
/// Handles movement, jumping, animations, and collision detection
class Player extends SpriteAnimationComponent
    with HasKeyboardHandlerComponents, CollisionCallbacks, HasGameRef {
  
  /// Player movement speed in pixels per second
  static const double _moveSpeed = 200.0;
  
  /// Jump velocity in pixels per second (negative for upward movement)
  static const double _jumpVelocity = -400.0;
  
  /// Gravity acceleration in pixels per second squared
  static const double _gravity = 980.0;
  
  /// Maximum fall speed to prevent infinite acceleration
  static const double _maxFallSpeed = 500.0;
  
  /// Duration of invulnerability frames after taking damage
  static const double _invulnerabilityDuration = 2.0;
  
  /// Player's current velocity
  Vector2 velocity = Vector2.zero();
  
  /// Whether the player is currently on the ground
  bool isOnGround = false;
  
  /// Whether the player can jump (prevents infinite jumping)
  bool canJump = true;
  
  /// Player's current health points
  int health = 3;
  
  /// Maximum health points
  int maxHealth = 3;
  
  /// Whether the player is currently invulnerable
  bool isInvulnerable = false;
  
  /// Timer for invulnerability frames
  Timer? _invulnerabilityTimer;
  
  /// Current animation state
  PlayerAnimationState _currentState = PlayerAnimationState.idle;
  
  /// Animation components for different states
  late SpriteAnimation _idleAnimation;
  late SpriteAnimation _runAnimation;
  late SpriteAnimation _jumpAnimation;
  late SpriteAnimation _fallAnimation;
  late SpriteAnimation _hurtAnimation;
  
  /// Particle effect for energy trail
  late Component _energyTrail;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Set up collision detection
    add(RectangleHitbox());
    
    // Load animations
    await _loadAnimations();
    
    // Set initial animation
    animation = _idleAnimation;
    
    // Initialize energy trail effect
    _initializeEnergyTrail();
    
    // Set player size
    size = Vector2(32, 48);
  }
  
  /// Loads all player animations from sprite sheets
  Future<void> _loadAnimations() async {
    try {
      final spriteSheet = await gameRef.images.load('player_spritesheet.png');
      
      _idleAnimation = SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.2,
          textureSize: Vector2(32, 48),
        ),
      );
      
      _runAnimation = SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 6,
          stepTime: 0.1,
          textureSize: Vector2(32, 48),
          texturePosition: Vector2(0, 48),
        ),
      );
      
      _jumpAnimation = SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 3,
          stepTime: 0.15,
          textureSize: Vector2(32, 48),
          texturePosition: Vector2(0, 96),
          loop: false,
        ),
      );
      
      _fallAnimation = SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 2,
          stepTime: 0.2,
          textureSize: Vector2(32, 48),
          texturePosition: Vector2(0, 144),
        ),
      );
      
      _hurtAnimation = SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 3,
          stepTime: 0.1,
          textureSize: Vector2(32, 48),
          texturePosition: Vector2(0, 192),
          loop: false,
        ),
      );
    } catch (e) {
      // Fallback to colored rectangles if sprites fail to load
      print('Failed to load player animations: $e');
    }
  }
  
  /// Initializes the energy trail particle effect
  void _initializeEnergyTrail() {
    // TODO: Implement particle system for neon trail effect
    // This would create glowing particles that follow the player
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Handle input
    _handleInput();
    
    // Apply physics
    _updatePhysics(dt);
    
    // Update animations
    _updateAnimations();
    
    // Handle invulnerability timer
    _updateInvulnerability(dt);
    
    // Constrain player to screen bounds
    _constrainToScreen();
  }
  
  /// Handles player input for movement and jumping
  void _handleInput() {
    // Reset horizontal velocity
    velocity.x = 0;
    
    // Handle keyboard input (for testing)
    if (gameRef.hasKeyboardHandlerComponents) {
      // Left/Right movement would be handled here if needed
      // For tap-to-jump game, horizontal movement might be automatic
    }
  }
  
  /// Updates player physics including gravity and collision
  void _updatePhysics(double dt) {
    // Apply gravity
    if (!isOnGround) {
      velocity.y += _gravity * dt;
      velocity.y = min(velocity.y, _maxFallSpeed);
    }
    
    // Update position based on velocity
    position += velocity * dt;
    
    // Reset ground state (will be set by collision detection)
    isOnGround = false;
    canJump = isOnGround;
  }
  
  /// Updates player animations based on current state
  void _updateAnimations() {
    PlayerAnimationState newState;
    
    if (isInvulnerable && _currentState != PlayerAnimationState.hurt) {
      newState = PlayerAnimationState.hurt;
    } else if (velocity.y < -50) {
      newState = PlayerAnimationState.jumping;
    } else if (velocity.y > 50) {
      newState = PlayerAnimationState.falling;
    } else if (velocity.x.abs() > 10) {
      newState = PlayerAnimationState.running;
    } else {
      newState = PlayerAnimationState.idle;
    }
    
    if (newState != _currentState) {
      _currentState = newState;
      _setAnimation(newState);
    }
    
    // Handle invulnerability visual effect
    if (isInvulnerable) {
      // Flicker effect during invulnerability
      final flickerTime = (_invulnerabilityTimer?.current ?? 0) * 10;
      opacity = (sin(flickerTime) + 1) * 0.5;
    } else {
      opacity = 1.0;
    }
  }
  
  /// Sets the current animation based on state
  void _setAnimation(PlayerAnimationState state) {
    switch (state) {
      case PlayerAnimationState.idle:
        animation = _idleAnimation;
        break;
      case PlayerAnimationState.running:
        animation = _runAnimation;
        break;
      case PlayerAnimationState.jumping:
        animation = _jumpAnimation;
        break;
      case PlayerAnimationState.falling:
        animation = _fallAnimation;
        break;
      case PlayerAnimationState.hurt:
        animation = _hurtAnimation;
        break;
    }
  }
  
  /// Updates invulnerability timer
  void _updateInvulnerability(double dt) {
    _invulnerabilityTimer?.update(dt);
  }
  
  /// Constrains player position to screen boundaries
  void _constrainToScreen() {
    final screenSize = gameRef.size;
    
    // Keep player within horizontal bounds
    position.x = position.x.clamp(0, screenSize.x - size.x);
    
    // Handle falling off bottom of screen
    if (position.y > screenSize.y) {
      _handleFallDeath();
    }
  }
  
  /// Makes the player jump if possible
  void jump() {
    if (canJump && isOnGround) {
      velocity.y = _jumpVelocity;
      isOnGround = false;
      canJump = false;
      
      // Play jump sound effect
      // TODO: Add audio component
    }
  }
  
  /// Handles collision with other components
  @override
  bool onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Platform) {
      _handlePlatformCollision(other, intersectionPoints);
    } else if (other is EnergyOrb) {
      _handleEnergyOrbCollection(other);
    } else if (other is LaserTrap) {
      _handleLaserTrapCollision(other);
    } else if (other is MovingPlatform) {
      _handleMovingPlatformCollision(other, intersectionPoints);
    }
    
    return true;
  }
  
  /// Handles collision with static platforms
  void _handlePlatformCollision(Platform platform, Set<Vector2> intersectionPoints) {
    // Only land on platform if falling and hitting from above
    if (velocity.y > 0 && position.y < platform.position.y) {
      position.y = platform.position.y - size.y;
      velocity.y = 0;
      isOnGround = true;
      canJump = true;
    }
  }
  
  /// Handles collision with moving platforms
  void _handleMovingPlatformCollision(MovingPlatform platform, Set<Vector2> intersectionPoints) {
    if (velocity.y > 0 && position.y < platform.position.y) {
      position.y = platform.position.y - size.y;
      velocity.y = 0;
      isOnGround = true;
      canJump = true;
      
      // Move with the platform
      velocity.x += platform.velocity.x;
    }
  }
  
  /// Handles collection of energy orbs
  void _handleEnergyOrbCollection(EnergyOrb orb) {
    orb.collect();
    // TODO: Add to score/currency system
    // TODO: Play collection sound effect
  }
  
  /// Handles collision with laser traps
  void _handleLaserTrapCollision(LaserTrap trap) {
    if (!isInvulnerable && trap.isActive) {
      takeDamage(1);
    }
  }
  
  /// Applies damage to the player
  void takeDamage(int damage) {
    if (isInvulnerable) return;
    
    health -= damage;
    health = max(0, health);
    
    // Start invulnerability frames
    _startInvulnerability();
    
    // Check for death
    if (health <= 0) {
      _handleDeath();
    }
    
    // TODO: Play hurt sound effect
  }
  
  /// Starts invulnerability period after taking damage
  void _startInvulnerability() {
    isInvulnerable = true;
    _invulnerabilityTimer?.stop();
    _invulnerabilityTimer = Timer(
      _invulnerabilityDuration,
      onTick: () {
        isInvulnerable = false;
        opacity = 1.0;
      },
    );
    _invulnerabilityTimer!.start();
  }
  
  /// Handles player death
  void _handleDeath() {
    // TODO: Trigger death animation
    // TODO: Show game over screen
    // TODO: Reset level
    print('Player died!');
  }
  
  /// Handles falling off the bottom of the screen
  void _handleFallDeath() {
    takeDamage(maxHealth); // Instant death
  }
  
  /// Heals the player by specified amount
  void heal(int amount) {
    health += amount;
    health = min(health, maxHealth);
  }
  
  /// Resets player to initial state
  void reset() {
    health = maxHealth;
    velocity = Vector2.zero();
    isOnGround = false;
    canJump = true;
    isInvulnerable = false;
    _invulnerabilityTimer?.stop();
    _invulnerabilityTimer = null;
    opacity = 1.0;
    _currentState = PlayerAnimationState.idle;
    animation = _idleAnimation;
  }
}

/// Enumeration of player animation states
enum PlayerAnimationState {
  idle,
  running,
  jumping,
  falling,
  hurt,
}

/// Platform component for collision detection
class Platform extends RectangleComponent with CollisionCallbacks {
  Platform({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);
}

/// Moving platform component
class MovingPlatform extends Platform {
  Vector2 velocity = Vector2.zero();
  
  MovingPlatform({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);
}

/// Energy orb collectible component
class EnergyOrb extends CircleComponent with CollisionCallbacks {
  bool isCollected = false;
  
  EnergyOrb({required Vector2 position, required double radius})
      : super(position: position, radius: radius);
  
  void collect() {
    if (!isCollected) {
      isCollected = true;
      removeFromParent();
    }
  }
}

/// Laser trap obstacle component
class LaserTrap extends RectangleComponent with CollisionCallbacks {
  bool isActive = true;
  
  LaserTrap({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);
}