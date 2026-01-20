// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:game/loading_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  // ---- نفس ستايل باقي الشاشات ----
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _success = Color(0xFF16A34A);

  final User? user = FirebaseAuth.instance.currentUser;
  int userXP = 0;
  int userLevel = 1;
  bool isLoading = true;
  RewardedAd? _rewardedAd;
  bool _loadingRewarded = false;
  Future<void> _grantXpFromVideo() async {
    if (user == null) return;

    setState(() {
      userXP += 2; // ✅ +2 XP
      if (userXP > 100) userXP = 100; // إذا بدك حد أعلى (اختياري)
    });

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      "xp": userXP,
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تمت إضافة +2 XP ✅", textAlign: TextAlign.center),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _watchAdAndGainXp() async {
    if (!mounted) return;

    // 1) Dialog احترافي
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "فيديو مكافأة",
                  style: TextStyle(fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          content: const Text(
            "شاهد فيديو قصير لتحصل على +2 خبرة (XP) فورًا.",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("مشاهدة الفيديو"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    // 2) Loading Dialog أنيق
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "جاري تجهيز الفيديو...",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 3) عرض الإعلان
    final earned = await _showRewardedAd();

    // سكّر اللودينغ
    if (mounted) Navigator.pop(context);

    // 4) إذا ما انمنحت المكافأة
    if (!earned) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 1),
          content: const Text(
            "لم يتم منح المكافأة. جرّب مرة ثانية.",
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    // 5) نجاح: زِد XP
    await _grantXpFromVideo();

    // if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     behavior: SnackBarBehavior.floating,
    //     margin: const EdgeInsets.all(12),
    //     duration: const Duration(seconds: 1),
    //     content: const Text("تمت إضافة +2 XP ✅", textAlign: TextAlign.center),
    //   ),
    // );
  }

  String get _rewardedUnitId {
    // Test rewarded IDs (Google)
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    return 'ca-app-pub-5228897328353749/9980832105';
  }

  Timer? _retryTimer;

  void _loadRewardedAd() {
    if (_loadingRewarded) return;
    _loadingRewarded = true;

    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd?.dispose(); // تنظيف لو كان فيه قديم
          _rewardedAd = ad;
          _loadingRewarded = false;
          _retryTimer?.cancel();
          if (mounted) setState(() {}); // ✅ عشان نحدّث حالة الزر
        },
        onAdFailedToLoad: (err) {
          _rewardedAd = null;
          _loadingRewarded = false;

          // ✅ جرّب تلقائيًا بعد 3 ثواني
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 3), _loadRewardedAd);

          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<bool> _showRewardedAd() async {
    final ad = _rewardedAd;

    // ✅ إذا مش جاهز: لا تفتح، فقط خبر المستخدم (والتحميل يكون مسبقًا)
    if (ad == null) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("الإعلان قيد التجهيز... جرّب بعد لحظة"),
          duration: Duration(seconds: 1),
        ),
      );

      // اختياري: لو بدك تعيد محاولة تحميل هنا
      _loadRewardedAd();
      return false;
    }

    // ✅ امنع استخدام نفس الإعلان مرتين
    _rewardedAd = null;
    if (mounted) setState(() {}); // لتحديث زر “جاري التجهيز”

    final completer = Completer<bool>();
    bool earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint("✅ Rewarded: SHOWED");
      },
      onAdImpression: (ad) {
        debugPrint("✅ Rewarded: IMPRESSION");
      },
      onAdDismissedFullScreenContent: (ad) async {
        debugPrint("✅ Rewarded: DISMISSED | earned=$earned");
        ad.dispose();

        // ✅ جهّز الإعلان التالي مباشرة
        _loadRewardedAd();

        // ✅ تأخير بسيط لمنع race (أحياناً المكافأة تصل متأخرة جداً)
        await Future.delayed(const Duration(milliseconds: 250));

        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint("❌ Rewarded: FAILED TO SHOW | ${err.message}");
        ad.dispose();

        // ✅ جهّز إعلان جديد
        _loadRewardedAd();

        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
        debugPrint("🎁 Rewarded: EARNED | ${reward.amount} ${reward.type}");
      },
    );

    return completer.future;
  }

  Future<void> _grantToolFromVideo(String toolKey) async {
    if (user == null) return;

    setState(() {
      userTools[toolKey] = (userTools[toolKey] ?? 0) + 1;
    });

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      "tools": {toolKey: FieldValue.increment(1)},
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تم إضافة +1 للأداة ✅", textAlign: TextAlign.center),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _watchAdAndGrant(String toolKey) async {
    if (!mounted) return;

    // 1) Dialog احترافي
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "فيديو مكافأة",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: const Text(
            "شاهد فيديو قصير لتحصل على +1 لهذه الأداة فورًا.",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("مشاهدة الفيديو"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    // 2) Loading Dialog أنيق
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "جاري تجهيز الفيديو...",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 3) عرض الإعلان
    final earned = await _showRewardedAd();

    // سكّر اللودينغ
    if (mounted) Navigator.pop(context);

    // 4) فشل المكافأة
    if (!earned) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 1),
          content: const Text(
            "لم يتم منح المكافأة. جرّب مرة ثانية.",
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    // 5) نجاح: امنح الأداة +1
    await _grantToolFromVideo(toolKey);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 1),
        content: const Text(
          "تمت إضافة +1 للأداة ✅",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // أعداد الأدوات المشتراة
  Map<String, int> userTools = {
    "deleteOne": 0,
    "deleteTwo": 0,
    "solve": 0,
    "addTime": 0,
  };

  // أدوات المساعدة المتاحة
  final List<Map<String, dynamic>> powerUps = [
    {
      "name": "حذف إجابة واحدة",
      "cost": 15,
      "key": "deleteOne",
      "icon": Icons.cancel_rounded,
      "color": Color(0xFFDC2626),
      "desc": "يزيل خيارًا خاطئًا واحدًا",
    },
    {
      "name": "حذف إجابتين",
      "cost": 25,
      "key": "deleteTwo",
      "icon": Icons.remove_circle_rounded,
      "color": Color(0xFFF59E0B),
      "desc": "يزيل خيارين خاطئين",
    },
    {
      "name": "حل السؤال مباشرة",
      "cost": 40,
      "key": "solve",
      "icon": Icons.check_circle_rounded,
      "color": Color(0xFF16A34A),
      "desc": "يعطيك الإجابة الصحيحة فورًا",
    },
    {
      "name": "زيادة 10 ثواني",
      "cost": 5,
      "key": "addTime",
      "icon": Icons.timer_rounded,
      "color": Color(0xFF2563EB),
      "desc": "يزيد الوقت المتاح +10 ثواني",
    },
  ];

  @override
  void initState() {
    super.initState();
    fetchUserXPAndTools();
    _loadRewardedAd();
    Future.delayed(const Duration(milliseconds: 500), _loadRewardedAd);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> fetchUserXPAndTools() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (!mounted) return;

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        userXP = data['xp'] ?? 0;
        userLevel = data['level'] ?? 1;
        userTools["deleteOne"] = data['tools']?['deleteOne'] ?? 0;
        userTools["deleteTwo"] = data['tools']?['deleteTwo'] ?? 0;
        userTools["solve"] = data['tools']?['solve'] ?? 0;
        userTools["addTime"] = data['tools']?['addTime'] ?? 0;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  /// شراء أداة أو مستوى
  Future<void> buyPowerUp(String name, int cost, [String? key]) async {
    if (user == null) return;

    if (userXP < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "النقاط (XP) غير كافية للشراء!",
            textAlign: TextAlign.center,
          ),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      userXP -= cost;
      if (key != null) {
        userTools[key] = (userTools[key] ?? 0) + 1;
      } else {
        userLevel += 1;
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      "xp": userXP,
      "level": userLevel,
      "tools": userTools,
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('powerups')
        .add({
          "name": name,
          "cost": cost,
          "date": FieldValue.serverTimestamp(),
        });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("تم شراء $name بنجاح ✅", textAlign: TextAlign.center),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  int getLevelCost() {
    if (userLevel >= 0 && userLevel < 20) return 25;
    if (userLevel >= 20 && userLevel < 40) return 50;
    return 75;
  }

  // ---------- UI Helpers ----------
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _chip({
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buyButton({
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: const Text(
            "المتجر",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
            ),
          ),
          child: isLoading
              ? const Center(child: LoadingScreen())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    children: [
                      // Header (XP + Level)
                      _card(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _primary.withOpacity(0.12),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "رصيدك الحالي",
                                    style: TextStyle(
                                      color: _textMuted,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _chip(
                                        text: "XP $userXP",
                                        icon: Icons.bolt_rounded,
                                        color: _primary,
                                      ),
                                      _chip(
                                        text: "Level $userLevel",
                                        icon: Icons.star_rounded,
                                        color: _warning,
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: _watchAdAndGainXp,
                                      icon: const Icon(
                                        Icons.play_circle_outline_rounded,
                                      ),
                                      label: const Text(
                                        "شاهد الاعلان واحصل على +2 XP",
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: "تحديث",
                              onPressed: fetchUserXPAndTools,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // List
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 12),
                          children: [
                            // PowerUps
                            ...powerUps.map((item) {
                              final String name = item["name"];
                              final int cost = item["cost"];
                              final String key = item["key"];
                              final IconData icon = item["icon"];
                              final Color color = item["color"];
                              final String desc = item["desc"];
                              final int count = userTools[key] ?? 0;

                              final canBuy = userXP >= cost;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: _card(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: color.withOpacity(0.18),
                                          ),
                                        ),
                                        child: Icon(icon, color: color),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: _textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              desc,
                                              style: const TextStyle(
                                                color: _textMuted,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                _chip(
                                                  text: "السعر: $cost XP",
                                                  icon:
                                                      Icons.local_offer_rounded,
                                                  color: _primary,
                                                ),
                                                _chip(
                                                  text: "لديك: $count",
                                                  icon:
                                                      Icons.inventory_2_rounded,
                                                  color: _success,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: 34,
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _watchAdAndGrant(key),
                                              icon: const Icon(
                                                Icons
                                                    .play_circle_outline_rounded,
                                                size: 18,
                                              ),
                                              label: const Text("1+"),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: _primary,
                                                side: BorderSide(
                                                  color: _primary.withOpacity(
                                                    0.35,
                                                  ),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buyButton(
                                            label: "شراء",
                                            enabled: canBuy,
                                            onTap: () =>
                                                buyPowerUp(name, cost, key),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 6),

                            // Buy Level
                            Builder(
                              builder: (_) {
                                final lvlCost = getLevelCost();
                                final canBuy = userXP >= lvlCost;

                                return _card(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: _warning.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: _warning.withOpacity(0.22),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.upgrade_rounded,
                                          color: _warning,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "شراء مستوى جديد",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: _textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              "يفتح تصنيفات أكثر حسب مستواك",
                                              style: TextStyle(
                                                color: _textMuted,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                _chip(
                                                  text: "السعر: $lvlCost XP",
                                                  icon:
                                                      Icons.local_offer_rounded,
                                                  color: _primary,
                                                ),
                                                _chip(
                                                  text: "مستواك: $userLevel",
                                                  icon: Icons.star_rounded,
                                                  color: _warning,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      _buyButton(
                                        label: "ترقية",
                                        enabled: canBuy,
                                        onTap: () =>
                                            buyPowerUp("شراء مستوى", lvlCost),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 8),

          child: const BannerAdView(
            adUnitId: 'ca-app-pub-5228897328353749/1447751878',
          ),
        ),
      ),
    );
  }
}
