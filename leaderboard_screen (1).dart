// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game/ads/banner_ad_view.dart';
import 'package:game/loading_screen.dart';
import 'package:game/screen/settings/player_profile_page.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // --- نفس ستايل اللاعبين/البروفايل (داخل الملف) ---
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  static const Color _warning = Color(0xFFF59E0B);

  int seasonDays = 10;
  List<num> prizes = const [20, 15, 10, 5, 5];
  // int _seasonNumber = 1;

  final DocumentReference seasonRef = FirebaseFirestore.instance
      .collection('settings')
      .doc('leaderboard');

  Timer? _ticker;
  DateTime? _seasonStart;
  bool _resetting = false;
  Duration _remaining = Duration.zero;
  static const String adminUid = '9onuGEKEqWR95sex16szvc3mBEJ2';
  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerProfilePage(userId: userId)),
    );
  }

  StreamSubscription? _seasonSub;
  bool get isAdmin {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == adminUid;
  }

  String compactNumber(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Future<void> _saveTop5Winners() async {
    final settingsSnap = await seasonRef.get();
    final settings = settingsSnap.data() as Map<String, dynamic>?;

    final int seasonNumber = (settings?['seasonNumber'] is int)
        ? settings!['seasonNumber'] as int
        : (settings?['seasonNumber'] is num)
        ? (settings!['seasonNumber'] as num).toInt()
        : 1;
    final winnersCount = prizes.length; // ✅ عدد الفائزين حسب فايربيز
    if (winnersCount == 0) return;

    // ✅ نسحب 50 فقط (مش كل اللاعبين)
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('level', descending: true)
        .orderBy('xp', descending: true)
        .limit(50)
        .get();

    final players = List<QueryDocumentSnapshot>.from(snap.docs);

    // ✅ نفس ترتيب الشاشة: level ثم xp ثم cheatCount عند التقارب
    players.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db = b.data() as Map<String, dynamic>;

      final la = (da['level'] ?? 1) as int;
      final lb = (db['level'] ?? 1) as int;
      final c1 = lb.compareTo(la);
      if (c1 != 0) return c1;

      final xa = (da['xp'] ?? 0) as int;
      final xb = (db['xp'] ?? 0) as int;

      final c2 = xb.compareTo(xa);
      if (c2 != 0) {
        final diff = (xa - xb).abs();
        if (diff > 10) return c2;
      }

      final ca = (da['cheatCount'] ?? 0) as int;
      final cb = (db['cheatCount'] ?? 0) as int;
      final c3 = ca.compareTo(cb);
      if (c3 != 0) return c3;

      return xb.compareTo(xa);
    });

    final top = players.take(winnersCount).toList();

    final winners = <Map<String, dynamic>>[];
    for (int i = 0; i < top.length; i++) {
      final doc = top[i];
      final data = doc.data() as Map<String, dynamic>;

      winners.add({
        'uid': doc.id,
        'rank': i + 1,
        'prize': prizes[i], // ✅ قيمة الجائزة من فايربيز
        'name': (data['name'] ?? data['displayName'] ?? 'لاعب').toString(),
        'playerId': (data['playerId'] ?? '').toString(),
        'level': (data['level'] ?? 1),
        'xp': (data['xp'] ?? 0),
        'cheatCount': (data['cheatCount'] ?? 0),
      });
    }

    await seasonRef.set({
      'lastWinners': {
        'createdAt': FieldValue.serverTimestamp(),
        'seasonStart': _seasonStart == null
            ? null
            : Timestamp.fromDate(_seasonStart!),
        'seasonEnd': FieldValue.serverTimestamp(),
        'seasonDays': seasonDays,
        'prizes': prizes, // ✅ خزّن الجوائز الحالية
        'seasonNumber': seasonNumber,
        'winners': winners,
      },
    }, SetOptions(merge: true));

    await seasonRef.collection('seasons').add({
      'createdAt': FieldValue.serverTimestamp(),
      'seasonStart': _seasonStart == null
          ? null
          : Timestamp.fromDate(_seasonStart!),
      'seasonEnd': FieldValue.serverTimestamp(),
      'seasonDays': seasonDays,
      'prizes': prizes,
      'winners': winners,
      'seasonNumber': seasonNumber,
    });
  }

  @override
  void initState() {
    super.initState();
    _ensureSeasonDoc();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _seasonSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureSeasonDoc() async {
    final snap = await seasonRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    final hasSeasonStart = snap.exists && data?['seasonStart'] != null;
    final hasSeasonDays = snap.exists && data?['seasonDays'] != null;
    final hasPrizes = snap.exists && data?['prizes'] != null;
    final hasSeasonNumber = snap.exists && data?['seasonNumber'] != null;

    // ✅ إذا الوثيقة مش موجودة: أنشئها ومعها seasonNumber = 1
    if (!snap.exists) {
      await seasonRef.set({
        'seasonStart': Timestamp.fromDate(DateTime.now()),
        'seasonNumber': 1,
        'seasonDays': seasonDays,
        'prizes': prizes,
      }, SetOptions(merge: true));
    } else {
      // ✅ إذا موجودة بس ناقص seasonStart
      if (!hasSeasonStart) {
        await seasonRef.set({
          'seasonStart': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
      }
      // ✅ إذا ناقص seasonNumber لأي سبب
      if (!hasSeasonNumber) {
        await seasonRef.set({'seasonNumber': 1}, SetOptions(merge: true));
      }
      if (!hasSeasonDays) {
        await seasonRef.set({
          'seasonDays': seasonDays,
        }, SetOptions(merge: true));
      }
      if (!hasPrizes) {
        await seasonRef.set({'prizes': prizes}, SetOptions(merge: true));
      }
    }

    _watchSeason();
  }

  void _watchSeason() {
    _seasonSub = seasonRef.snapshots().listen((doc) {
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>?;

      final ts = data?['seasonStart'] as Timestamp?;
      final days = data?['seasonDays'];
      final p = data?['prizes'];
      // final sn = data?['seasonNumber'];

      // prizes
      List<num> newPrizes = prizes;
      if (p is List) {
        newPrizes = p
            .map((e) => (e is num) ? e : num.tryParse('$e') ?? 0)
            .toList();
        if (newPrizes.isEmpty) newPrizes = const [20, 15, 10, 5, 5];
      }

      // seasonNumber
      // final int newSeasonNumber = (sn is int)
      // ? sn
      // : (sn is num)
      // ? sn.toInt()
      // : 1;
      setState(() {
        if (ts != null) _seasonStart = ts.toDate();

        if (days is int) {
          seasonDays = days;
        } else if (days is num) {
          seasonDays = days.toInt();
        }

        prizes = newPrizes;
        // _seasonNumber = newSeasonNumber;
      });

      _updateRemaining();
    });
  }

  void _startTicker() {
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    if (_seasonStart == null) return;

    final end = _seasonStart!.add(Duration(days: seasonDays));
    final now = DateTime.now();
    final left = end.difference(now);

    if (left <= Duration.zero) {
      setState(() => _remaining = Duration.zero);
      if (left <= Duration.zero) {
        setState(() => _remaining = Duration.zero);
        return;
      }
      return;
    }
    setState(() => _remaining = left);
  }

  Future<void> _resetSeason() async {
    if (!isAdmin) return;

    if (_resetting) return;
    setState(() => _resetting = true);

    try {
      await _saveTop5Winners();

      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int i = 0;

      for (final doc in usersSnap.docs) {
        batch.update(doc.reference, {
          'level': 1,
          'cheatCount': 0,
          'lastUnlockLevel': 1,
          'unlockedCategories': [],
        });
        i++;
        if (i % 450 == 0) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
        }
      }
      await batch.commit();

      await seasonRef.set({
        'seasonNumber': FieldValue.increment(1),
        'seasonStart': Timestamp.fromDate(DateTime.now()),
        'seasonDays': seasonDays,
        'prizes': prizes,
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  String _fmt(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final secs = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(days)}:${two(hours)}:${two(mins)}:${two(secs)}';
  }

  // ----------- UI Helpers (نفس ستايل اللاعبين) -----------

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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _chip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prizeBadge({
    required String text,
    required List<Color> gradient,
    required Color shadowBase,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: shadowBase.withOpacity(0.18),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$text \$',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int index) {
    if (index == 0) return const Color(0xFFFFF7E6); // gold tint
    if (index == 1) return const Color(0xFFF3F4F6); // silver tint
    if (index == 2) return const Color(0xFFFFF1EE); // bronze tint
    return Colors.white;
  }

  IconData _rankIcon(int index) {
    if (index <= 2) return Icons.emoji_events_rounded;
    return Icons.person_rounded;
  }

  Color _rankIconColor(int index) {
    if (index == 0) return const Color(0xFFFFB300);
    if (index == 1) return const Color(0xFF9CA3AF);
    if (index == 2) return const Color(0xFF8D6E63);
    return _primary;
  }

  List<Color>? _prizeGradient(int index) {
    if (index == 0) return const [Color(0xFFFFE082), Color(0xFFFFB300)];
    if (index == 1) return const [Color(0xFFE5E7EB), Color(0xFF9CA3AF)];
    if (index == 2) return const [Color(0xFFBCAAA4), Color(0xFF6D4C41)];
    if (index == 3 || index == 4) {
      return const [Color(0xFF93C5FD), Color(0xFF2563EB)];
    }
    return null;
  }

  String? _prizeText(int index) {
    if (index < 0 || index >= prizes.length) return null;
    final v = prizes[index];

    // تنسيق: إذا رقم صحيح لا تظهر .0
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final usersQuery = FirebaseFirestore.instance
        .collection('users')
        .orderBy('level', descending: true)
        .orderBy('xp', descending: true)
        .limit(50);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ترتيب اللاعبين'),
        centerTitle: true,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBar: Platform.isAndroid
          ? const BannerAdView(
              adUnitId: 'ca-app-pub-5228897328353749/1447751878',
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
          ),
        ),
        child: Column(
          children: [
            // Header timer card
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: _card(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _primary.withOpacity(0.12),
                      child: const Icon(Icons.timer_outlined, color: _primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _resetting
                                ? 'جاري بدء موسم جديد...'
                                : 'الموسم ينتهي بعد',
                            style: const TextStyle(
                              color: _textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 4),
                          Text(
                            '${_remaining.inDays} يوم',
                            style: const TextStyle(
                              color: _textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          // Text(
                          //   'الموسم رقم $_seasonNumber',
                          //   style: const TextStyle(
                          //     color: _primary,
                          //     fontWeight: FontWeight.w900,
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                    Text(
                      _fmt(_remaining),
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: _textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_remaining == Duration.zero && isAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'بدء موسم جديد',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onPressed: _resetting ? null : _resetSeason,
                ),
              ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: usersQuery.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: LoadingScreen());
                  }

                  final players = List<QueryDocumentSnapshot>.from(
                    snapshot.data!.docs,
                  );

                  // ✅ ترتيب إضافي: إذا level متساوي و XP متقارب (<=10) رتّب حسب cheatCount (الأقل أفضل)
                  players.sort((a, b) {
                    final da = a.data() as Map<String, dynamic>;
                    final db = b.data() as Map<String, dynamic>;

                    final la = (da['level'] ?? 1) as int;
                    final lb = (db['level'] ?? 1) as int;

                    // المستوى: تنازلي
                    final c1 = lb.compareTo(la);
                    if (c1 != 0) return c1;

                    final xa = (da['xp'] ?? 0) as int;
                    final xb = (db['xp'] ?? 0) as int;

                    // XP: تنازلي
                    final c2 = xb.compareTo(xa);
                    if (c2 != 0) {
                      // ✅ إذا الفرق كبير، خلّي ترتيب XP الطبيعي
                      final diff = (xa - xb).abs();
                      if (diff > 10) return c2;
                      // إذا الفرق قريب (<=10) راح نكمل للمقارنة حسب cheatCount
                    }

                    // ✅ cheatCount: تصاعدي (الأقل غش = أفضل)
                    final ca = (da['cheatCount'] ?? 0) as int;
                    final cb = (db['cheatCount'] ?? 0) as int;
                    final c3 = ca.compareTo(cb);
                    if (c3 != 0) return c3;

                    // ✅ إذا ما زال تعادل: رجّع ل XP (للاستقرار)
                    return xb.compareTo(xa);
                  });
                  if (players.isEmpty) {
                    return const Center(child: Text("لا يوجد بيانات"));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final data = player.data() as Map<String, dynamic>;

                      final name = (data['name'] ?? 'لا يوجد اسم').toString();
                      final xp = data['xp'] ?? 0;
                      final level = data['level'] ?? 1;
                      // ignore: unused_local_variable
                      final cheatCount = (data['cheatCount'] ?? 0) as int;

                      final pid = (data['playerId'] ?? '').toString();

                      final prize = _prizeText(index);
                      final grad = _prizeGradient(index);
                      final userId = player.id;

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openProfile(userId),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _rankColor(index),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(
                              horizontal: 0,
                              vertical: -2,
                            ),
                            minLeadingWidth: 0,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),

                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: _rankIconColor(
                                index,
                              ).withOpacity(0.12),
                              child: Icon(
                                _rankIcon(index),
                                size: 18,
                                color: _rankIconColor(index),
                              ),
                            ),

                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: _textDark,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                if (prize != null && grad != null)
                                  _prizeBadge(
                                    text: prize,
                                    gradient: grad,
                                    shadowBase: _rankIconColor(index),
                                  ),
                              ],
                            ),

                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),

                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    if (pid.isNotEmpty) ...[
                                      _chip(
                                        'ID: $pid',
                                        Icons.badge_outlined,
                                        _textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    _chip(
                                      'Lv ${compactNumber(level)}',
                                      Icons.star_rounded,
                                      _warning,
                                    ),

                                    const SizedBox(width: 6),
                                    _chip(
                                      'XP ${compactNumber(xp)}',
                                      Icons.bolt_rounded,
                                      _primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _primary.withOpacity(0.15),
                                ),
                              ),
                              child: Text(
                                '#${index + 1}',
                                style: const TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
