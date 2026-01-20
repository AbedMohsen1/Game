// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:game/loading_screen.dart';
import 'package:game/screen/auth/login_screen.dart';
import 'package:game/screen/Game/friends_matches_page.dart';
import 'package:game/screen/settings/players_list.dart';
import 'package:game/screen/settings/purchases_history_page.dart';
import 'package:game/screen/settings/purchases_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- نفس ألوان شاشة اللاعبين (داخل الملف) ---
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);

  final User? user = FirebaseAuth.instance.currentUser;

  String name = "مستخدم";
  String playerId = "غير متوفر";
  int level = 1;
  int xp = 0;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  int friendWins = 0;
  bool isLoading = true;
  String photoUrl = "";
  int cheatCount = 0;

  @override
  void initState() {
    super.initState();
    fetchUserStats();
  }

  Stream<int> _friendRequestsCountStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream<int>.value(0);

    return FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> fetchUserStats() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (!mounted) return;

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        name = data['name'] ?? user!.displayName ?? "مستخدم";
        playerId = data['playerId'] ?? "غير متوفر";
        photoUrl = (data['photoURL'] ?? "").toString();
        level = _asInt(data['level'], 1);
        xp = _asInt(data['xp'], 0);
        correctAnswers = _asInt(data['correctAnswers'], 0);
        wrongAnswers = _asInt(data['wrongAnswers'], 0);
        friendWins = _asInt(data['friendWins'], 0);
        cheatCount = _asInt(data['cheatCount'], 0);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  int _asInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  void copyPlayerId() {
    Clipboard.setData(ClipboardData(text: playerId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("تم نسخ معرف اللاعب!", textAlign: TextAlign.center),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await FirebaseMessaging.instance.subscribeToTopic('season_updates');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  void openPurchases() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PurchasesPage()),
    );
  }

  void openPurchasesHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PurchasesHistoryPage()),
    );
  }

  void openFriendsMatches() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendsMatchesPage()),
    );
  }

  void openPlayersList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlayersList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = user?.email ?? "";
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("الملف الشخصي"),
        centerTitle: true,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
            tooltip: "تسجيل الخروج",
          ),
        ],
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
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      child: Column(
                        children: [
                          _card(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 54,
                                  backgroundColor: _primary.withOpacity(0.12),
                                  backgroundImage: photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,

                                  child: !hasPhoto
                                      ? Text(
                                          name.isNotEmpty
                                              ? name.characters.first
                                                    .toUpperCase()
                                              : "?",
                                          style: const TextStyle(
                                            fontSize: 40,
                                            color: _primary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: _textDark,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // ID Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _pill(
                                      icon: Icons.badge_outlined,
                                      text: "ID: $playerId",
                                      color: _textMuted,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18),
                                      onPressed: copyPlayerId,
                                      tooltip: "نسخ المعرف",
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Stats Card
                          _card(
                            child: Column(
                              children: [
                                _statRow(
                                  icon: Icons.star_rounded,
                                  iconColor: _warning,
                                  title: "المستوى الحالي",
                                  value: "Level $level",
                                ),
                                const SizedBox(height: 10),
                                _statRow(
                                  icon: Icons.bolt_rounded,
                                  iconColor: _primary,
                                  title: "النقاط (XP)",
                                  value: "$xp",
                                ),
                                const SizedBox(height: 10),
                                _statRow(
                                  icon: Icons.warning_amber_rounded,
                                  iconColor: _danger,
                                  title: "محاولات الغش",
                                  value: "$cheatCount",
                                ),
                                const SizedBox(height: 10),
                                _statRow(
                                  icon: Icons.emoji_events_rounded,
                                  iconColor: _warning,
                                  title: "مرات الفوز ضد صديق",
                                  value: "$friendWins",
                                ),
                                const SizedBox(height: 12),
                                Divider(color: _border.withOpacity(0.8)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _miniStat(
                                        icon: Icons.check_circle_rounded,
                                        color: _success,
                                        label: "صح",
                                        value: "$correctAnswers",
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _miniStat(
                                        icon: Icons.cancel_rounded,
                                        color: _danger,
                                        label: "خطأ",
                                        value: "$wrongAnswers",
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Actions
                          _actionButton(
                            icon: Icons.shopping_cart_rounded,
                            text: "المتجر",
                            onTap: openPurchases,
                          ),
                          const SizedBox(height: 10),
                          _actionButton(
                            icon: Icons.receipt_long_rounded,
                            text: "سجل المشتريات",
                            onTap: openPurchasesHistory,
                          ),
                          const SizedBox(height: 10),
                          StreamBuilder<int>(
                            stream: _friendRequestsCountStream(),
                            builder: (context, snap) {
                              final count = snap.data ?? 0;

                              return _actionButton(
                                icon: Icons.people_alt_rounded,
                                text: "قائمة اللاعبين",
                                badgeCount: count,
                                onTap: openPlayersList,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _actionButton(
                            icon: Icons.sports_esports_rounded,
                            text: "سجل المباريات ضد صديق",
                            onTap: () => _showComingSoonSnackBar(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Banner
                  if (Platform.isAndroid || Platform.isIOS)
                    Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.all(8),
                      child: const BannerAdView(
                        adUnitId: 'ca-app-pub-5228897328353749/1447751878',
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _showComingSoonSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            "قريباً: سجل المباريات ضد صديق 🔒",
            textAlign: TextAlign.center,
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
  }

  // ---------- Widgets helpers ----------
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.6,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: iconColor.withOpacity(0.12),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _miniStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    int badgeCount = 0, // ✅ جديد
  }) {
    final showBadge = badgeCount > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _primary.withOpacity(0.12),
              child: Icon(icon, color: _primary),
            ),
            const SizedBox(width: 12),

            // ✅ النص + البادج جنب بعض
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  if (showBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 99 ? "99+" : "$badgeCount",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Icon(Icons.chevron_right_rounded, color: _textMuted),
          ],
        ),
      ),
    );
  }
}
