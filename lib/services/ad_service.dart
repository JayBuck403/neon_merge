import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics_service.dart';

class AdService {
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;
  int _gameOverCount = 0;

  // Test Ad Unit IDs - Replace with your actual Ad Unit IDs for production
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-9683085160632853/5937359908'; // Real banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Test banner
    }
    return '';
  }

  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-9683085160632853/2203140789'; // Real interstitial
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Test interstitial
    }
    return '';
  }

  String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-9683085160632853/7263895770'; // Real rewarded
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Test rewarded
    }
    return '';
  }

  // Load banner ad
  void loadBannerAd(Function(BannerAd) onAdLoaded) {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          onAdLoaded(ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

  // Load interstitial ad
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialAdReady = false;
              loadInterstitialAd(); // Preload next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialAdReady = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  // Load rewarded ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isRewardedAdReady = false;
              loadRewardedAd(); // Preload next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isRewardedAdReady = false;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdReady = false;
        },
      ),
    );
  }

  // Show interstitial ad (e.g., every 3 game overs)
  void showInterstitialAd() {
    _gameOverCount++;
    
    if (_gameOverCount % 3 == 0 && _isInterstitialAdReady) {
      // Track ad impression
      AnalyticsService().logAdViewed(
        adType: 'interstitial',
        placement: 'game_over',
      );
      
      _interstitialAd?.show();
      _isInterstitialAdReady = false;
    }
  }

  // Show rewarded ad with callbacks
  Future<bool> showRewardedAd({
    required Function() onRewarded,
    Function()? onAdDismissed,
  }) async {
    if (!_isRewardedAdReady || _rewardedAd == null) {
      return false;
    }

    bool rewarded = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedAdReady = false;
        loadRewardedAd();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isRewardedAdReady = false;
        loadRewardedAd();
        onAdDismissed?.call();
      },
    );

    try {
      // Track ad impression
      AnalyticsService().logAdViewed(
        adType: 'rewarded',
        placement: 'continue',
      );
      
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          rewarded = true;
          onRewarded();
        },
      );
      
      // Wait a bit to ensure callback fires
      await Future.delayed(const Duration(milliseconds: 500));
      
      return rewarded;
    } catch (e) {
      debugPrint('Error showing rewarded ad: $e');
      return false;
    }
  }

  bool get isRewardedAdReady => _isRewardedAdReady;

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}