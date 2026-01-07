import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/player.dart';
import '../components/platform.dart';
import '../components/energy_orb.dart';
import '../components/laser_trap.dart';
import '../components/exit_portal.dart';
import '../components/background.dart';
import '../controllers/game_controller.dart';
import '../services/analytics_service.dart';
import '../config/level_config.dart';

/// Game states for the platformer
enum GameState {
  playing,
  paused,
  gameOver,
  levelComplete,
  loading
}

/// Main game class for the neon-lit cyber tower platformer
class Batch20260107101049Platformer01Game extends FlameGame
    with HasCollisionDetection, HasTappableComponents, TapDetector {
  
  /// Current game state
  GameState gameState = GameState.loading;
  
  /// Current level number (1-10)
  int currentLevel = 1;
  
  /// Player's score for current level
  int score = 0;
  
  /// Energy orbs collected in current level
  int energyOrbsCollected = 0;
  
  /// Energy orbs required to complete level
  int energyOrbsRequired = 3;
  
  /// Player lives (not used in this game but kept for extensibility)
  int lives = 3;
  
  /// Level timer in seconds
  double levelTimer = 0.0;
  
  /// Maximum time allowed for level
  double maxLevelTime = 90.0;
  
  /// Reference to game controller
  late GameController gameController;
  
  /// Reference to analytics service
  late AnalyticsService analyticsService;
  
  /// Player component
  late Player player;
  
  /// Background component
  late Background background;
  
  /// Level configuration
  late LevelConfig levelConfig;
  
  /// Components for current level
  final List<Platform> platforms = [];
  final List<EnergyOrb> energyOrbs = [];
  final List<LaserTrap> laserTraps = [];
  late ExitPortal exitPortal;
  
  /// Camera bounds
  static const double worldWidth = 400.0;
  static const double worldHeight = 800.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialize services
    gameController = GameController();
    analyticsService = AnalyticsService();
    
    // Set up camera
    camera.viewfinder.visibleGameSize = Vector2(worldWidth, worldHeight);
    camera.viewfinder.anchor = Anchor.topLeft;
    
    // Add collision detection
    add(HasCollisionDetection());
    
    // Load initial level
    await _loadLevel(currentLevel);
    
    // Log game start
    analyticsService.logEvent('game_start', {
      'level': currentLevel,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Load a specific level
  Future<void> _loadLevel(int levelNumber) async {
    gameState = GameState.loading;
    
    // Clear existing components
    _clearLevel();
    
    // Load level configuration
    levelConfig = LevelConfig.getLevel(levelNumber);
    energyOrbsRequired = levelConfig.requiredEnergyOrbs;
    maxLevelTime = levelConfig.timeLimit;
    
    // Reset level state
    energyOrbsCollected = 0;
    levelTimer = 0.0;
    score = 0;
    
    // Add background
    background = Background();
    add(background);
    
    // Create player
    player = Player(
      position: Vector2(levelConfig.playerStartX, levelConfig.playerStartY),
    );
    add(player);
    
    // Add platforms
    for (final platformData in levelConfig.platforms) {
      final platform = Platform(
        position: Vector2(platformData.x, platformData.y),
        size: Vector2(platformData.width, platformData.height),
        isMoving: platformData.isMoving,
        moveSpeed: platformData.moveSpeed,
        moveDistance: platformData.moveDistance,
      );
      platforms.add(platform);
      add(platform);
    }
    
    // Add energy orbs
    for (final orbData in levelConfig.energyOrbs) {
      final orb = EnergyOrb(
        position: Vector2(orbData.x, orbData.y),
      );
      energyOrbs.add(orb);
      add(orb);
    }
    
    // Add laser traps
    for (final trapData in levelConfig.laserTraps) {
      final trap = LaserTrap(
        position: Vector2(trapData.x, trapData.y),
        size: Vector2(trapData.width, trapData.height),
        activationDelay: trapData.activationDelay,
        activeTime: trapData.activeTime,
        cooldownTime: trapData.cooldownTime,
      );
      laserTraps.add(trap);
      add(trap);
    }
    
    // Add exit portal
    exitPortal = ExitPortal(
      position: Vector2(levelConfig.exitPortalX, levelConfig.exitPortalY),
    );
    add(exitPortal);
    
    // Set camera to follow player
    camera.follow(player);
    
    gameState = GameState.playing;
    
    // Log level start
    analyticsService.logEvent('level_start', {
      'level': levelNumber,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Update UI overlay
    overlays.add('GameUI');
  }

  /// Clear all level components
  void _clearLevel() {
    // Remove all level-specific components
    for (final platform in platforms) {
      platform.removeFromParent();
    }
    platforms.clear();
    
    for (final orb in energyOrbs) {
      orb.removeFromParent();
    }
    energyOrbs.clear();
    
    for (final trap in laserTraps) {
      trap.removeFromParent();
    }
    laserTraps.clear();
    
    if (hasComponent<Player>()) {
      player.removeFromParent();
    }
    
    if (hasComponent<Background>()) {
      background.removeFromParent();
    }
    
    if (hasComponent<ExitPortal>()) {
      exitPortal.removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (gameState == GameState.playing) {
      // Update level timer
      levelTimer += dt;
      
      // Check for time limit
      if (levelTimer >= maxLevelTime) {
        _gameOver('time_limit');
      }
      
      // Check for level completion
      if (energyOrbsCollected >= energyOrbsRequired && 
          player.overlaps(exitPortal)) {
        _levelComplete();
      }
    }
  }

  @override
  bool onTapDown(TapDownInfo info) {
    if (gameState == GameState.playing) {
      // Make player jump
      player.jump();
      return true;
    }
    return false;
  }

  /// Handle energy orb collection
  void collectEnergyOrb(EnergyOrb orb) {
    if (energyOrbs.contains(orb)) {
      energyOrbsCollected++;
      score += 10;
      orb.removeFromParent();
      energyOrbs.remove(orb);
      
      // Play collection effect
      _playCollectionEffect(orb.position);
      
      // Log collection
      analyticsService.logEvent('energy_orb_collected', {
        'level': currentLevel,
        'orbs_collected': energyOrbsCollected,
        'orbs_required': energyOrbsRequired,
      });
    }
  }

  /// Handle player collision with laser trap
  void hitLaserTrap() {
    if (gameState == GameState.playing) {
      _gameOver('laser_trap');
    }
  }

  /// Handle player falling off platforms
  void playerFellOff() {
    if (gameState == GameState.playing) {
      _gameOver('fell_off');
    }
  }

  /// Handle level completion
  void _levelComplete() {
    gameState = GameState.levelComplete;
    
    // Calculate final score
    final timeBonus = ((maxLevelTime - levelTimer) * 2).round();
    score += timeBonus;
    
    // Update game controller
    gameController.completeLevel(currentLevel, score);
    
    // Log level completion
    analyticsService.logEvent('level_complete', {
      'level': currentLevel,
      'score': score,
      'time_taken': levelTimer,
      'energy_orbs_collected': energyOrbsCollected,
    });
    
    // Show completion overlay
    overlays.remove('GameUI');
    overlays.add('LevelCompleteOverlay');
  }

  /// Handle game over
  void _gameOver(String reason) {
    gameState = GameState.gameOver;
    
    // Log level failure
    analyticsService.logEvent('level_fail', {
      'level': currentLevel,
      'reason': reason,
      'time_survived': levelTimer,
      'energy_orbs_collected': energyOrbsCollected,
    });
    
    // Show game over overlay
    overlays.remove('GameUI');
    overlays.add('GameOverOverlay');
  }

  /// Restart current level
  Future<void> restartLevel() async {
    overlays.remove('GameOverOverlay');
    await _loadLevel(currentLevel);
  }

  /// Go to next level
  Future<void> nextLevel() async {
    if (currentLevel < 10) {
      currentLevel++;
      overlays.remove('LevelCompleteOverlay');
      
      // Check if level is unlocked
      if (gameController.isLevelUnlocked(currentLevel)) {
        await _loadLevel(currentLevel);
      } else {
        // Show unlock prompt
        overlays.add('UnlockPromptOverlay');
        analyticsService.logEvent('unlock_prompt_shown', {
          'level': currentLevel,
        });
      }
    } else {
      // Game completed
      overlays.remove('LevelCompleteOverlay');
      overlays.add('GameCompleteOverlay');
    }
  }

  /// Go to specific level
  Future<void> goToLevel(int levelNumber) async {
    if (levelNumber >= 1 && levelNumber <= 10 && 
        gameController.isLevelUnlocked(levelNumber)) {
      currentLevel = levelNumber;
      overlays.clear();
      await _loadLevel(currentLevel);
    }
  }

  /// Pause the game
  void pauseGame() {
    if (gameState == GameState.playing) {
      gameState = GameState.paused;
      overlays.add('PauseOverlay');
    }
  }

  /// Resume the game
  void resumeGame() {
    if (gameState == GameState.paused) {
      gameState = GameState.playing;
      overlays.remove('PauseOverlay');
    }
  }

  /// Play collection effect at position
  void _playCollectionEffect(Vector2 position) {
    // Add particle effect or animation
    // This would be implemented with actual effect components
  }

  /// Get current progress as percentage
  double get levelProgress {
    if (energyOrbsRequired == 0) return 1.0;
    return energyOrbsCollected / energyOrbsRequired;
  }

  /// Get time remaining
  double get timeRemaining {
    return (maxLevelTime - levelTimer).clamp(0.0, maxLevelTime);
  }

  /// Get time remaining as percentage
  double get timeRemainingPercent {
    if (maxLevelTime == 0) return 1.0;
    return timeRemaining / maxLevelTime;
  }

  @override
  void onRemove() {
    // Clean up resources
    _clearLevel();
    super.onRemove();
  }
}