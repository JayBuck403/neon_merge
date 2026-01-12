import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:neon_merge/services/analytics_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge2d/forge2d.dart';
import '../services/game_state.dart';
import '../services/ad_service.dart';
import '../services/sound_manager.dart';
import '../services/iap_service.dart';
import '../services/powerup_service.dart';
import '../models/orb_config.dart';
import '../game/physics_world.dart';
import '../widgets/game_renderer.dart';
import '../widgets/powerup_bar.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late PhysicsWorld _physicsWorld;
  Timer? _gameLoop;
  BannerAd? _bannerAd;
  bool _showMenu = true;
  final SoundManager _soundManager = SoundManager();
  final IAPService _iapService = IAPService();
  DateTime? _lastTapTime;
  static const _tapDebounceMs = 400; // Increased from 300ms to 400ms
  int _pendingOperations = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _physicsWorld = PhysicsWorld();
    _setupPhysicsCallbacks();
    _loadBannerAd();
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopGameLoop();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App in background - pause music
        _soundManager.pauseBackgroundMusic();
        break;
      case AppLifecycleState.resumed:
        // App back in foreground - resume music only if game is playing
        final gameState = context.read<GameState>();
        if (gameState.isPlaying && !_showMenu) {
          _soundManager.resumeBackgroundMusic();
        }
        break;
      case AppLifecycleState.hidden:
        // App hidden - pause music
        _soundManager.pauseBackgroundMusic();
        break;
    }
  }

  Future<void> _initializeServices() async {
    // Initialize sound manager
    await _soundManager.initialize();
    // Don't play music yet - wait for game to start
    
    // Initialize IAP
    await _iapService.initialize();
    
    // Preload interstitial and rewarded ads
    final adService = context.read<AdService>();
    adService.loadInterstitialAd();
    adService.loadRewardedAd();
  }

  void _setupPhysicsCallbacks() {
    final gameState = context.read<GameState>();
    
    _physicsWorld.onScoreAdd = (points) {
      gameState.addScore(points);
    };
    
    _physicsWorld.onMerge = (level) {
      // Non-blocking sound
      if (_soundManager.soundEnabled) {
        _soundManager.playMerge(level).catchError((e) {});
      }
      
      // Non-blocking haptic
      try {
        HapticFeedback.mediumImpact();
      } catch (e) {}
      
      // Track merge count and highest level
      try {
        gameState.incrementMergeCount();
        gameState.updateHighestLevel(level);
      } catch (e) {
        debugPrint('Merge tracking error: $e');
      }
    };
    
    _physicsWorld.onDrop = () {
      // Fire-and-forget sound - don't await
      if (_soundManager.soundEnabled) {
        _soundManager.playDrop().catchError((e) {
          // Silently ignore audio errors
        });
      }
      
      // Light haptic feedback - also non-blocking
      try {
        HapticFeedback.lightImpact();
      } catch (e) {
        // Ignore haptic errors
      }
    };
    
    _physicsWorld.onGameOver = () {
      try {
        if (_soundManager.soundEnabled) {
          _soundManager.playGameOver().catchError((e) {});
        }
        HapticFeedback.heavyImpact();
      } catch (e) {}
      
      // Pause game loop but don't stop it
      gameState.pauseGame();
      
      // Show continue option after a brief delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _showContinueDialog();
        }
      });
    };
    
    _physicsWorld.onWin = () {
      _soundManager.playWin();
      HapticFeedback.vibrate();
      
      gameState.win();
      _stopGameLoop();
      setState(() => _showMenu = true);
    };
  }

  void _loadBannerAd() {
    final adService = context.read<AdService>();
    adService.loadBannerAd((ad) {
      setState(() {
        _bannerAd = ad;
      });
    });
  }

  void _startGame() {
    final gameState = context.read<GameState>();
    gameState.resetGame();
    _physicsWorld.reset();
    
    setState(() => _showMenu = false);
    
    // Start background music when game starts
    _soundManager.playBackgroundMusic();
    
    // Track game start
    AnalyticsService().logGameStart();
    
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (gameState.isPlaying) {
        try {
          _physicsWorld.update();
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          debugPrint('Game loop error (handled): $e');
          // Don't crash, just skip this frame
        }
      }
    });
    
    // Show tutorial for first-time players
    _checkAndShowTutorial();
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('has_seen_tutorial') ?? false;
    
    if (!hasSeenTutorial && mounted) {
      // Small delay to let game screen render first
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        await _showTutorialDialog();
        await prefs.setBool('has_seen_tutorial', true);
      }
    }
  }

  Future<void> _showTutorialDialog() async {
    final gameState = context.read<GameState>();
    
    // Pause game during tutorial
    gameState.pauseGame();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.sports_esports,
                color: Color(0xFF00F2FF),
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                'HOW TO PLAY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTutorialSection(
                  '🎯',
                  'Objective',
                  'Merge orbs to reach the Supernova (Level 10)!',
                ),
                const SizedBox(height: 16),
                
                _buildTutorialSection(
                  '🎮',
                  'How to Play',
                  '• Tap anywhere to drop orbs\n'
                  '• Watch "Next" preview at top\n'
                  '• Match same colors to merge\n'
                  '• Each merge creates a bigger orb\n'
                  '• Avoid crossing the red death line',
                ),
                const SizedBox(height: 16),
                
                _buildTutorialSection(
                  '⚡',
                  'Power-Ups',
                  '💣 Bomb - Destroy bottom orbs\n'
                  '🛡️ Shield - Prevent game over\n\n'
                  'Tap empty power-ups to buy with coins or watch ads!',
                ),
                const SizedBox(height: 16),
                
                _buildTutorialSection(
                  '💰',
                  'Coins',
                  'Earn coins by scoring points!\n'
                  'Use coins to buy power-ups\n'
                  'Or watch ads for free power-ups',
                ),
                const SizedBox(height: 16),
                
                const Text(
                  '💡 Tip: Plan your moves carefully!\nHigher level orbs = more points!',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Resume game after tutorial
                gameState.resumeGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F2FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'GOT IT! LET\'S PLAY!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        ),
      ),
    );
    
    // Track tutorial completion
    AnalyticsService().logTutorialComplete();
  }

  Widget _buildTutorialSection(String emoji, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF00F2FF),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  void _stopGameLoop() {
    _gameLoop?.cancel();
    _gameLoop = null;
  }

  void _handleTap(TapDownDetails details) {
    final gameState = context.read<GameState>();
    if (!gameState.isPlaying || _showMenu) return;
    
    // Prevent too many pending operations
    if (_pendingOperations > 2) {
      return; // Already processing drops, skip this tap
    }
    
    // Debounce rapid taps
    final now = DateTime.now();
    if (_lastTapTime != null) {
      final timeSinceLastTap = now.difference(_lastTapTime!).inMilliseconds;
      if (timeSinceLastTap < _tapDebounceMs) {
        return; // Too fast, ignore this tap
      }
    }
    _lastTapTime = now;
    
    _pendingOperations++;
    
    try {
      final RenderBox box = context.findRenderObject() as RenderBox;
      final localPosition = box.globalToLocal(details.globalPosition);
      
      // Get next orb level from GameState
      final nextLevel = gameState.consumeNextOrb();
      _physicsWorld.dropOrbWithLevel(localPosition.dx, nextLevel);
    } catch (e) {
      debugPrint('Tap handling error: $e');
    } finally {
      // Decrement after short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_pendingOperations > 0) {
          _pendingOperations--;
        }
      });
    }
  }

  Future<void> _showContinueDialog() async {
    final gameState = context.read<GameState>();
    final adService = context.read<AdService>();
    
    // Stop background music on game over
    _soundManager.stopBackgroundMusic();
    
    // Check if rewarded ad is available
    if (!adService.isRewardedAdReady) {
      // No ad available, just show game over
      gameState.gameOver();
      _stopGameLoop();
      setState(() => _showMenu = true);
      adService.showInterstitialAd();
      return;
    }
    
    // Show continue option
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'CONTINUE?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_outline,
                color: Color(0xFF00F2FF),
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Watch an ad to continue playing!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Current Score: ${gameState.score}',
                style: const TextStyle(
                  color: Color(0xFF00F2FF),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                
                // Track game over with full metrics
                final analytics = AnalyticsService();
                analytics.logGameOver(
                  score: gameState.score,
                  mergeCount: gameState.mergeCount,
                  highestLevel: gameState.highestLevelReached,
                  coinsEarned: (gameState.score / 1000).floor(),
                  duration: 0, // TODO: Track session duration
                );
                
                gameState.gameOver();
                _stopGameLoop();
                setState(() => _showMenu = true);
                adService.showInterstitialAd();
              },
              child: const Text(
                'END GAME',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00F2FF),
                    ),
                  ),
                );
                
                // Small delay to ensure dialog is dismissed
                await Future.delayed(const Duration(milliseconds: 100));
                
                bool adShown = false;
                
                try {
                  adShown = await adService.showRewardedAd(
                    onRewarded: () {
                      // User watched the full ad - give reward
                      _clearTopOrbs();
                      gameState.resumeGame();
                      // Resume background music when continuing
                      _soundManager.playBackgroundMusic();
                      
                      // Track rewarded ad completion
                      AnalyticsService().logAdRewarded(
                        placement: 'continue',
                        reward: 'continue',
                      );
                    },
                  );
                } catch (e) {
                  debugPrint('Error showing rewarded ad: $e');
                }
                
                // Dismiss loading
                if (mounted) {
                  Navigator.of(context).pop();
                }
                
                if (adShown) {
                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Keep playing! Good luck!'),
                        backgroundColor: Color(0xFF00F2FF),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  // Ad failed to show
                  gameState.gameOver();
                  _stopGameLoop();
                  setState(() => _showMenu = true);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ad not available. Try again later!'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F2FF),
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'WATCH AD',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearTopOrbs() {
    // Remove orbs above the death line to give player a fresh start
    final orbsToRemove = _physicsWorld.orbs
        .where((orb) => orb.body.position.y < _physicsWorld.deathLineY)
        .toList();
    
    for (final orb in orbsToRemove) {
      _physicsWorld.orbs.remove(orb);
      _physicsWorld.world.destroyBody(orb.body);
    }
    
    _physicsWorld.deathTimer = 0;
  }

  void _handlePowerUpUsed(PowerUpType type) {
    final gameState = context.read<GameState>();
    
    _soundManager.playPowerUp();
    HapticFeedback.heavyImpact();
    
    // Track power-up usage
    AnalyticsService().logPowerUpUsed(
      powerUpType: type.toString().split('.').last,
      score: gameState.score,
    );
    
    switch (type) {
      case PowerUpType.bomb:
        _useBombPowerUp();
        break;
      case PowerUpType.shield:
        gameState.activateShield();
        break;
      case PowerUpType.wild:
      case PowerUpType.magnet:
        // Not implemented yet
        break;
    }
    
    setState(() {});
  }

  void _useBombPowerUp() {
    // Find and remove the bottom 20% of orbs
    final threshold = _physicsWorld.worldHeight * 0.8;
    final orbsToRemove = _physicsWorld.orbs
        .where((orb) => orb.body.position.y > threshold)
        .toList();
    
    for (final orb in orbsToRemove) {
      _physicsWorld.orbs.remove(orb);
      _physicsWorld.world.destroyBody(orb.body);
    }
    
    // Visual feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Destroyed ${orbsToRemove.length} orbs!'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFFFF4D00),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF050507),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Score display
              _buildScoreDisplay(),
              
              // Power-up bar
              PowerUpBar(onPowerUpUsed: _handlePowerUpUsed),
              
              // Next orbs preview (always visible)
              Consumer<GameState>(
                builder: (context, gameState, _) {
                  if (!gameState.isPlaying) {
                    return const SizedBox.shrink();
                  }
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Next: ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ...gameState.nextOrbs.map((level) {
                          final config = OrbConfig.levels[level];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: config.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: config.color.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
              
              // Game area
              Expanded(
                child: GestureDetector(
                  onTapDown: _handleTap,
                  child: Stack(
                    children: [
                      // Game renderer
                      GameRenderer(
                        physicsWorld: _physicsWorld,
                        showDeathLine: _physicsWorld.showDeathLine,
                      ),
                      
                      // Menu overlay
                      if (_showMenu) _buildMenuOverlay(),
                    ],
                  ),
                ),
              ),
              
              // Banner ad
              if (_bannerAd != null && !_iapService.adsRemoved)
                Container(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  color: Colors.black,
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreDisplay() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        final challenge = gameState.dailyChallenge.currentChallenge;
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              // Coins and shield display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Coins
                  const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${gameState.coins}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // Shield indicator
                  if (gameState.shieldActive) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF00).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00FF00)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield, color: Color(0xFF00FF00), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'PROTECTED',
                            style: TextStyle(
                              color: Color(0xFF00FF00),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              
              // High score
              Text(
                'BEST: ${gameState.highScore}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 5),
              
              // Current score
              Text(
                '${gameState.score}',
                style: const TextStyle(
                  fontSize: 60,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                  shadows: [
                    Shadow(
                      color: Color(0xFF00F2FF),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              
              // Daily challenge indicator
              if (challenge != null && !gameState.dailyChallenge.isCompleted)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00F2FF).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFD700),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        challenge.title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        height: 4,
                        child: LinearProgressIndicator(
                          value: gameState.dailyChallenge.progressPercentage,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00F2FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOverlay() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        String title = 'NEON MERGE';
        String subtitle = '';
        int coinsEarned = 0;
        
        if (gameState.isGameOver) {
          if (gameState.hasWon) {
            title = 'SUPERNOVA!';
            subtitle = 'Legendary! Score: ${gameState.score}';
            coinsEarned = 100;
          } else {
            title = 'GAME OVER';
            subtitle = 'Final Score: ${gameState.score}';
            coinsEarned = (gameState.score / 100).floor();
          }
        }
        
        final challenge = gameState.dailyChallenge.currentChallenge;
        final challengeComplete = gameState.dailyChallenge.isCompleted;
        
        return Container(
          color: Colors.black.withOpacity(0.9),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Color(0xFF00F2FF),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white70,
                    ),
                  ),
                ],
                
                // Coins earned
                if (gameState.isGameOver && coinsEarned > 0) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Color(0xFFFFD700),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+$coinsEarned coins earned!',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Daily challenge status
                if (!gameState.isGameOver && challenge != null) ...[
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: challengeComplete 
                            ? const Color(0xFF00FF00) 
                            : const Color(0xFF00F2FF),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              challengeComplete ? Icons.check_circle : Icons.star,
                              color: challengeComplete 
                                  ? const Color(0xFF00FF00) 
                                  : const Color(0xFFFFD700),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              challengeComplete ? 'CHALLENGE COMPLETE!' : 'DAILY CHALLENGE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          challenge.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (challengeComplete) ...[
                          const SizedBox(height: 8),
                          Text(
                            '+ ${challenge.rewardCoins} coins',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 40),
                
                // Play button
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F2FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: const Color(0xFF00F2FF),
                  ),
                  child: Text(
                    gameState.isGameOver ? 'PLAY AGAIN' : 'TAP TO START',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                
                // Shop button
                if (!_iapService.adsRemoved) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _showShopDialog,
                    icon: const Icon(Icons.shopping_cart, color: Color(0xFFFFD700)),
                    label: const Text(
                      'REMOVE ADS - \$2.99',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                
                // Free power-ups button
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _showFreePowerUpsDialog,
                  icon: const Icon(Icons.card_giftcard, color: Color(0xFF00F2FF)),
                  label: const Text(
                    'GET FREE POWER-UPS',
                    style: TextStyle(
                      color: Color(0xFF00F2FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // Settings button
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings, color: Colors.white70),
                  label: const Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShopDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'REMOVE ADS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Enjoy the game without any interruptions!\n\n'
          'One-time purchase: \$2.99',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _iapService.buyProduct(IAPService.removeAdsId);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ads removed! Thank you for your support!'),
                    backgroundColor: Color(0xFF00FF00),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F2FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('BUY NOW'),
          ),
        ],
      ),
    );
  }

  void _showFreePowerUpsDialog() {
    final adService = context.read<AdService>();
    final gameState = context.read<GameState>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'GET POWER-UPS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.card_giftcard,
              color: Color(0xFF00F2FF),
              size: 64,
            ),
            const SizedBox(height: 16),
            
            // Coin balance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'You have: ${gameState.coins} coins',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Get a random power-up by:',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text('You might get:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 8),
                  Text('💣 Bomb (10 coins)',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  Text('🛡️ Shield (15 coins)',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  Text('💡 Hint (8 coins)',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Or tap a power-up button during game to buy specific ones!',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          
          // Buy random with coins (8-15, average 11)
          ElevatedButton.icon(
            onPressed: gameState.coins >= 10
                ? () async {
                    Navigator.of(dialogContext).pop();
                    
                    final success = await gameState.spendCoins(10);
                    if (success) {
                      _giveRandomPowerUp();
                    }
                  }
                : null,
            icon: const Icon(Icons.monetization_on, size: 18),
            label: const Text('10 COINS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: gameState.coins >= 10 
                  ? const Color(0xFFFFD700) 
                  : Colors.grey,
              foregroundColor: Colors.black,
            ),
          ),
          
          // Watch ad for free
          ElevatedButton.icon(
            onPressed: adService.isRewardedAdReady
                ? () async {
                    Navigator.of(dialogContext).pop();
                    
                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00F2FF)),
                      ),
                    );
                    
                    await Future.delayed(const Duration(milliseconds: 100));
                    
                    try {
                      final adShown = await adService.showRewardedAd(
                        onRewarded: () {
                          _giveRandomPowerUp();
                        },
                      );
                      
                      if (mounted) {
                        Navigator.of(context).pop(); // Dismiss loading
                        
                        if (!adShown) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ad not available. Try again later!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error showing ad. Please try again!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                : null,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('WATCH AD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: adService.isRewardedAdReady
                  ? const Color(0xFF00F2FF)
                  : Colors.grey,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _giveRandomPowerUp() {
    final gameState = context.read<GameState>();
    final random = DateTime.now().millisecondsSinceEpoch % 2;
    
    PowerUpType type;
    switch (random) {
      case 0:
        type = PowerUpType.bomb;
        break;
      default:
        type = PowerUpType.shield;
    }
    
    gameState.powerUpInventory.add(type, 1);
    
    _soundManager.playPowerUp();
    HapticFeedback.mediumImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You got: ${PowerUpInfo.getEmoji(type)} ${PowerUpInfo.getName(type)}!',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00FF00),
        duration: const Duration(seconds: 3),
      ),
    );
    
    setState(() {});
  }

  void _openSettings() {
    // Track settings screen view
    AnalyticsService().logScreenView(screenName: 'settings');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }
}