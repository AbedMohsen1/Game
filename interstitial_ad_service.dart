import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdService {
  InterstitialAdService._();
  static final InterstitialAdService instance = InterstitialAdService._();

  InterstitialAd? _ad;
  bool _loading = false;
  bool _showing = false;

  DateTime? _lastShownAt;
  final Duration minInterval = const Duration(minutes: 5);

  int _retryAttempt = 0;
  Timer? _retryTimer;

  bool get _isSupported => Platform.isAndroid || Platform.isIOS;

  String get _unitId {
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS test
    }
    return 'ca-app-pub-5228897328353749/1771169590'; // Android test
  }

  void preload({bool force = false}) {
    if (!_isSupported) return;

    if (!force) {
      if (_ad != null || _loading) return;
    } else {
      // ✅ لو forced، نظّف القديم
      _ad?.dispose();
      _ad = null;
    }

    _retryTimer?.cancel();
    _loading = true;

    InterstitialAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          _retryAttempt = 0;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _showing = true;
              _lastShownAt = DateTime.now(); // ✅ هنا الأفضل
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
              _showing = false;
              preload();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _ad = null;
              _showing = false;
              preload();
            },
          );
        },
        onAdFailedToLoad: (err) {
          _ad = null;
          _loading = false;
          _scheduleRetry();
        },
      ),
    );
  }

  void _scheduleRetry() {
    if (!_isSupported) return;

    _retryTimer?.cancel();
    _retryAttempt++;
    final seconds = (2 << (_retryAttempt - 1)).clamp(2, 60);
    _retryTimer = Timer(Duration(seconds: seconds), () {
      preload(force: true);
    });
  }

  bool _passedInterval() {
    if (_lastShownAt == null) return true;
    return DateTime.now().difference(_lastShownAt!) >= minInterval;
  }

  Future<bool> showIfReady(BuildContext context) async {
    if (!_isSupported) return false;

    final isCurrent = (ModalRoute.of(context)?.isCurrent ?? true);
    if (!isCurrent) return false;
    if (_showing) return false;
    if (!_passedInterval()) return false;

    final ad = _ad;
    if (ad == null) {
      preload();
      return false;
    }

    try {
      ad.show();
      _ad = null; // ✅ مهم: interstitial single-use
      return true;
    } catch (_) {
      ad.dispose();
      _ad = null;
      _showing = false;
      preload();
      return false;
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _ad?.dispose();
    _ad = null;
    _loading = false;
    _showing = false;
  }
}
