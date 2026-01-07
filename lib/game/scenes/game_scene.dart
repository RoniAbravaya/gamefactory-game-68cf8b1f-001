import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

/// Main game scene component that manages the platformer gameplay
/// Handles level loading, player spawning, game logic, and UI integration
class GameScene extends Component with HasKeyboardHandlerComponents, HasTapHandlers {
  late Player player;
  late CameraComponent camera;
  late World world;
  late HudComponent hud;
  
  int currentLevel = 1;
  int energyOrbsCollected = 0;
  int energyOrbsRequired = 3;
  double levelTimer = 0.0;
  double maxLevelTime = 90.0;
  bool isGameActive = true;
  bool isPaused = false;
  bool levelCompleted = false;
  
  final List<Platform> platforms = [];
  final List<EnergyOrb> energyOrbs = [];
  final List<LaserTrap> laserTraps = [];
  final List<MovingPlatform> movingPlatforms = [];
  
  Vector2 spawnPoint = Vector2.zero();
  Vector2 exitPortal = Vector2.zero();
  
  final Random _random = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialize world and camera
    world = World();
    camera = CameraComponent.withFixedResolution(
      world: world,
      width: 400,
      height: 800,
    );
    
    add(world);
    add(camera);
    
    // Initialize HUD
    hud = HudComponent();
    camera.viewport.add(hud);
    
    // Load initial level
    await _loadLevel(currentLevel);
    
    // Spawn player
    await _spawnPlayer();
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (!isGameActive || isPaused) return;
    
    // Update level timer
    levelTimer += dt;
    hud.updateTimer(maxLevelTime - levelTimer);
    
    // Check time limit
    if (levelTimer >= maxLevelTime) {
      _handleGameOver('Time\'s up!');
      return;
    }
    
    // Check win condition
    if (energyOrbsCollected >= energyOrbsRequired && _playerAtExit()) {
      _handleLevelComplete();
    }
    
    // Update moving platforms
    for (final platform in movingPlatforms) {
      platform.update(dt);
    }
    
    // Update laser traps
    for (final laser in laserTraps) {
      laser.update(dt);
    }
    
