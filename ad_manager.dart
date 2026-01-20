// ignore_for_file: unused_field

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;
  static final bool _isSupported = Platform.isAndroid || Platform.isIOS;

  /// تهيئة AdMob
  static Future<void> initialize() async {
    if (_isSupported) {
      await MobileAds.instance.initialize();
    } else {
      debugPrint("Ads are not supported on this platform");
    }
  }

  /// عرض Interstitial
  static void showInterstitial({required VoidCallback onComplete}) {
    if (!_isSupported) {
      onComplete(); // تخطي الإعلانات على Windows
      return;
    }

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-5228897328353749/1771169590', // ID اختبار
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.show();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              onComplete();
              ad.dispose();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial Failed: ${error.message}');
          onComplete();
        },
      ),
    );
  }

  /// عرض Rewarded
  static void showRewarded({required Function(int) onReward}) {
    if (!_isSupported) {
      onReward(0); // لا يوجد مكافأة على Windows
      return;
    }

    RewardedAd.load(
      adUnitId: 'ca-app-pub-5228897328353749/9980832105', // ID اختبار
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.show(
            onUserEarnedReward: (ad, reward) {
              onReward(reward.amount.toInt());
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded Failed: ${error.message}');
        },
      ),
    );
  }
}
