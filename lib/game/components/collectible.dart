import 'dart:async';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';

/// Collectible energy orb component for the cyber platformer game
/// Handles pickup detection, scoring, and visual effects
class Collectible extends SpriteComponent with HasGameRef, CollisionCallbacks {
  /// Score value awarded when collected
  final int scoreValue;
  
  /// Whether this collectible has been collected
  bool _isCollected = false;
  
  /// Original Y position for floating animation
  late double _originalY;
  
  /// Floating animation offset
  double _floatOffset = 0.0;
  
  /// Rotation angle for spinning animation
  double _rotationAngle = 0.0;
  
  /// Animation timer
  late Timer _animationTimer;
  
  /// Sound effect file path
  static const String _collectSoundPath = 'sfx/energy_orb_collect.wav';

  Collectible({
    required Vector2 position,
    required Vector2 size,
    required Sprite sprite,
    this.scoreValue = 10,
  }) : super(
          position: position,
          size: size,
          sprite: sprite,
        );

  @override
  Future<void> onLoad() async {
    try {
      // Store original position for floating animation
      _originalY = position.y;
      
      // Add collision detection
      add(RectangleHitbox(
        size: size * 0.8, // Slightly smaller hitbox for better gameplay feel
        anchor: Anchor.center,
      ));
      
      // Set anchor to center for proper rotation
      anchor = Anchor.center;
      
      // Start floating and spinning animations
      _startAnimations();
      
      // Preload collect sound effect
      await FlameAudio.audioCache.load(_collectSoundPath);
    } catch (e) {
      // Handle loading errors gracefully
      print('Warning: Could not load collectible resources: $e');
    }
  }

  /// Starts the floating and spinning animations
  void _startAnimations() {
    _animationTimer = Timer.periodic(0.016, (timer) { // ~60 FPS
      if (_isCollected) {
        timer.cancel();
        return;
      }
      
      // Update floating animation
      _floatOffset += 0.05;
      position.y = _originalY + math.sin(_floatOffset) * 5.0;
      
      // Update spinning animation
      _rotationAngle += 0.03;
      angle = _rotationAngle;
    });
  }

  @override
  bool onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    // Check if colliding with player (assuming player has a specific type or tag)
    if (!_isCollected && _isPlayer(other)) {
      _collect();
      return true;
    }
    return false;
  }

  /// Checks if the colliding component is the player
  bool _isPlayer(PositionComponent component) {
    // This would typically check for a Player class or component tag
    // For now, we'll use a simple class name check
    return component.runtimeType.toString().toLowerCase().contains('player');
  }

  /// Handles the collection of this item
  void _collect() async {
    if (_isCollected) return;
    
    _isCollected = true;
    _animationTimer.cancel();
    
    try {
      // Play collection sound effect
      await FlameAudio.play(_collectSoundPath, volume: 0.7);
    } catch (e) {
      print('Warning: Could not play collect sound: $e');
    }
    
    // Add collection visual effect
    _addCollectionEffect();
    
    // Notify game of collection (you would typically use an event system)
    _notifyCollection();
    
    // Remove from game after effect
    Future.delayed(const Duration(milliseconds: 300), () {
      removeFromParent();
    });
  }

  /// Adds visual effects when collected
  void _addCollectionEffect() {
    // Scale up and fade out effect
    add(ScaleEffect.to(
      Vector2.all(1.5),
      EffectController(duration: 0.2),
    ));
    
    add(OpacityEffect.to(
      0.0,
      EffectController(duration: 0.3),
    ));
    
    // Add particle-like effect by creating smaller copies
    for (int i = 0; i < 6; i++) {
      final particle = SpriteComponent(
        sprite: sprite,
        size: size * 0.3,
        position: position.clone(),
        anchor: Anchor.center,
      );
      
      final angle = (i * math.pi * 2) / 6;
      final velocity = Vector2(
        math.cos(angle) * 50,
        math.sin(angle) * 50,
      );
      
      parent?.add(particle);
      
      particle.add(MoveEffect.by(
        velocity,
        EffectController(duration: 0.5),
      ));
      
      particle.add(OpacityEffect.to(
        0.0,
        EffectController(duration: 0.5),
      ));
      
      Future.delayed(const Duration(milliseconds: 500), () {
        particle.removeFromParent();
      });
    }
  }

  /// Notifies the game system of the collection
  void _notifyCollection() {
    // In a real implementation, this would use an event system or callback
    // For example: gameRef.onCollectibleGathered(this);
    print('Collectible collected! Score: $scoreValue');
  }

  @override
  void onRemove() {
    _animationTimer.cancel();
    super.onRemove();
  }

  /// Gets whether this collectible has been collected
  bool get isCollected => _isCollected;
  
  /// Manually trigger collection (useful for testing or special cases)
  void forceCollect() {
    _collect();
  }
}