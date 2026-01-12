import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'powerup_service.dart';
import 'daily_challenge_service.dart';
import 'analytics_service.dart';

class GameState extends ChangeNotifier {
  int _score = 0;
  int _highScore = 0;
  int _coins = 0;
  int _mergeCount = 0;
  bool _isGameOver = false;
  bool _isPlaying = false;
  bool _hasWon = false;
  bool _shieldActive = false;
  int _highestLevelReached = 0;
  final List<int> _nextOrbs = [0, 0, 0]; // Next 3 orbs to drop - always visible

  final PowerUpInventory powerUpInventory = PowerUpInventory();
  final DailyChallengeService dailyChallenge = DailyChallengeService();

  GameState(int initialHighScore) {
    _highScore = initialHighScore;
    _loadCoins();
    dailyChallenge.initialize();
  }

  Future<void> _loadCoins() async {
    final prefs = await SharedPreferences.getInstance();
    _coins = prefs.getInt('coins') ?? 0;
    notifyListeners();
  }

  int get score => _score;
  int get highScore => _highScore;
  int get coins => _coins;
  int get mergeCount => _mergeCount;
  bool get isGameOver => _isGameOver;
  bool get isPlaying => _isPlaying;
  bool get hasWon => _hasWon;
  bool get shieldActive => _shieldActive;
  int get highestLevelReached => _highestLevelReached;
  List<int> get nextOrbs => _nextOrbs;

  void generateNextOrbs() {
    for (int i = 0; i < 3; i++) {
      _nextOrbs[i] = DateTime.now().millisecondsSinceEpoch % 3;
    }
    notifyListeners();
  }

  int consumeNextOrb() {
    final orb = _nextOrbs.removeAt(0);
    _nextOrbs.add(DateTime.now().millisecondsSinceEpoch % 3);
    notifyListeners();
    return orb;
  }

  void addScore(int points) {
    _score += points;
    if (_score > _highScore) {
      _highScore = _score;
      _saveHighScore();
      
      // Track new high score milestone
      AnalyticsService().logMilestone(
        type: 'score',
        value: _highScore,
      );
    }
    
    // Update daily challenge
    dailyChallenge.updateProgress(ChallengeType.reachScore, _score);
    
    notifyListeners();
  }

  void incrementMergeCount() {
    _mergeCount++;
    dailyChallenge.updateProgress(ChallengeType.mergeCount, _mergeCount);
    notifyListeners();
  }

  void updateHighestLevel(int level) {
    if (level > _highestLevelReached) {
      _highestLevelReached = level;
      dailyChallenge.updateProgress(ChallengeType.createLevel, level);
      
      // Track level milestone
      AnalyticsService().logLevelUp(
        level: level,
        character: 'orb_level_$level',
      );
      
      notifyListeners();
    }
  }

  Future<void> addCoins(int amount) async {
    _coins += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', _coins);
    
    // Track coin earnings
    AnalyticsService().logCoinsEarned(
      amount: amount,
      source: 'game',
    );
    
    notifyListeners();
  }

  Future<bool> spendCoins(int amount) async {
    if (_coins >= amount) {
      _coins -= amount;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('coins', _coins);
      notifyListeners();
      return true;
    }
    return false;
  }

  void activateShield() {
    _shieldActive = true;
    notifyListeners();
  }

  void useShield() {
    _shieldActive = false;
    notifyListeners();
  }

  void resetGame() {
    _score = 0;
    _mergeCount = 0;
    _isGameOver = false;
    _isPlaying = true;
    _hasWon = false;
    _highestLevelReached = 0;
    generateNextOrbs();
    notifyListeners();
  }

  void gameOver() {
    // Check if shield is active
    if (_shieldActive) {
      useShield();
      return; // Don't end game, shield saves us
    }
    
    _isGameOver = true;
    _isPlaying = false;
    
    // Award coins based on score - DRASTICALLY REDUCED
    // Now: 1 coin per 1000 points (was 500, now 10x harder!)
    final coinsEarned = (_score / 1000).floor();
    if (coinsEarned > 0) {
      addCoins(coinsEarned);
    }
    
    notifyListeners();
  }

  void win() {
    _hasWon = true;
    _isGameOver = true;
    _isPlaying = false;
    
    // Bonus coins for winning - DRASTICALLY REDUCED
    // Now: 10 coins (was 20, now 50% of before)
    addCoins(10);
    
    // Track game win
    AnalyticsService().logWin(
      score: _score,
      duration: 0, // TODO: Track session duration
    );
    
    notifyListeners();
  }

  void pauseGame() {
    _isPlaying = false;
    notifyListeners();
  }

  void resumeGame() {
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', _highScore);
  }
}