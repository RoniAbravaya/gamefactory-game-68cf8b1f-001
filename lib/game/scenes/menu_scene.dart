import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Main menu scene for the neon-lit cyber platformer game
class MenuScene extends Component with HasKeyboardHandlerComponents, HasTappableComponents {
  late TextComponent titleText;
  late RectangleComponent playButton;
  late TextComponent playButtonText;
  late RectangleComponent levelSelectButton;
  late TextComponent levelSelectButtonText;
  late RectangleComponent settingsButton;
  late TextComponent settingsButtonText;
  late List<CircleComponent> backgroundParticles;
  late Timer animationTimer;
  
  static const Color neonCyan = Color(0xFF00FFFF);
  static const Color neonMagenta = Color(0xFFFF00FF);
  static const Color neonYellow = Color(0xFFFFFF00);
  static const Color darkBlue = Color(0xFF1A1A2E);
  static const Color mediumBlue = Color(0xFF16213E);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    final gameSize = gameRef.size;
    
    // Initialize background particles
    _createBackgroundParticles();
    
    // Create title
    titleText = TextComponent(
      text: 'CYBER TOWER',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: neonCyan,
          shadows: [
            Shadow(
              color: neonCyan,
              blurRadius: 10,
            ),
          ],
        ),
      ),
      position: Vector2(gameSize.x / 2, gameSize.y * 0.2),
      anchor: Anchor.center,
    );
    add(titleText);
    
    // Add pulsing effect to title
    titleText.add(
      ScaleEffect.by(
        Vector2.all(1.1),
        EffectController(
          duration: 2.0,
          alternate: true,
          infinite: true,
        ),
      ),
    );
    
    // Create play button
    playButton = RectangleComponent(
      size: Vector2(200, 60),
      position: Vector2(gameSize.x / 2, gameSize.y * 0.45),
      anchor: Anchor.center,
      paint: Paint()
        ..color = darkBlue
        ..style = PaintingStyle.fill,
    );
    
    // Add glowing border to play button
    playButton.add(
      RectangleComponent(
        size: Vector2(204, 64),
        position: Vector2(-2, -2),
        paint: Paint()
          ..color = neonMagenta
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      ),
    );
    
    add(playButton);
    
    playButtonText = TextComponent(
      text: 'PLAY',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: neonMagenta,
        ),
      ),
      position: Vector2(100, 30),
      anchor: Anchor.center,
    );
    playButton.add(playButtonText);
    
    // Create level select button
    levelSelectButton = RectangleComponent(
      size: Vector2(200, 60),
      position: Vector2(gameSize.x / 2, gameSize.y * 0.6),
      anchor: Anchor.center,
      paint: Paint()
        ..color = darkBlue
        ..style = PaintingStyle.fill,
    );
    
    levelSelectButton.add(
      RectangleComponent(
        size: Vector2(204, 64),
        position: Vector2(-2, -2),
        paint: Paint()
          ..color = neonYellow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      ),
    );
    
    add(levelSelectButton);
    
    levelSelectButtonText = TextComponent(
      text: 'LEVELS',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: neonYellow,
        ),
      ),
      position: Vector2(100, 30),
      anchor: Anchor.center,
    );
    levelSelectButton.add(levelSelectButtonText);
    
    // Create settings button
    settingsButton = RectangleComponent(
      size: Vector2(200, 60),
      position: Vector2(gameSize.x / 2, gameSize.y * 0.75),
      anchor: Anchor.center,
      paint: Paint()
        ..color = darkBlue
        ..style = PaintingStyle.fill,
    );
    
    settingsButton.add(
      RectangleComponent(
        size: Vector2(204, 64),
        position: Vector2(-2, -2),
        paint: Paint()
          ..color = neonCyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      ),
    );
    
    add(settingsButton);
    
    settingsButtonText = TextComponent(
      text: 'SETTINGS',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: neonCyan,
        ),
      ),
      position: Vector2(100, 30),
      anchor: Anchor.center,
    );
    settingsButton.add(settingsButtonText);
    
    // Start background animation
    _startBackgroundAnimation();
  }
  
  /// Creates animated background particles for cyberpunk atmosphere
  void _createBackgroundParticles() {
    backgroundParticles = [];
    final gameSize = gameRef.size;
    final random = math.Random();
    
    for (int i = 0; i < 20; i++) {
      final particle = CircleComponent(
        radius: random.nextDouble() * 3 + 1,
        position: Vector2(
          random.nextDouble() * gameSize.x,
          random.nextDouble() * gameSize.y,
        ),
        paint: Paint()
          ..color = [neonCyan, neonMagenta, neonYellow][random.nextInt(3)]
              .withOpacity(0.3),
      );
      
      // Add floating animation
      particle.add(
        MoveEffect.by(
          Vector2(0, -gameSize.y - 100),
          EffectController(
            duration: random.nextDouble() * 10 + 5,
            infinite: true,
          ),
        ),
      );
      
      backgroundParticles.add(particle);
      add(particle);
    }
  }
  
  /// Starts the background animation timer
  void _startBackgroundAnimation() {
    animationTimer = Timer(
      0.1,
      repeat: true,
      onTick: () {
        _updateBackgroundParticles();
      },
    );
    add(TimerComponent(timer: animationTimer));
  }
  
  /// Updates background particle positions and effects
  void _updateBackgroundParticles() {
    final gameSize = gameRef.size;
    final random = math.Random();
    
    for (final particle in backgroundParticles) {
      if (particle.position.y < -10) {
        particle.position = Vector2(
          random.nextDouble() * gameSize.x,
          gameSize.y + 10,
        );
      }
    }
  }
  
  @override
  bool onTapDown(TapDownEvent event) {
    final tapPosition = event.localPosition;
    
    try {
      // Check play button tap
      if (_isPointInButton(tapPosition, playButton)) {
        _onPlayButtonPressed();
        return true;
      }
      
      // Check level select button tap
      if (_isPointInButton(tapPosition, levelSelectButton)) {
        _onLevelSelectButtonPressed();
        return true;
      }
      
      // Check settings button tap
      if (_isPointInButton(tapPosition, settingsButton)) {
        _onSettingsButtonPressed();
        return true;
      }
    } catch (e) {
      // Handle tap errors gracefully
      print('Error handling tap: $e');
    }
    
    return false;
  }
  
  /// Checks if a point is within a button's bounds
  bool _isPointInButton(Vector2 point, RectangleComponent button) {
    final buttonBounds = button.toRect();
    return buttonBounds.contains(point.toOffset());
  }
  
  /// Handles play button press
  void _onPlayButtonPressed() {
    // Add button press effect
    playButton.add(
      ScaleEffect.by(
        Vector2.all(0.9),
        EffectController(duration: 0.1, alternate: true),
      ),
    );
    
    // Navigate to game scene
    // This would typically trigger a scene change in the game
    print('Play button pressed - Starting game');
  }
  
  /// Handles level select button press
  void _onLevelSelectButtonPressed() {
    levelSelectButton.add(
      ScaleEffect.by(
        Vector2.all(0.9),
        EffectController(duration: 0.1, alternate: true),
      ),
    );
    
    // Navigate to level select scene
    print('Level select button pressed - Opening level selection');
  }
  
  /// Handles settings button press
  void _onSettingsButtonPressed() {
    settingsButton.add(
      ScaleEffect.by(
        Vector2.all(0.9),
        EffectController(duration: 0.1, alternate: true),
      ),
    );
    
    // Navigate to settings scene
    print('Settings button pressed - Opening settings');
  }
  
  @override
  void onRemove() {
    animationTimer.stop();
    super.onRemove();
  }
}