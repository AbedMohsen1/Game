// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdView extends StatefulWidget {
  final String adUnitId;

  // UI options
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double radius;
  final bool showPlaceholder;

  const BannerAdView({
    super.key,
    required this.adUnitId,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.padding = const EdgeInsets.all(8),
    this.radius = 16,
    this.showPlaceholder = true,
  });

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _banner;
  AnchoredAdaptiveBannerAdSize? _adaptiveSize;

  bool _loaded = false;
  bool _loading = false;

  Timer? _retryTimer;
  int _lastWidth = 0;

  bool get _isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSupported) return;

    // عرض المساحة المتاحة للإعلان
    final w = MediaQuery.of(context).size.width.truncate();
    if (w <= 0 || w == _lastWidth) return;

    _lastWidth = w;
    _prepareAndLoad(w);
  }

  Future<void> _prepareAndLoad(int width) async {
    // جيب مقاس adaptive حسب اتجاه الشاشة الحالي
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );

    if (!mounted) return;

    setState(() {
      _adaptiveSize = size;
    });

    // لو رجع null (نادر) ما نحمّل
    if (size == null) return;

    _load();
  }

  void _load() {
    if (_loading || _adaptiveSize == null) return;
    _loading = true;

    _retryTimer?.cancel();
    _banner?.dispose();
    _banner = null;

    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: _adaptiveSize!, // ✅ Adaptive
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _banner = ad as BannerAd;
            _loaded = true;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;

          setState(() {
            _banner = null;
            _loaded = false;
            _loading = false;
          });

          // ✅ Retry بعد 3 ثواني
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            _load();
          });
        },
      ),
    );

    _banner = ad;
    ad.load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) return const SizedBox.shrink();

    // لو لسه ما حسبنا حجم الـ adaptive
    final size = _adaptiveSize;
    final w = (size?.width ?? MediaQuery.of(context).size.width).toDouble();
    final h = (size?.height ?? 50).toDouble(); // fallback لطيف

    return SafeArea(
      top: false,
      child: Container(
        margin: widget.margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                SizedBox(
                  width: w,
                  height: h,
                  child: (_loaded && _banner != null)
                      ? AdWidget(ad: _banner!)
                      : (widget.showPlaceholder
                            ? _placeholder(w, h)
                            : const SizedBox.shrink()),
                ),

                // ✅ شارة صغيرة "إعلان"
                Positioned(
                  top: 4,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      "إعلان",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      ),
    );
  }
}
