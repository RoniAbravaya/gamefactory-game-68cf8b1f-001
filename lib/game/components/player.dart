import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'dart:math' as math;

/// Player component for the neon-lit cyber tower platformer game.
/// Handles jumping mechanics, animations, collision detection, and score tracking.
class Player extends SpriteAnimationComponent
    with HasKeyboardHandlerComponents, HasCollisionDetection, CollisionCallbacks {
  
  /// Current vertical velocity for jump physics
  double _velocityY = 0.0;
  
  /// Horizontal velocity for movement
  double _velocityX = 0.0;
  
  /// Gravity constant for realistic jumping
  static const double _gravity = 980.0;
  
  /// Jump force applied when tapping
  static const double _jumpForce = -400.0;
  
  /// Maximum horizontal movement speed
  static const double _maxSpeed = 150.0;
  
  /// Whether the player is currently on the ground
  bool _isOnGround = false;
  
  /// Whether the player is currently jumping
  bool _isJumping = false;
  
  /// Current player health/lives
  int _health = 3;
  
  /// Maximum health
  static const int _maxHealth = 3;
  
  /// Current score
  int _score = 0;
  
  /// Energy orbs collected in current level
  int _energyOrbs = 0;
  
  /// Whether the player is invulnerable (after taking damage)
  bool _isInvulnerable = false;
  
  /// Invulnerability timer
  double _invulnerabilityTimer = 0.0;
  
  /// Invulnerability duration in seconds
  static const double _invulnerabilityDuration = 2.0;
  
  /// Animation states
  late SpriteAnimation _idleAnimation;
  late SpriteAnimation _jumpAnimation;
  late SpriteAnimation _fallAnimation;
  
  /// Current animation state
  PlayerAnimationState _currentState = PlayerAnimationState.idle;
  
  /// Reference to the game for callbacks
  late FlameGame gameRef;
  
  /// Particle trail effect timer
  double _trailTimer = 0.0;
  static const double _trailInterval = 0.1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Set up collision detection
    add(RectangleHitbox());
    
    // Load animations
    await _loadAnimations();
    
    // Set initial size and position
    size = Vector2(32, 48);
    anchor = Anchor.center;
    
    // Set initial animation
    animation = _idleAnimation;
    _currentState = PlayerAnimationState.idle;
  }

  /// Loads all player animations
  Future<void> _loadAnimations() async {
    // Load sprite sheets for different animation states
    _idleAnimation = await gameRef.loadSpriteAnimation(
      'player_idle.png',
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.2,
        textureSize: Vector2(32, 48),
      ),
    );
    
    _jumpAnimation = await gameRef.loadSpriteAnimation(
      'player_jump.png',
      SpriteAnimationData.sequenced(
        amount: 3,
        stepTime: 0.1,
        textureSize: Vector2(32, 48),
      ),
    );
    
    _fallAnimation = await gameRef.loadSpriteAnimation(
      'player_fall.png',
      SpriteAnimationData.sequenced(
        amount: 2,
        stepTime: 0.15,
        textureSize: Vector2(32, 48),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update physics
    _updatePhysics(dt);
    
    // Update animation state
    _updateAnimationState();
    
    // Update invulnerability
    _updateInvulnerability(dt);
    
    // Update particle trail
    _updateTrailEffect(dt);
    
    // Check boundaries
    _checkBoundaries();
  }

  /// Updates player physics including gravity and movement
  void _updatePhysics(double dt) {
    // Apply gravity
    if (!_isOnGround) {
      _velocityY += _gravity * dt;
    }
    
    // Update position
    position.x += _velocityX * dt;
    position.y += _velocityY * dt;
    
    // Apply friction to horizontal movement
    _velocityX *= 0.95;
    
    // Reset ground state (will be set by collision detection)
    _isOnGround = false;
  }

  /// Updates animation state based on player movement
  void _updateAnimationState() {
    PlayerAnimationState newState;
    
    if (_velocityY < -50) {
      newState = PlayerAnimationState.jumping;
    } else if (_velocityY > 50) {
      newState = PlayerAnimationState.falling;
    } else {
      newState = PlayerAnimationState.idle;
    }
    
    if (newState != _currentState) {
      _currentState = newState;
      switch (_currentState) {
        case PlayerAnimationState.idle:
          animation = _idleAnimation;
          break;
        case PlayerAnimationState.jumping:
          animation = _jumpAnimation;
          break;
        case PlayerAnimationState.falling:
          animation = _fallAnimation;
          break;
      }
    }
  }

  /// Updates invulnerability state
  void _updateInvulnerability(double dt) {
    if (_isInvulnerable) {
      _invulnerabilityTimer -= dt;
      if (_invulnerabilityTimer <= 0) {
        _isInvulnerable = false;
        opacity = 1.0;
      } else {
        // Flashing effect during invulnerability
        opacity = (math.sin(_invulnerabilityTimer * 20) + 1) * 0.5;
      }
    }
  }

  /// Updates particle trail effect
  void _updateTrailEffect(double dt) {
    _trailTimer += dt;
    if (_trailTimer >= _trailInterval) {
      _trailTimer = 0.0;
      _createTrailParticle();
    }
  }

  /// Creates a particle for the trail effect
  void _createTrailParticle() {
    // Implementation would create a particle component at current position
    // This is a placeholder for the actual particle system integration
  }

  /// Checks if player is within game boundaries
  void _checkBoundaries() {
    // Keep player within screen bounds horizontally
    if (position.x < size.x / 2) {
      position.x = size.x / 2;
      _velocityX = 0;
    } else if (position.x > gameRef.size.x - size.x / 2) {
      position.x = gameRef.size.x - size.x / 2;
      _velocityX = 0;
    }
    
    // Check if player fell off the bottom
    if (position.y > gameRef.size.y + 100) {
      _onPlayerFell();
    }
  }

  /// Handles tap input for jumping
  void onTap() {
    if (_isOnGround && !_isJumping) {
      jump();
    }
  }

  /// Makes the player jump
  void jump() {
    if (_isOnGround) {
      _velocityY = _jumpForce;
      _isOnGround = false;
      _isJumping = true;
      
      // Play jump sound effect
      _playJumpSound();
    }
  }

  /// Moves the player horizontally
  void moveHorizontal(double direction) {
    _velocityX += direction * _maxSpeed * 0.1;
    _velocityX = _velocityX.clamp(-_maxSpeed, _maxSpeed);
  }

  /// Handles collision with platforms
  void onPlatformCollision(PositionComponent platform) {
    // Land on platform if falling
    if (_velocityY > 0 && position.y < platform.position.y) {
      position.y = platform.position.y - size.y / 2;
      _velocityY = 0;
      _isOnGround = true;
      _isJumping = false;
    }
  }

  /// Handles collision with laser traps
  void onLaserCollision() {
    if (!_isInvulnerable) {
      takeDamage();
    }
  }

  /// Handles collision with energy orbs
  void onEnergyOrbCollision() {
    _energyOrbs++;
    _score += 10;
    
    // Play collection sound
    _playCollectSound();
    
    // Notify game of collection
    _onEnergyOrbCollected();
  }

  /// Handles collision with exit portal
  void onExitPortalCollision() {
    // Check if player has collected enough energy orbs
    if (_energyOrbs >= _getRequiredEnergyOrbs()) {
      _onLevelComplete();
    }
  }

  /// Reduces player health and handles damage
  void takeDamage() {
    if (_isInvulnerable) return;
    
    _health--;
    _isInvulnerable = true;
    _invulnerabilityTimer = _invulnerabilityDuration;
    
    // Play damage sound
    _playDamageSound();
    
    if (_health <= 0) {
      _onPlayerDeath();
    }
  }

  /// Restores player health
  void heal(int amount) {
    _health = math.min(_health + amount, _maxHealth);
  }

  /// Adds to player score
  void addScore(int points) {
    _score += points;
  }

  /// Resets player state for new level
  void resetForNewLevel() {
    _velocityX = 0;
    _velocityY = 0;
    _isOnGround = false;
    _isJumping = false;
    _isInvulnerable = false;
    _invulnerabilityTimer = 0;
    _energyOrbs = 0;
    opacity = 1.0;
    _currentState = PlayerAnimationState.idle;
    animation = _idleAnimation;
  }

  /// Gets the number of energy orbs required for current level
  int _getRequiredEnergyOrbs() {
    // This would be determined by the current level
    // Placeholder implementation
    return 5;
  }

  /// Called when player falls off the level
  void _onPlayerFell() {
    takeDamage();
    // Reset position to last safe position or respawn point
    _respawnPlayer();
  }

  /// Called when player dies
  void _onPlayerDeath() {
    // Notify game of player death
    gameRef.onPlayerDeath();
  }

  /// Called when level is completed
  void _onLevelComplete() {
    // Calculate completion bonus
    int bonus = _energyOrbs * 5;
    addScore(bonus);
    
    // Notify game of level completion
    gameRef.onLevelComplete(_score, _energyOrbs);
  }

  /// Called when energy orb is collected
  void _onEnergyOrbCollected() {
    // Notify game for UI updates
    gameRef.onEnergyOrbCollected(_energyOrbs);
  }

  /// Respawns player at safe position
  void _respawnPlayer() {
    // Reset to spawn point or last safe platform
    position = Vector2(gameRef.size.x / 2, gameRef.size.y - 100);
    _velocityX = 0;
    _velocityY = 0;
  }

  /// Plays jump sound effect
  void _playJumpSound() {
    // Implementation would play jump sound
  }

  /// Plays collection sound effect
  void _playCollectSound() {
    // Implementation would play collection sound
  }

  /// Plays damage sound effect
  void _playDamageSound() {
    // Implementation would play damage sound
  }

  @override
  bool onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    // Handle different collision types
    if (other.hasTag('platform')) {
      onPlatformCollision(other);
    } else if (other.hasTag('laser')) {
      onLaserCollision();
    } else if (other.hasTag('energy_orb')) {
      onEnergyOrbCollision();
    } else if (other.hasTag('exit_portal')) {
      onExitPortalCollision();
    }
    
    return true;
  }

  // Getters for game state
  int get health => _health;
  int get maxHealth => _maxHealth;
  int get score => _score;
  int get energyOrbs => _energyOrbs;
  bool get isOnGround => _isOnGround;
  bool get isInvulnerable => _isInvulnerable;
}

/// Enumeration for player animation states
enum PlayerAnimationState {
  idle,
  jumping,
  falling,
}