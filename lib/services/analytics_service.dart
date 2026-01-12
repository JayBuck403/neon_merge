import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  FirebaseAnalytics get analytics => _analytics;
  FirebaseAnalyticsObserver get observer => 
      FirebaseAnalyticsObserver(analytics: _analytics);

  // User Properties
  Future<void> setUserProperties({
    required int totalGamesPlayed,
    required int highScore,
    required int totalCoins,
  }) async {
    await _analytics.setUserProperty(
      name: 'total_games_played',
      value: totalGamesPlayed.toString(),
    );
    await _analytics.setUserProperty(
      name: 'high_score',
      value: highScore.toString(),
    );
    await _analytics.setUserProperty(
      name: 'total_coins',
      value: totalCoins.toString(),
    );
  }

  // Game Events
  Future<void> logGameStart() async {
    await _analytics.logEvent(
      name: 'game_start',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logGameOver({
    required int score,
    required int mergeCount,
    required int highestLevel,
    required int coinsEarned,
    required int duration,
  }) async {
    await _analytics.logEvent(
      name: 'game_over',
      parameters: {
        'score': score,
        'merge_count': mergeCount,
        'highest_level': highestLevel,
        'coins_earned': coinsEarned,
        'duration_seconds': duration,
      },
    );
  }

  Future<void> logWin({
    required int score,
    required int duration,
  }) async {
    await _analytics.logEvent(
      name: 'game_win',
      parameters: {
        'score': score,
        'duration_seconds': duration,
      },
    );
  }

  // Power-up Events
  Future<void> logPowerUpUsed({
    required String powerUpType,
    required int score,
  }) async {
    await _analytics.logEvent(
      name: 'power_up_used',
      parameters: {
        'power_up_type': powerUpType,
        'score_at_use': score,
      },
    );
  }

  Future<void> logPowerUpPurchased({
    required String powerUpType,
    required String purchaseMethod, // 'coins' or 'ad'
  }) async {
    await _analytics.logEvent(
      name: 'power_up_purchased',
      parameters: {
        'power_up_type': powerUpType,
        'purchase_method': purchaseMethod,
      },
    );
  }

  // Ad Events
  Future<void> logAdViewed({
    required String adType, // 'banner', 'interstitial', 'rewarded'
    required String placement, // 'game_over', 'continue', 'power_up'
  }) async {
    await _analytics.logEvent(
      name: 'ad_viewed',
      parameters: {
        'ad_type': adType,
        'placement': placement,
      },
    );
  }

  Future<void> logAdClicked({
    required String adType,
    required String placement,
  }) async {
    await _analytics.logEvent(
      name: 'ad_clicked',
      parameters: {
        'ad_type': adType,
        'placement': placement,
      },
    );
  }

  Future<void> logAdRewarded({
    required String placement,
    required String reward, // 'continue', 'power_up'
  }) async {
    await _analytics.logEvent(
      name: 'ad_rewarded',
      parameters: {
        'placement': placement,
        'reward_type': reward,
      },
    );
  }

  // Daily Challenge Events
  Future<void> logChallengeStarted({
    required String challengeType,
    required int target,
  }) async {
    await _analytics.logEvent(
      name: 'challenge_started',
      parameters: {
        'challenge_type': challengeType,
        'target': target,
      },
    );
  }

  Future<void> logChallengeCompleted({
    required String challengeType,
    required int coinsEarned,
  }) async {
    await _analytics.logEvent(
      name: 'challenge_completed',
      parameters: {
        'challenge_type': challengeType,
        'coins_earned': coinsEarned,
      },
    );
  }

  // Coin Events
  Future<void> logCoinsEarned({
    required int amount,
    required String source, // 'game_over', 'win', 'challenge'
  }) async {
    await _analytics.logEvent(
      name: 'coins_earned',
      parameters: {
        'amount': amount,
        'source': source,
      },
    );
  }

  Future<void> logCoinsSpent({
    required int amount,
    required String item, // 'bomb', 'shield', etc.
  }) async {
    await _analytics.logEvent(
      name: 'coins_spent',
      parameters: {
        'amount': amount,
        'item': item,
      },
    );
  }

  // Milestone Events
  Future<void> logMilestone({
    required String type, // 'score', 'level', 'merges'
    required int value,
  }) async {
    await _analytics.logEvent(
      name: 'milestone_reached',
      parameters: {
        'milestone_type': type,
        'value': value,
      },
    );
  }

  // Settings Events
  Future<void> logSettingChanged({
    required String setting, // 'sound', 'music', 'haptics'
    required bool enabled,
  }) async {
    await _analytics.logEvent(
      name: 'setting_changed',
      parameters: {
        'setting': setting,
        'enabled': enabled,
      },
    );
  }

  // IAP Events (built-in Firebase events)
  Future<void> logPurchase({
    required String productId,
    required double price,
    required String currency,
  }) async {
    await _analytics.logPurchase(
      currency: currency,
      value: price,
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productId,
          price: price,
        ),
      ],
    );
  }

  // Screen View Events
  Future<void> logScreenView({
    required String screenName,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
    );
  }

  // Tutorial Events
  Future<void> logTutorialBegin() async {
    await _analytics.logTutorialBegin();
  }

  Future<void> logTutorialComplete() async {
    await _analytics.logTutorialComplete();
  }

  // Level Events
  Future<void> logLevelUp({
    required int level,
    required String character, // orb color/type
  }) async {
    await _analytics.logLevelUp(
      level: level,
      character: character,
    );
  }

  // Engagement
  Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  // Session Events
  Future<void> logSessionStart() async {
    await _analytics.logEvent(
      name: 'session_start',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logSessionEnd({
    required int durationSeconds,
    required int gamesPlayed,
  }) async {
    await _analytics.logEvent(
      name: 'session_end',
      parameters: {
        'duration_seconds': durationSeconds,
        'games_played': gamesPlayed,
      },
    );
  }

  // Retention Events
  Future<void> logDailyLogin({
    required int consecutiveDays,
  }) async {
    await _analytics.logEvent(
      name: 'daily_login',
      parameters: {
        'consecutive_days': consecutiveDays,
      },
    );
  }

  // Error Events
  Future<void> logError({
    required String errorType,
    required String errorMessage,
  }) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage,
      },
    );
  }
}