    // Check collisions
    _checkCollisions();
  }

  @override
  bool onTapDown(TapDownEvent event) {
    if (!isGameActive || isPaused) return false;
    
    // Handle tap jump
    player.jump();
    return true;
  }

  /// Loads a specific level with its platforms, obstacles, and collectibles
  Future<void> _loadLevel(int levelNumber) async {
    try {
      // Clear existing level elements
      _clearLevel();
      
      // Reset level state
      energyOrbsCollected = 0;
      levelTimer = 0.0;
      levelCompleted = false;
      isGameActive = true;
      
      // Set level parameters based on difficulty
      _setLevelParameters(levelNumber);
      
      // Generate level layout
      await _generateLevelLayout(levelNumber);
      
      // Update HUD
      hud.updateLevel(levelNumber);
      hud.updateEnergyOrbs(energyOrbsCollected, energyOrbsRequired);
      
    } catch (e) {
      print('Error loading level $levelNumber: $e');
      _handleGameOver('Failed to load level');
    }
  }

  /// Sets level-specific parameters based on difficulty curve
  void _setLevelParameters(int levelNumber) {
    switch (levelNumber) {
      case 1:
        energyOrbsRequired = 3;
        maxLevelTime = double.infinity; // No time pressure
        break;
      case 2:
      case 3:
        energyOrbsRequired = 5;
        maxLevelTime = 90.0;
        break;
      case 4:
      case 5:
        energyOrbsRequired = 8;
        maxLevelTime = 75.0;
        break;
      default:
        energyOrbsRequired = 10 + (levelNumber - 6) * 2;
        maxLevelTime = max(45.0, 90.0 - (levelNumber - 3) * 5);
    }
  }

  /// Generates the level layout with platforms, obstacles, and collectibles
  Future<void> _generateLevelLayout(int levelNumber) async {
    final levelHeight = 800.0;
    final platformCount = 8 + levelNumber * 2;
    
    // Set spawn point at bottom
    spawnPoint = Vector2(200, levelHeight - 50);
    
    // Set exit portal at top
    exitPortal = Vector2(200, 50);
    
    // Generate static platforms
    for (int i = 0; i < platformCount; i++) {
      final y = levelHeight - 100 - (i * (levelHeight - 150) / platformCount);
      final x = 50 + _random.nextDouble() * 300;
      final width = 80 + _random.nextDouble() * 40;
      
      final platform = Platform(Vector2(x, y), Vector2(width, 20));
      platforms.add(platform);
      world.add(platform);
    }
    
    // Generate moving platforms (for levels 3+)
    if (levelNumber >= 3) {
      final movingCount = min(3, levelNumber - 2);
      for (int i = 0; i < movingCount; i++) {
        final y = 200 + i * 150.0;
        final startX = 50.0;
        final endX = 300.0;
        final speed = 50.0 + levelNumber * 10;
        
        final movingPlatform = MovingPlatform(
          Vector2(startX, y),
          Vector2(100, 20),
          startX,
          endX,
          speed,
        );
        movingPlatforms.add(movingPlatform);
        world.add(movingPlatform);
      }
    }
    
    // Generate energy orbs
    for (int i = 0; i < energyOrbsRequired; i++) {
      Vector2 orbPosition;
      do {
        orbPosition = Vector2(
          50 + _random.nextDouble() * 300,
          100 + _random.nextDouble() * 600,
        );
      } while (_isPositionOccupied(orbPosition));
      
      final orb = EnergyOrb(orbPosition);
      energyOrbs.add(orb);
      world.add(orb);
    }
    
    // Generate laser traps (for levels 2+)
    if (levelNumber >= 2) {
      final laserCount = min(5, levelNumber);
      for (int i = 0; i < laserCount; i++) {
        final x = 100 + _random.nextDouble() * 200;
        final y = 150 + i * 120.0;
        final activeDuration = max(1.0, 3.0 - levelNumber * 0.2);
        final inactiveDuration = max(0.5, 2.0 - levelNumber * 0.1);
        
        final laser = LaserTrap(
          Vector2(x, y),
          Vector2(100, 10),
          activeDuration,
          inactiveDuration,
        );
        laserTraps.add(laser);
        world.add(laser);
      }
    }
    
    // Add exit portal
    final portal = ExitPortal(exitPortal);
    world.add(portal);
  }

  /// Spawns the player at the designated spawn point
  Future<void> _spawnPlayer() async {
    player = Player(spawnPoint);
    world.add(player);
    
    // Set camera to follow player
    camera.follow(player);
  }

  /// Checks for collisions between game objects
  void _checkCollisions() {
    final playerRect = player.toRect();
    
    // Check energy orb collection
    energyOrbs.removeWhere((orb) {
      if (playerRect.overlaps(orb.toRect())) {
        orb.collect();
        energyOrbsCollected++;
        hud.updateEnergyOrbs(energyOrbsCollected, energyOrbsRequired);
        world.remove(orb);
        return true;
      }
      return false;
    });
    
    // Check laser trap collisions
    for (final laser in laserTraps) {
      if (laser.isActive && playerRect.overlaps(laser.toRect())) {
        _handleGameOver('Hit by laser trap!');
        return;
      }
    }
    
    // Check if player fell off screen
    if (player.position.y > 850) {
      _handleGameOver('Fell off the platform!');
    }
  }

  /// Checks if player is at the exit portal
  bool _playerAtExit() {
    final playerRect = player.toRect();
    final exitRect = Rect.fromCenter(
      center: Offset(exitPortal.x, exitPortal.y),
      width: 60,
      height: 60,
    );
    return playerRect.overlaps(exitRect);
  }

  /// Handles level completion
  void _handleLevelComplete() {
    if (levelCompleted) return;
    
    levelCompleted = true;
    isGameActive = false;
    
    // Award coins based on performance
    final timeBonus = max(0, (maxLevelTime - levelTimer) / 10).round();
    final totalCoins = 15 + timeBonus;
    
    hud.showLevelComplete(currentLevel, totalCoins);
    
    // Analytics event
    _trackEvent('level_complete', {
      'level': currentLevel,
      'time_taken': levelTimer,
      'coins_earned': totalCoins,
    });
  }

  /// Handles game over scenarios
  void _handleGameOver(String reason) {
    if (!isGameActive) return;
    
    isGameActive = false;
    hud.showGameOver(reason);
    
    // Analytics event
    _trackEvent('level_fail', {
      'level': currentLevel,
      'reason': reason,
      'time_survived': levelTimer,
      'orbs_collected': energyOrbsCollected,
    });
  }

  /// Restarts the current level
  Future<void> restartLevel() async {
    await _loadLevel(currentLevel);
    player.reset(spawnPoint);
  }

  /// Advances to the next level
  Future<void> nextLevel() async {
    currentLevel++;
    await _loadLevel(currentLevel);
    player.reset(spawnPoint);
  }

  /// Pauses the game
  void pauseGame() {
    isPaused = true;
    hud.showPauseMenu();
  }

  /// Resumes the game
  void resumeGame() {
    isPaused = false;
    hud.hidePauseMenu();
  }

  /// Clears all level elements
  void _clearLevel() {
    for (final platform in platforms) {
      world.remove(platform);
    }
    platforms.clear();
    
    for (final orb in energyOrbs) {
      world.remove(orb);
    }
    energyOrbs.clear();
    
    for (final laser in laserTraps) {
      world.remove(laser);
    }
    laserTraps.clear();
    
    for (final movingPlatform in movingPlatforms) {
      world.remove(movingPlatform);
    }
    movingPlatforms.clear();
  }

  /// Checks if a position is occupied by existing game objects
  bool _isPositionOccupied(Vector2 position) {
    const checkRadius = 30.0;
    
    for (final platform in platforms) {
      if ((platform.position - position).length < checkRadius) {
        return true;
      }
    }
    
    for (final laser in laserTraps) {
      if ((laser.position - position).length < checkRadius) {
        return true;
      }
    }
    
    return false;
  }

  /// Tracks analytics events
  void _trackEvent(String eventName, Map<String, dynamic> parameters) {
    // Implementation would integrate with analytics service
    print('Analytics: $eventName - $parameters');
  }
}

