import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Main game class for the neon-lit cyber tower platformer
class Batch20260107101049Platformer01Game extends FlameGame
    with HasTappableComponents, HasCollisionDetection {
  
  /// Current game state
  GameState gameState = GameState.playing;
  
  /// Current level number (1-10)
  int currentLevel = 1;
  
  /// Player's score for current level
  int currentScore = 0;
  
  /// Total energy orbs collected
  int totalEnergyOrbs = 0;
  
  /// Energy orbs collected in current level
  int levelEnergyOrbs = 0;
  
  /// Required energy orbs for current level completion
  int requiredEnergyOrbs = 3;
  
  /// Level timer in seconds
  double levelTimer = 0.0;
  
  /// Maximum time allowed for current level (0 = no limit)
  double maxLevelTime = 0.0;
  
  /// Player component reference
  late PlayerComponent player;
  
  /// Level manager component
  late LevelManager levelManager;
  
  /// UI overlay manager
  late OverlayManager overlayManager;
  
  /// Analytics service hook
  Function(String event, Map<String, dynamic> parameters)? onAnalyticsEvent;
  
  /// Ad service hook for rewarded ads
  Future<bool> Function()? onShowRewardedAd;
  
  /// Storage service hook for saving progress
  Future<void> Function(Map<String, dynamic> data)? onSaveProgress;
  
  /// Storage service hook for loading progress
  Future<Map<String, dynamic>?> Function()? onLoadProgress;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Initialize camera
    camera.viewfinder.visibleGameSize = size;
    
    // Load saved progress
    await _loadProgress();
    
    // Initialize level manager
    levelManager = LevelManager(this);
    add(levelManager);
    
    // Initialize overlay manager
    overlayManager = OverlayManager(this);
    add(overlayManager);
    
    // Load initial level
    await _loadLevel(currentLevel);
    
    // Track game start
    _trackEvent('game_start', {
      'level': currentLevel,
      'total_orbs': totalEnergyOrbs,
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (gameState == GameState.playing) {
      // Update level timer
      levelTimer += dt;
      
      // Check time limit
      if (maxLevelTime > 0 && levelTimer >= maxLevelTime) {
        _failLevel('time_limit_reached');
      }
      
      // Check level completion
      if (levelEnergyOrbs >= requiredEnergyOrbs && _playerReachedExit()) {
        _completeLevel();
      }
    }
  }

  /// Handle tap input for jumping
  @override
  bool onTapDown(TapDownInfo info) {
    if (gameState == GameState.playing) {
      player.jump();
      return true;
    }
    return false;
  }

  /// Load a specific level
  Future<void> _loadLevel(int levelNumber) async {
    try {
      // Clear existing level components
      removeWhere((component) => component is LevelComponent);
      
      // Reset level state
      levelEnergyOrbs = 0;
      levelTimer = 0.0;
      gameState = GameState.playing;
      
      // Configure level parameters based on difficulty curve
      _configureLevelDifficulty(levelNumber);
      
      // Create player
      player = PlayerComponent();
      add(player);
      
      // Load level layout
      await levelManager.loadLevel(levelNumber);
      
      // Track level start
      _trackEvent('level_start', {
        'level': levelNumber,
        'required_orbs': requiredEnergyOrbs,
        'time_limit': maxLevelTime,
      });
      
    } catch (e) {
      debugPrint('Error loading level $levelNumber: $e');
      gameState = GameState.gameOver;
    }
  }

  /// Configure difficulty parameters for the given level
  void _configureLevelDifficulty(int levelNumber) {
    switch (levelNumber) {
      case 1:
        requiredEnergyOrbs = 3;
        maxLevelTime = 0.0; // No time limit
        break;
      case 2:
        requiredEnergyOrbs = 5;
        maxLevelTime = 0.0;
        break;
      case 3:
        requiredEnergyOrbs = 6;
        maxLevelTime = 90.0;
        break;
      case 4:
        requiredEnergyOrbs = 8;
        maxLevelTime = 75.0;
        break;
      case 5:
        requiredEnergyOrbs = 8;
        maxLevelTime = 60.0;
        break;
      default:
        // Levels 6-10 with increasing difficulty
        requiredEnergyOrbs = 10 + (levelNumber - 6) * 2;
        maxLevelTime = 60.0 - (levelNumber - 5) * 3.0;
        break;
    }
  }

  /// Complete the current level
  void _completeLevel() {
    gameState = GameState.levelComplete;
    
    // Award energy orbs
    int orbsEarned = 15; // Base earn rate per level
    totalEnergyOrbs += orbsEarned;
    
    // Calculate score bonus
    int timeBonus = maxLevelTime > 0 ? 
        ((maxLevelTime - levelTimer) * 10).round().clamp(0, 500) : 0;
    currentScore += (levelEnergyOrbs * 100) + timeBonus;
    
    // Track completion
    _trackEvent('level_complete', {
      'level': currentLevel,
      'orbs_collected': levelEnergyOrbs,
      'time_taken': levelTimer,
      'score': currentScore,
      'orbs_earned': orbsEarned,
    });
    
    // Save progress
    _saveProgress();
    
    // Show completion overlay
    overlayManager.showLevelComplete();
  }

  /// Fail the current level
  void _failLevel(String reason) {
    gameState = GameState.gameOver;
    
    // Track failure
    _trackEvent('level_fail', {
      'level': currentLevel,
      'reason': reason,
      'orbs_collected': levelEnergyOrbs,
      'time_taken': levelTimer,
    });
    
    // Show game over overlay
    overlayManager.showGameOver();
  }

  /// Restart the current level
  Future<void> restartLevel() async {
    await _loadLevel(currentLevel);
  }

  /// Advance to the next level
  Future<void> nextLevel() async {
    if (currentLevel < 10) {
      // Check if level is unlocked
      if (currentLevel >= 3 && !_isLevelUnlocked(currentLevel + 1)) {
        // Show unlock prompt
        _trackEvent('unlock_prompt_shown', {'level': currentLevel + 1});
        overlayManager.showUnlockPrompt(currentLevel + 1);
        return;
      }
      
      currentLevel++;
      await _loadLevel(currentLevel);
    } else {
      // Game completed
      _trackEvent('game_complete', {
        'total_score': currentScore,
        'total_orbs': totalEnergyOrbs,
      });
      overlayManager.showGameComplete();
    }
  }

  /// Unlock a level through rewarded ad
  Future<void> unlockLevel(int levelNumber) async {
    if (onShowRewardedAd != null) {
      _trackEvent('rewarded_ad_started', {'level': levelNumber});
      
      try {
        bool adCompleted = await onShowRewardedAd!();
        
        if (adCompleted) {
          _trackEvent('rewarded_ad_completed', {'level': levelNumber});
          _trackEvent('level_unlocked', {'level': levelNumber});
          
          // Unlock the level and advance
          currentLevel = levelNumber;
          await _loadLevel(currentLevel);
        } else {
          _trackEvent('rewarded_ad_failed', {'level': levelNumber});
        }
      } catch (e) {
        _trackEvent('rewarded_ad_failed', {
          'level': levelNumber,
          'error': e.toString(),
        });
      }
    }
  }

  /// Collect an energy orb
  void collectEnergyOrb() {
    levelEnergyOrbs++;
    currentScore += 100;
    
    // Visual feedback
    overlayManager.showOrbCollected();
  }

  /// Check if player has reached the exit portal
  bool _playerReachedExit() {
    // This would check collision with exit portal component
    return false; // Placeholder
  }

  /// Check if a level is unlocked
  bool _isLevelUnlocked(int levelNumber) {
    // Levels 1-3 are free, 4-10 require ads
    return levelNumber <= 3;
  }

  /// Save game progress
  Future<void> _saveProgress() async {
    if (onSaveProgress != null) {
      try {
        await onSaveProgress!({
          'current_level': currentLevel,
          'total_energy_orbs': totalEnergyOrbs,
          'current_score': currentScore,
          'unlocked_levels': List.generate(currentLevel, (i) => i + 1),
        });
      } catch (e) {
        debugPrint('Error saving progress: $e');
      }
    }
  }

  /// Load game progress
  Future<void> _loadProgress() async {
    if (onLoadProgress != null) {
      try {
        final data = await onLoadProgress!();
        if (data != null) {
          currentLevel = data['current_level'] ?? 1;
          totalEnergyOrbs = data['total_energy_orbs'] ?? 0;
          currentScore = data['current_score'] ?? 0;
        }
      } catch (e) {
        debugPrint('Error loading progress: $e');
      }
    }
  }

  /// Track analytics event
  void _trackEvent(String event, Map<String, dynamic> parameters) {
    onAnalyticsEvent?.call(event, parameters);
  }

  /// Pause the game
  void pauseGame() {
    if (gameState == GameState.playing) {
      gameState = GameState.paused;
      overlayManager.showPauseMenu();
    }
  }

  /// Resume the game
  void resumeGame() {
    if (gameState == GameState.paused) {
      gameState = GameState.playing;
      overlayManager.hidePauseMenu();
    }
  }
}

/// Game state enumeration
enum GameState {
  playing,
  paused,
  gameOver,
  levelComplete,
}

/// Base class for level-specific components
abstract class LevelComponent extends Component {}

/// Player character component
class PlayerComponent extends SpriteAnimationComponent with LevelComponent {
  bool isJumping = false;
  double jumpVelocity = 0.0;
  final double gravity = 980.0; // pixels per second squared
  final double jumpStrength = 400.0; // pixels per second

  /// Make the player jump
  void jump() {
    if (!isJumping) {
      isJumping = true;
      jumpVelocity = -jumpStrength;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (isJumping) {
      jumpVelocity += gravity * dt;
      position.y += jumpVelocity * dt;
      
      // Check for landing (simplified)
      if (position.y >= 400) { // Ground level
        position.y = 400;
        isJumping = false;
        jumpVelocity = 0.0;
      }
    }
  }
}

/// Level management component
class LevelManager extends Component {
  final Batch20260107101049Platformer01Game game;
  
  LevelManager(this.game);

  /// Load level layout and components
  Future<void> loadLevel(int levelNumber) async {
    // Create platforms, obstacles, collectibles based on level
    _createPlatforms(levelNumber);
    _createObstacles(levelNumber);
    _createCollectibles(levelNumber);
    _createExitPortal(levelNumber);
  }

  void _createPlatforms(int levelNumber) {
    // Create platform components based on level design
  }

  void _createObstacles(int levelNumber) {
    // Create laser trap and obstacle components
  }

  void _createCollectibles(int levelNumber) {
    // Create energy orb components
  }

  void _createExitPortal(int levelNumber) {
    // Create exit portal component
  }
}

/// UI overlay management component
class OverlayManager extends Component {
  final Batch20260107101049Platformer01Game game;
  
  OverlayManager(this.game);

  void showLevelComplete() {
    // Show level completion overlay
  }

  void showGameOver() {
    // Show game over overlay
  }

  void showUnlockPrompt(int levelNumber) {
    // Show level unlock prompt with ad option
  }

  void showGameComplete() {
    // Show game completion overlay
  }

  void showOrbCollected() {
    // Show energy orb collection feedback
  }

  void showPauseMenu() {
    // Show pause menu overlay
  }

  void hidePauseMenu() {
    // Hide pause menu overlay
  }
}