/// HUD component for displaying game UI
class HudComponent extends Component {
  late TextComponent levelText;
  late TextComponent orbText;
  late TextComponent timerText;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    levelText = TextComponent(
      text: 'Level 1',
      position: Vector2(20, 20),
    );
    add(levelText);
    
    orbText = TextComponent(
      text: 'Orbs: 0/3',
      position: Vector2(20, 50),
    );
    add(orbText);
    
    timerText = TextComponent(
      text: 'Time: ∞',
      position: Vector2(20, 80),
    );
    add(timerText);
  }
  
  void updateLevel(int level) {
    levelText.text = 'Level $level';
  }
  
  void updateEnergyOrbs(int collected, int required) {
    orbText.text = 'Orbs: $collected/$required';
  }
  
  void updateTimer(double timeRemaining) {
    if (timeRemaining == double.infinity) {
      timerText.text = 'Time: ∞';
    } else {
      timerText.text = 'Time: ${timeRemaining.toInt()}s';
    }
  }
  
  void showLevelComplete(int level, int coins) {
    // Implementation for level complete UI
  }
  
  void showGameOver(String reason) {
    // Implementation for game over UI
  }
  
  void showPauseMenu() {
    // Implementation for pause menu
  }
  
  void hidePauseMenu() {
    // Implementation to hide pause menu
  }
}

/// Placeholder classes for game objects
class Player extends RectangleComponent {
  Player(Vector2 position) : super(position: position, size: Vector2(30, 40));
  
  void jump() {
    // Implementation for jump mechanics
  }
  
  void reset(Vector2 newPosition) {
    position = newPosition.clone();
  }
}

class Platform extends RectangleComponent {
  Platform(Vector2 position, Vector2 size) : super(position: position, size: size);
}

class MovingPlatform extends RectangleComponent {
  final double startX;
  final double endX;
  final double speed;
  bool movingRight = true;
  
  MovingPlatform(Vector2 position, Vector2 size, this.startX, this.endX, this.speed)
      : super(position: position, size: size);
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (movingRight) {
      position.x += speed * dt;
      if (position.x >= endX) {
        movingRight = false;
      }
    } else {
      position.x -= speed * dt;
      if (position.x <= startX) {
        movingRight = true;
      }
    }
  }
}

class EnergyOrb extends CircleComponent {
  EnergyOrb(Vector2 position